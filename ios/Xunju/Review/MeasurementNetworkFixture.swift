#if DEBUG
import Foundation

@MainActor enum MeasurementNetworkFixture {
    static func mode(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let test = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(test + 1), UUID(uuidString: arguments[test + 1]) != nil,
              let flag = arguments.firstIndex(of: "--speed-measurement-fixture"), arguments.indices.contains(flag + 1),
              ["wifi", "mobile", "offline", "slow"].contains(arguments[flag + 1]) else { return nil }
        return arguments[flag + 1]
    }
    static func make(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> (NativeSpeedTest, NativeNetwork)? {
        guard let mode = mode(arguments) else { return nil }
        let clock = FixtureSpeedClock()
        return (NativeSpeedTest(transport: FixtureSpeedRanges(clock: clock, slow: mode == "slow"), now: { clock.read() }),
                NativeNetwork(driver: FixtureSpeedPath(mode: mode)))
    }
}
private final class FixtureSpeedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var milliseconds = 0.0
    func tick() { lock.withLock { milliseconds += 1000 } }
    func read() -> Double { lock.withLock { milliseconds } }
}
private actor FixtureSpeedRanges: SpeedRangeTransport {
    let clock: FixtureSpeedClock
    let slow: Bool
    init(clock: FixtureSpeedClock, slow: Bool) { self.clock = clock; self.slow = slow }
    func download(offset: Int, size: Int, timeout: Double) async throws -> Int {
        // Explicit disposable transport latency, never a test sleep or real HTTP.
        try await Task.sleep(for: slow ? .seconds(5) : .milliseconds(80))
        clock.tick(); return size
    }
}
@MainActor private final class FixtureSpeedPath: NetworkPathDriver {
    let mode: String
    init(mode: String) { self.mode = mode }
    func start(_ update: @escaping @Sendable (Bool, Bool) -> Void) { update(mode != "offline", mode != "mobile") }
    func stop() {}
}
#endif
