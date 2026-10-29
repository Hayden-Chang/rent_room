import Foundation
import Network
import Observation

@MainActor protocol NetworkPathDriver {
    func start(_ update: @escaping @Sendable (Bool, Bool) -> Void)
    func stop()
}

@MainActor final class NativePathDriver: NetworkPathDriver {
    private let monitor = NWPathMonitor()
    func start(_ update: @escaping @Sendable (Bool, Bool) -> Void) {
        monitor.pathUpdateHandler = { path in update(path.status == .satisfied, path.usesInterfaceType(.wifi)) }
        monitor.start(queue: DispatchQueue(label: "Xunju.network-status"))
    }
    func stop() { monitor.cancel() }
}

/// Readiness and cancellation are per waiter. The monitor stays alive across a
/// measurement retry and is stopped when its page leaves.
@MainActor @Observable final class NativeNetwork {
    private(set) var current: NetworkStatus?
    @ObservationIgnored private let driver: any NetworkPathDriver
    @ObservationIgnored private var started = false
    @ObservationIgnored private var stopped = false
    @ObservationIgnored private var waiters: [UUID: CheckedContinuation<NetworkStatus, Error>] = [:]
    @ObservationIgnored private var timeout: Task<Void, Never>?
    init(driver: any NetworkPathDriver = NativePathDriver()) { self.driver = driver }

    func ready() async throws -> NetworkStatus {
        try Task.checkCancellation()
        guard !stopped else { throw CancellationError() }
        if let current { return current }
        let id = UUID()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { reply in
                waiters[id] = reply
                if !started {
                    started = true
                    driver.start { [weak self] available, wifi in
                        Task { @MainActor in self?.receive(available: available, wifi: wifi) }
                    }
                }
                if timeout == nil {
                    timeout = Task { @MainActor in
                        try? await Task.sleep(for: .seconds(5))
                        if !Task.isCancelled { failWaiters(CoreFailure(message: "未能确认网络状态，请重试")); timeout = nil }
                    }
                }
            }
        } onCancel: { Task { @MainActor in self.waiters.removeValue(forKey: id)?.resume(throwing: CancellationError()) } }
    }
    private func receive(available: Bool, wifi: Bool) {
        guard !stopped else { return }
        let status = NetworkStatus(available: available, wifi: wifi, version: (current?.version ?? 0) + 1)
        current = status
        timeout?.cancel(); timeout = nil
        let pending = waiters.values; waiters.removeAll()
        for reply in pending { reply.resume(returning: status) }
    }
    private func failWaiters(_ error: Error) {
        let pending = waiters.values; waiters.removeAll()
        for reply in pending { reply.resume(throwing: error) }
    }
    func stop() {
        stopped = true; driver.stop(); timeout?.cancel(); timeout = nil
        failWaiters(CancellationError())
    }
}
