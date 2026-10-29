import XCTest
import Observation
@testable import Xunju

@MainActor private final class ConsentWatch {
    let flow: SpeedFlow, kind: SpeedConsentKind, expectation: XCTestExpectation
    private var finished = false
    init(_ flow: SpeedFlow, _ kind: SpeedConsentKind, _ expectation: XCTestExpectation) { self.flow = flow; self.kind = kind; self.expectation = expectation }
    func arm() {
        guard !finished else { return }
        withObservationTracking {
            if flow.prompt?.kind == kind { finished = true; expectation.fulfill() }
        } onChange: { [weak self] in Task { @MainActor in self?.arm() } }
    }
}

@MainActor final class SpeedFlowTests: XCTestCase {
    private func make(_ mode: String) throws -> (SpeedFlow, NativeStore, String) {
        let root = FileManager.default.temporaryDirectory.appending(path: "speed-flow-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let store = try NativeStore(directory: root), id = try store.add("测速流程")
        try store.answer(id, field: UtilityField.speed, value: .string("10"))
        try store.answer(id, field: UtilityField.speed, property: "note", value: .string("原备注"))
        let fixture = try XCTUnwrap(MeasurementNetworkFixture.make(["--business-test", UUID().uuidString, "--speed-measurement-fixture", mode]))
        let flow = SpeedFlow(session: SpeedSession(store: store, houseID: id, test: fixture.0, validScope: { true }), network: fixture.1)
        addTeardownBlock { @MainActor in flow.cancel(leaving: true) }
        return (flow, store, id)
    }
    private func prompt(_ kind: SpeedConsentKind, _ flow: SpeedFlow) async throws -> UUID {
        let appeared = expectation(description: "Explicit \(kind) consent"), watch = ConsentWatch(flow, kind, appeared)
        watch.arm()
        let ready = await XCTWaiter.fulfillment(of: [appeared], timeout: 3); XCTAssertEqual(ready, .completed)
        withExtendedLifetime(watch) {}
        return try XCTUnwrap(flow.prompt?.id)
    }
    func testConfirmedMobileFlowPersistsAndRequestsClose() async throws {
        let (flow, store, id) = try make("mobile"), operation = flow.start()
        flow.answer(try await prompt(.wifi, flow), accepted: true)
        flow.answer(try await prompt(.mobile, flow), accepted: true)
        await operation?.value
        XCTAssertEqual(flow.state, .done); XCTAssertTrue(flow.closeRequested); XCTAssertNil(flow.prompt)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"][UtilityField.speed]["value"].string, "8.39")
        XCTAssertEqual(restored.house(id)["answers"][UtilityField.speed]["note"].string, "原备注")
    }
    func testDecliningConsentRequestsCloseAndKeepsManualValue() async throws {
        let (flow, store, id) = try make("wifi"), operation = flow.start()
        flow.answer(try await prompt(.wifi, flow), accepted: false); await operation?.value
        XCTAssertTrue(flow.closeRequested); XCTAssertNil(flow.session.reading)
        XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testLeavingDuringConsentResolvesWaiterAndIgnoresLateAcceptance() async throws {
        let (flow, store, id) = try make("wifi"), operation = flow.start()
        let previous = try await prompt(.wifi, flow)
        flow.cancel(leaving: true); flow.answer(previous, accepted: true); await operation?.value
        XCTAssertNil(flow.prompt); XCTAssertNil(flow.start()); XCTAssertNil(flow.session.reading)
        XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
        do { _ = try await flow.network.ready(); XCTFail("Leaving must stop the monitor") } catch { XCTAssertTrue(error is CancellationError) }
    }
    func testNetworkChangeDismissesConsentWithoutOverwritingAnswer() async throws {
        let (flow, store, id) = try make("wifi"), operation = flow.start()
        let previous = try await prompt(.wifi, flow)
        flow.networkChanged(to: 2); flow.answer(previous, accepted: true); await operation?.value
        XCTAssertNil(flow.prompt); XCTAssertFalse(flow.closeRequested); XCTAssertNil(flow.session.reading)
        XCTAssertEqual(flow.state, .failed("测速已取消，原值保持不变"))
        XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testOfflineReadinessShowsRetryWithoutConsent() async throws {
        let (flow, store, id) = try make("offline")
        await flow.start()?.value
        XCTAssertEqual(flow.state, .failed("当前无网络，请连接 Wi-Fi 后重试")); XCTAssertNil(flow.prompt)
        XCTAssertFalse(flow.closeRequested); XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testOldConsentCannotAcceptRetriedPrompt() async throws {
        let (flow, store, id) = try make("wifi"), first = flow.start()
        let previous = try await prompt(.wifi, flow)
        flow.cancel(); await first?.value
        let retry = flow.start(), current = try await prompt(.wifi, flow)
        XCTAssertNotEqual(previous, current)
        flow.answer(previous, accepted: true)
        XCTAssertEqual(flow.prompt?.id, current); XCTAssertNil(flow.session.reading)
        flow.answer(current, accepted: false); await retry?.value
        XCTAssertEqual(store.house(id)["answers"][UtilityField.speed]["value"].string, "10")
    }
    func testMeasurementFixtureRequiresExplicitModeAndIsolatedUUID() {
        XCTAssertEqual(MeasurementNetworkFixture.mode(["--business-test", UUID().uuidString, "--speed-measurement-fixture", "mobile"]), "mobile")
        for args in [["--speed-measurement-fixture", "wifi"], ["--business-test", "bad", "--speed-measurement-fixture", "wifi"], ["--business-test", UUID().uuidString, "--utility-network-fixture"], ["--business-test", UUID().uuidString, "--speed-measurement-fixture", "unknown"]] {
            XCTAssertNil(MeasurementNetworkFixture.mode(args))
        }
    }
}
