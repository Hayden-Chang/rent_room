import XCTest
@testable import Xunju

private final class SpeedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Double = 0
    func read() -> Double { lock.withLock { value } }
    func advance(_ milliseconds: Double) { lock.withLock { value += milliseconds } }
}

private actor SpeedRanges: SpeedRangeTransport {
    let clock: SpeedClock, duration: Double
    private(set) var requests: [(Int, Int, Double)] = []
    init(clock: SpeedClock, duration: Double) { self.clock = clock; self.duration = duration }
    func download(offset: Int, size: Int, timeout: Double) async throws -> Int {
        requests.append((offset, size, timeout)); clock.advance(duration); return size
    }
}

private final class SpeedProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let scenario = request.value(forHTTPHeaderField: "X-Scenario") ?? "valid"
        let range = (request.value(forHTTPHeaderField: "Range") ?? "bytes=0-0").dropFirst(6)
        let bounds = range.split(separator: "-").compactMap { Int($0) }, size = bounds[1] - bounds[0] + 1
        let response = HTTPURLResponse(url: request.url!, statusCode: scenario == "full" ? 200 : 206, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Range": "bytes \(range)/4294967296", "Content-Length": "\(size)"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        let length = scenario == "short" ? size - 1 : scenario == "extra" ? size + 1 : size
        client?.urlProtocol(self, didLoad: Data(count: length))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

private final class SpeedProbeRegistry: @unchecked Sendable {
    struct Probe: Sendable { let start: @Sendable () -> Void, stop: @Sendable () -> Void }
    private let lock = NSLock()
    private var probes: [String: Probe] = [:]
    func set(_ key: String, _ probe: Probe?) { lock.withLock { probes[key] = probe } }
    func get(_ key: String) -> Probe? { lock.withLock { probes[key] } }
}

private final class StalledSpeedProtocol: URLProtocol, @unchecked Sendable {
    static let probes = SpeedProbeRegistry()
    private var probe: SpeedProbeRegistry.Probe? { Self.probes.get(request.value(forHTTPHeaderField: "X-Probe") ?? "") }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { probe?.start() }
    override func stopLoading() { probe?.stop() }
}

final class SpeedTests: XCTestCase {
    func testAdaptiveRangesUseMonotonicElapsedTimeAndRequireTwoSamples() async throws {
        let clock = SpeedClock(), ranges = SpeedRanges(clock: clock, duration: 1000)
        let reading = try await NativeSpeedTest(transport: ranges, now: { clock.read() }).run()
        let requests = await ranges.requests
        XCTAssertEqual(requests.count, 8); XCTAssertEqual(requests[0].0, 0)
        XCTAssertTrue(requests.allSatisfy { $0.1 == 1024 * 1024 && $0.2 <= 8 })
        XCTAssertEqual(reading.bytes, 8 * 1024 * 1024); XCTAssertEqual(reading.elapsed, 8000)
        XCTAssertEqual(reading.mbps, 8.39); XCTAssertEqual(reading.progress, 100)
    }
    func testFastConnectionStopsAt64MiBWithBoundedRanges() async throws {
        let clock = SpeedClock(), ranges = SpeedRanges(clock: clock, duration: 100)
        let reading = try await NativeSpeedTest(transport: ranges, now: { clock.read() }).run()
        let requests = await ranges.requests
        XCTAssertEqual(reading.bytes, NativeSpeedTest.maximumBytes)
        XCTAssertTrue(requests.allSatisfy { $0.1 <= 8 * 1024 * 1024 && $0.0 + $0.1 <= NativeSpeedTest.maximumBytes })
        XCTAssertEqual(requests.last.map { $0.0 + $0.1 }, NativeSpeedTest.maximumBytes)
    }
    func testInsufficientElapsedSampleAndLateResponsesNeverReturnSpeed() async throws {
        for (duration, expected) in [(1.0, SpeedFailure.sample), (15_001.0, .timeout)] {
            let clock = SpeedClock(), ranges = SpeedRanges(clock: clock, duration: duration)
            do { _ = try await NativeSpeedTest(transport: ranges, now: { clock.read() }).run(); XCTFail("Invalid sample accepted") }
            catch { XCTAssertEqual(error as? SpeedFailure, expected) }
        }
    }
    func testRangeHeadersRejectFullObjectAndMalformedOrCompressedResponses() throws {
        let valid = ["Content-Range": "bytes 0-4095/4294967296", "Content-Length": "4096"]
        func accepts(_ status: Int, _ headers: [String: String]) -> Bool {
            NativeSpeedTransport.accepts(HTTPURLResponse(url: NativeSpeedTransport.endpoint, statusCode: status, httpVersion: nil, headerFields: headers)!, offset: 0, size: 4096)
        }
        XCTAssertTrue(accepts(206, valid)); XCTAssertFalse(accepts(200, valid))
        for headers in [["Content-Range": "bytes 1-4096/4294967296"], ["Content-Range": "bytes 0-4095/*"],
                        ["Content-Range": "bytes 0-4095/4095"], valid.merging(["Content-Length": "8192"], uniquingKeysWith: { _, b in b }),
                        valid.merging(["Content-Encoding": "gzip"], uniquingKeysWith: { _, b in b })] {
            XCTAssertFalse(accepts(206, headers))
        }
    }
    func testNativeTransportCountsOnlyExactValidatedBodies() async throws {
        for scenario in ["valid", "full", "short", "extra"] {
            let transport = NativeSpeedTransport(configuration: {
                let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SpeedProtocol.self]
                config.httpAdditionalHeaders = ["X-Scenario": scenario]; return config
            })
            do {
                let count = try await transport.download(offset: 0, size: 4096, timeout: 1)
                XCTAssertEqual(scenario, "valid"); XCTAssertEqual(count, 4096)
            } catch { XCTAssertNotEqual(scenario, "valid"); XCTAssertEqual(error as? SpeedFailure, .response) }
        }
    }
    func testCancellationBeforeStartDoesNotReturnOrDownloadAResult() async throws {
        let clock = SpeedClock(), ranges = SpeedRanges(clock: clock, duration: 1000)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await NativeSpeedTest(transport: ranges, now: { clock.read() }).run()
        }
        do { _ = try await task.value; XCTFail("Cancelled run produced result") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await ranges.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testCancellationAfterProgressDoesNotStartAnotherRangeOrReturnSpeed() async throws {
        let clock = SpeedClock(), ranges = SpeedRanges(clock: clock, duration: 1000)
        let task = Task {
            try await NativeSpeedTest(transport: ranges, now: { clock.read() }).run { _ in
                withUnsafeCurrentTask { $0?.cancel() }
            }
        }
        do { _ = try await task.value; XCTFail("Cancelled progress produced result") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await ranges.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testInFlightNativeCancellationStopsURLSessionRequest() async throws {
        let started = expectation(description: "Range request started"), stopped = expectation(description: "Cancelled request stopped")
        let key = UUID().uuidString
        StalledSpeedProtocol.probes.set(key, .init(start: { started.fulfill() }, stop: { stopped.fulfill() }))
        defer { StalledSpeedProtocol.probes.set(key, nil) }
        let transport = NativeSpeedTransport(configuration: {
            let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StalledSpeedProtocol.self]
            config.httpAdditionalHeaders = ["X-Probe": key]; return config
        })
        let task = Task { try await transport.download(offset: 0, size: 4096, timeout: 8) }
        await fulfillment(of: [started], timeout: 3)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled network request returned a result") }
        catch { XCTAssertTrue(error is CancellationError) }
        await fulfillment(of: [stopped], timeout: 3)
    }
}
