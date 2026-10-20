import Foundation

enum SpeedFailure: LocalizedError, Equatable {
    case response, network, timeout, sample
    var errorDescription: String? {
        switch self {
        case .response: "测速服务返回异常，请稍后重试"
        case .network: "网络连接失败或超时，请稍后重试"
        case .timeout: "测速超时，请稍后重试"
        case .sample: "有效测速数据不足，请重试"
        }
    }
}

struct SpeedReading: Equatable, Sendable {
    let bytes: Int
    let elapsed: Double // milliseconds, matching the mini-program
    let mbps: Double
    let progress: Double
}

protocol SpeedRangeTransport: Sendable {
    func download(offset: Int, size: Int, timeout: Double) async throws -> Int
}

// Counts only completely downloaded, validated ranges, like speed-test.js.
// A monotonic clock keeps elapsed time independent of system-clock changes.
struct NativeSpeedTest: Sendable {
    static let maximumBytes = 64 * 1024 * 1024
    let transport: any SpeedRangeTransport
    var now: @Sendable () -> Double = { ProcessInfo.processInfo.systemUptime * 1000 }

    func run(progress: @Sendable (SpeedReading) async -> Void = { _ in }) async throws -> SpeedReading {
        let started = now()
        var bytes = 0, samples = 0, size = 1024 * 1024
        repeat {
            try Task.checkCancellation()
            let before = now(), remaining = 15_000 - (before - started)
            guard remaining > 0 else { throw SpeedFailure.timeout }
            let requested = min(size, Self.maximumBytes - bytes)
            let downloaded = try await transport.download(offset: bytes, size: requested, timeout: min(8000, remaining) / 1000)
            try Task.checkCancellation()
            guard downloaded == requested else { throw SpeedFailure.response }
            let elapsed = now() - started
            guard elapsed < 15_000 else { throw SpeedFailure.timeout }
            bytes += downloaded; samples += 1
            await progress(SpeedReading(bytes: bytes, elapsed: elapsed, mbps: Double(bytes) * 8 / max(1, elapsed) / 1000,
                                        progress: min(99, max(elapsed / 8000, Double(bytes) / Double(Self.maximumBytes)) * 100)))
            try Task.checkCancellation()
            size = min(8 * 1024 * 1024, max(256 * 1024, Int((Double(size) * 1000 / max(1, now() - before)).rounded())))
            if bytes >= Self.maximumBytes || (samples >= 2 && now() - started >= 8000) { break }
        } while true
        let elapsed = now() - started, mbps = Double(bytes) * 8 / elapsed / 1000
        guard elapsed >= 500, samples >= 2, mbps.isFinite, mbps > 0 else { throw SpeedFailure.sample }
        return SpeedReading(bytes: bytes, elapsed: elapsed, mbps: (mbps * 100).rounded() / 100, progress: 100)
    }
}

struct NativeSpeedTransport: SpeedRangeTransport {
    static let endpoint = URL(string: "https://mensura.cdn-apple.com/api/v1/gm/large")!
    var configuration: @Sendable () -> URLSessionConfiguration = { .ephemeral }

    func download(offset: Int, size: Int, timeout: Double) async throws -> Int {
        guard offset >= 0, size > 0, size <= 8 * 1024 * 1024,
              offset <= NativeSpeedTest.maximumBytes - size, timeout > 0, timeout <= 8 else { throw SpeedFailure.response }
        var request = URLRequest(url: Self.endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.setValue("bytes=\(offset)-\(offset + size - 1)", forHTTPHeaderField: "Range")
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        let download = RangeDownload(offset: offset, size: size, configuration: configuration)
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await download.start(request)
        } onCancel: { download.cancel() }
    }

    static func accepts(_ response: HTTPURLResponse, offset: Int, size: Int) -> Bool {
        guard response.statusCode == 206,
              let value = response.value(forHTTPHeaderField: "Content-Range") else { return false }
        let parts = value.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count == 2, parts[0] == "bytes" else { return false }
        let range = parts[1].split(separator: "/", omittingEmptySubsequences: false)
        guard range.count == 2, let total = Int(range[1]) else { return false }
        let bounds = range[0].split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2, Int(bounds[0]) == offset, Int(bounds[1]) == offset + size - 1, total > offset + size - 1 else { return false }
        if let length = response.value(forHTTPHeaderField: "Content-Length"), Int(length) != size { return false }
        if let encoding = response.value(forHTTPHeaderField: "Content-Encoding"), encoding.lowercased() != "identity" { return false }
        return true
    }
}

// URLSession invokes delegate methods off the main actor. All mutable state is
// protected by lock; continuations are resumed once, outside the lock. No body
// is retained. Header validation happens before allowing any response body.
private final class RangeDownload: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    let offset: Int, size: Int
    let configuration: @Sendable () -> URLSessionConfiguration
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Int, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var finished = false, accepted = false
    private var bytes = 0

    init(offset: Int, size: Int, configuration: @escaping @Sendable () -> URLSessionConfiguration) {
        self.offset = offset; self.size = size; self.configuration = configuration
    }

    func start(_ request: URLRequest) async throws -> Int {
        try await withCheckedThrowingContinuation { reply in
            let task: URLSessionDataTask? = lock.withLock {
                guard !finished else { return nil }
                continuation = reply
                let config = configuration()
                config.urlCache = nil; config.requestCachePolicy = .reloadIgnoringLocalCacheData
                config.timeoutIntervalForResource = request.timeoutInterval
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session
                let task = session.dataTask(with: request); self.task = task
                return task
            }
            if let task { task.resume() } else { reply.resume(throwing: CancellationError()) }
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func finish(_ result: Result<Int, Error>) {
        let state: (CheckedContinuation<Int, Error>?, URLSession?, URLSessionDataTask?)? = lock.withLock {
            guard !finished else { return nil }
            finished = true
            let state = (continuation, session, task)
            continuation = nil; session = nil; task = nil
            return state
        }
        guard let state else { return }
        state.2?.cancel(); state.1?.invalidateAndCancel()
        state.0?.resume(with: result)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse,
              NativeSpeedTransport.accepts(http, offset: offset, size: size) else {
            finish(.failure(SpeedFailure.response)); completionHandler(.cancel); return
        }
        let allow = lock.withLock { if finished { return false }; accepted = true; return true }
        completionHandler(allow ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let overflow = lock.withLock {
            if finished { return false }
            bytes += data.count
            return !accepted || bytes > size
        }
        if overflow { finish(.failure(SpeedFailure.response)) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure((error as? URLError)?.code == .timedOut ? SpeedFailure.timeout : SpeedFailure.network)); return
        }
        let valid = lock.withLock { accepted && bytes == size }
        finish(valid ? .success(size) : .failure(SpeedFailure.response))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}
