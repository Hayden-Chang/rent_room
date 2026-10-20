import XCTest
@testable import Xunju

private actor DelayedMapHTTP: AuthTransport {
    let started: XCTestExpectation
    private var reply: CheckedContinuation<HTTPPayload, Error>?
    init(started: XCTestExpectation) { self.started = started }
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        try await withCheckedThrowingContinuation { reply in self.reply = reply; started.fulfill() }
    }
    func finish() {
        reply?.resume(returning: HTTPPayload(data: Data(#"{"status":{"infocode":1000},"pois":[{"hotPointID":"late","name":"过期地点","address":"旧地址","lonlat":"121.4737,31.2304"}]}"#.utf8), status: 200)); reply = nil
    }
}

@MainActor final class UtilityFlowTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "utility-flows-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func testPlaceSelectionPersistsCanonicalAddressAndWorkplaceWithoutChangingAnswers() async throws {
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapTransport: UtilityNetworkFixture.transport, mapKey: "fixture")
        let store = workspace.store, id = try store.add("联动房源")
        try store.answer(id, field: "f1_6", value: .string("2800"))
        let search = PlaceSearch(store: store, key: workspace.mapKey, validScope: { workspace.store === store })
        let before = store.state; search.query = "阳光"; await search.submit()?.value
        XCTAssertEqual(store.state, before)
        let choice = try XCTUnwrap(search.choices.first)
        try store.call("place", ["id": .string(id), "value": search.selected(choice)])
        search.query = "办公楼"; await search.submit()?.value
        let office = try XCTUnwrap(search.choices.first)
        try store.call("workplacePlace", ["value": search.selected(office)])
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertTrue(restored.house(id)["address"].string.contains("阳光小区"))
        XCTAssertTrue(restored.state["settings"]["workplace"].string.contains("办公楼"))
        XCTAssertEqual(restored.house(id)["answers"]["f1_6"]["value"].string, "2800")
        XCTAssertNotNil(GeographicPoint(restored.house(id)["location"]))
        try workspace.logout()
        XCTAssertThrowsError(try search.selected(office))
    }
    func testCancelledPlaceResponseDoesNotRestoreCandidatesOrChangeRecords() async throws {
        let started = expectation(description: "Read-only query started"), http = DelayedMapHTTP(started: started)
        let store = try NativeStore(directory: root(), network: NativeMapTransport(transport: http))
        let search = PlaceSearch(store: store, key: "fixture", validScope: { true }), before = store.state
        search.query = "旧地址"; let operation = search.submit()
        let result = await XCTWaiter.fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(result, .completed)
        search.cancel(); await http.finish(); await operation?.value
        XCTAssertTrue(search.choices.isEmpty); XCTAssertFalse(search.busy); XCTAssertEqual(store.state, before)
    }
    func testMissingMapKeyKeepsManualWorkplaceAndDoesNotQuery() async throws {
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapKey: "")
        try workspace.store.call("settings", ["property": .string("workplace"), "value": .string("手工填写办公楼")])
        let search = PlaceSearch(store: workspace.store, key: "", validScope: { true }); search.query = "办公楼"
        XCTAssertNil(search.submit()); XCTAssertTrue(search.message.contains("手动填写地址"))
        try workspace.store.call("save")
        XCTAssertEqual(try NativeStore(directory: workspace.store.records.directory).state["settings"]["workplace"].string, "手工填写办公楼")
    }
    func testRouteConfirmationPersistsAndRejectsChangedValueAndEndpoints() async throws {
        let store = try NativeStore(directory: root(), network: UtilityNetworkFixture.transport), id = try store.add("通勤房源")
        func point(_ latitude: Double, _ longitude: Double) throws -> JSONValue {
            try store.call("coordinate", ["property": .string("toMap"), "value": GeographicPoint(latitude: latitude, longitude: longitude).json])
        }
        try store.call("place", ["id": .string(id), "value": .object(["address": .string("房源"), "location": point(31.2304, 121.4737)])])
        try store.call("workplacePlace", ["value": .object(["address": .string("公司"), "location": point(31.2404, 121.4837)])])
        let model = CommuteSearch(store: store, houseID: id, fieldID: UtilityField.transit, key: "fixture", validScope: { true })
        await model.query()?.value
        XCTAssertEqual(model.chosen?.minutes, 24); XCTAssertFalse(model.busy)
        try model.confirm()
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["answers"][UtilityField.transit]["value"].string, "24")
        let changed = CommuteSearch(store: store, houseID: id, fieldID: UtilityField.transit, key: "fixture", validScope: { true })
        await changed.query()?.value
        try store.answer(id, field: UtilityField.transit, value: .string("31"))
        XCTAssertThrowsError(try changed.confirm())
        try store.call("settings", ["property": .string("workplace"), "value": .string("公司已搬迁")])
        XCTAssertThrowsError(try changed.confirm())
        await changed.query()?.value
        XCTAssertTrue(changed.routes.isEmpty); XCTAssertTrue(changed.message.contains("选定"))
        XCTAssertEqual(store.house(id)["answers"][UtilityField.transit]["value"].string, "31")
    }
    func testNetworkFixtureRequiresBothExplicitFlagAndIsolatedUUID() {
        #if DEBUG
        XCTAssertTrue(UtilityNetworkFixture.enabled(["--business-test", UUID().uuidString, "--utility-network-fixture"]))
        for arguments in [["--utility-network-fixture"], ["--business-test", "not-a-uuid", "--utility-network-fixture"], ["--business-test", UUID().uuidString]] {
            XCTAssertFalse(UtilityNetworkFixture.enabled(arguments))
        }
        #endif
    }
}
