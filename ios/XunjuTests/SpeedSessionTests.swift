import XCTest
@testable import Xunju

private final class SessionSpeedClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time = 0.0
    func tick() { lock.withLock { time += 1000 } }
    func read() -> Double { lock.withLock { time } }
}
private actor SessionSpeedRanges: SpeedRangeTransport {
    let clock: SessionSpeedClock
    var hook: (@Sendable () async throws -> Void)?
    private(set) var count = 0
    init(clock: SessionSpeedClock, hook: (@Sendable () async throws -> Void)? = nil) { self.clock = clock; self.hook = hook }
    func download(offset: Int, size: Int, timeout: Double) async throws -> Int {
        count += 1; clock.tick(); try await hook?(); return size
    }
}
@MainActor private final class ConsentGate {
    let started: XCTestExpectation
    var reply: CheckedContinuation<Bool, Never>?
    init(_ started: XCTestExpectation) { self.started = started }
    func ask() async -> Bool { await withCheckedContinuation { reply = $0; started.fulfill() } }
    func finish(_ value: Bool) { reply?.resume(returning: value); reply = nil }
}

@MainActor final class SpeedSessionTests: XCTestCase {
    private func record() throws -> (NativeStore, String) {
        let url = FileManager.default.temporaryDirectory.appending(path: "speed-session-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        let store = try NativeStore(directory: url), id = try store.add("网络测速")
        try store.answer(id, field: UtilityField.speed, value: .string("10"))
        try store.answer(id, field: UtilityField.speed, property: "note", value: .string("房源Wi-Fi"))
        return (store, id)
    }
    func testMobileRequiresBothConsentsAndPersistsMeasuredResultWithNote() async throws {
        let (store, id) = try record(), clock = SessionSpeedClock(), transport = SessionSpeedRanges(clock: clock)
        let model = SpeedSession(store: store, houseID: id, test: NativeSpeedTest(transport: transport, now: { clock.read() }), validScope: { true })
        var prompts: [SpeedConsentKind] = []
        await model.start(network: NetworkStatus(available: true, wifi: false, version: 1)) { kind in prompts.append(kind); return true }?.value
        XCTAssertEqual(prompts, [.wifi, .mobile]); XCTAssertEqual(model.state, .done)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"][UtilityField.speed]["value"].string, "8.39")
        XCTAssertEqual(restored.house(id)["answers"][UtilityField.speed]["note"].string, "房源Wi-Fi")
    }
    func testNoNetworkOrDeclinedConsentNeverStartsDownloadOrChangesAnswer() async throws {
        let (store, id) = try record(), clock = SessionSpeedClock(), transport = SessionSpeedRanges(clock: clock)
        let model = SpeedSession(store: store, houseID: id, test: NativeSpeedTest(transport: transport, now: { clock.read() }), validScope: { true })
        await model.start(network: NetworkStatus(available: false, wifi: false, version: 1)) { _ in XCTFail("Offline must not ask"); return true }?.value
        XCTAssertEqual(model.state, .failed("当前无网络，请连接 Wi-Fi 后重试"))
        await model.start(network: NetworkStatus(available: true, wifi: true, version: 2)) { _ in false }?.value
        let count = await transport.count
        XCTAssertEqual(count, 0); XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testNetworkChangeWhileAwaitingConsentPreventsMeasurement() async throws {
        let (store, id) = try record(), clock = SessionSpeedClock(), transport = SessionSpeedRanges(clock: clock)
        let model = SpeedSession(store: store, houseID: id, test: NativeSpeedTest(transport: transport, now: { clock.read() }), validScope: { true })
        let began = expectation(description: "Consent visible"), gate = ConsentGate(began)
        let operation = model.start(network: NetworkStatus(available: true, wifi: true, version: 1)) { _ in await gate.ask() }
        let ready = await XCTWaiter.fulfillment(of: [began], timeout: 3); XCTAssertEqual(ready, .completed)
        model.networkChanged(to: 2); gate.finish(true); await operation?.value
        let count = await transport.count
        XCTAssertEqual(count, 0); XCTAssertEqual(model.state, .failed("测速已取消，原值保持不变"))
        XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testConcurrentManualValueIsNeverOverwrittenByMeasurement() async throws {
        let (store, id) = try record(), clock = SessionSpeedClock()
        let transport = SessionSpeedRanges(clock: clock, hook: { try await MainActor.run { try store.answer(id, field: UtilityField.speed, value: .string("31")) } })
        let model = SpeedSession(store: store, houseID: id, test: NativeSpeedTest(transport: transport, now: { clock.read() }), validScope: { true })
        await model.start(network: NetworkStatus(available: true, wifi: true, version: 1)) { _ in true }?.value
        guard case .saveError = model.state else { return XCTFail("Changed answer must prevent overwrite") }
        XCTAssertNotNil(model.reading); XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "31")
    }
    func testSaveFailureKeepsReadingAndOriginalAnswerForExplicitRetry() async throws {
        let (store, id) = try record(), clock = SessionSpeedClock(), transport = SessionSpeedRanges(clock: clock)
        let file = store.records.directory.appending(path: "state.json")
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let model = SpeedSession(store: store, houseID: id, test: NativeSpeedTest(transport: transport, now: { clock.read() }), validScope: { true })
        await model.start(network: NetworkStatus(available: true, wifi: true, version: 1)) { _ in true }?.value
        guard case .saveError = model.state else { return XCTFail("I/O failure must preserve retry") }
        XCTAssertEqual(model.reading?.mbps, 8.39); XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
        try FileManager.default.removeItem(at: file); model.save()
        XCTAssertEqual(model.state, .done)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["answers"][UtilityField.speed]["value"].string, "8.39")
    }
}
