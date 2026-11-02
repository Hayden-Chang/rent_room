import XCTest
@testable import Xunju

@MainActor private final class TimedPlaceClient: NativePlacesClient {
    var reply: (@MainActor @Sendable (Result<[NativePlace], Error>) -> Void)?
    var immediate: [NativePlace]?
    var cancellations = 0
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] {
        try await SystemPlacesClient().perform(deadline: .milliseconds(20), cancel: { self.cancellations += 1 }) { complete in
            reply = complete
            if let immediate { complete(.success(immediate)) }
        }
    }
    func reverse(_ point: GeographicPoint) async throws -> NativePlace? { nil }
}

@MainActor private final class DelayedPlaceClient: NativePlacesClient {
    let started: XCTestExpectation
    private var reply: CheckedContinuation<[NativePlace], Error>?
    init(started: XCTestExpectation) { self.started = started }
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] {
        try await withCheckedThrowingContinuation { reply in self.reply = reply; started.fulfill() }
    }
    func reverse(_ point: GeographicPoint) async throws -> NativePlace? { nil }
    func finish() {
        reply?.resume(returning: [NativePlace(name: "过期地点", address: "旧地址", point: GeographicPoint(latitude: 31.2304, longitude: 121.4737))]); reply = nil
    }
}

@MainActor private struct UnavailableSystemPlaces: NativePlacesClient {
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] { throw URLError(.notConnectedToInternet) }
    func reverse(_ point: GeographicPoint) async throws -> NativePlace? { throw URLError(.notConnectedToInternet) }
}

private actor PlaceTransportCounter: MapTransport {
    var calls = 0
    func request(_ input: String) async throws -> String { calls += 1; throw URLError(.unsupportedURL) }
}

@MainActor private struct OverseasPlaces: NativePlacesClient {
    let place = NativePlace(name: "California", address: "California, United States",
                            point: GeographicPoint(latitude: 36.7783, longitude: -119.4179))
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] { [place] }
    func reverse(_ point: GeographicPoint) async throws -> NativePlace? { place }
}

@MainActor final class UtilityFlowTests: XCTestCase {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "utility-flows-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    func testPlaceSearchStartsWithoutTiandituKeyAndDoesNotChangeRecords() async throws {
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapKey: "")
        let search = PlaceSearch(store: workspace.store, places: workspace.places, validScope: { true })
        let before = workspace.store.state
        search.query = "上海东方明珠广播电视塔"
        let operation = search.submit()
        XCTAssertNotNil(operation, "System place search must start without a Tianditu key")
        XCTAssertEqual(search.message, "")
        search.cancel(); await operation?.value
        XCTAssertEqual(workspace.store.state, before)
    }
    func testConfiguredWorkspaceUsesApplePlacesAndPreservesSavedCoordinate() async throws {
        let transport = PlaceTransportCounter()
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapTransport: transport,
                                         mapKey: "fixture", places: UtilityNetworkFixture.places)
        let store = workspace.store
        let search = PlaceSearch(store: store, places: workspace.places, validScope: { true })
        let before = store.state
        search.query = "阳光"; await search.submit()?.value
        XCTAssertEqual(search.attribution, "系统地图"); XCTAssertEqual(search.message, ""); XCTAssertFalse(search.busy)
        let choice = try XCTUnwrap(search.choices.first), selected = try search.selected(choice)
        XCTAssertEqual(choice.name, "阳光小区"); XCTAssertEqual(store.state, before)
        let restoredPoint = try XCTUnwrap(search.nativePoint(selected["location"]))
        XCTAssertEqual(restoredPoint.latitude, choice.point.latitude, accuracy: 0.000001)
        XCTAssertEqual(restoredPoint.longitude, choice.point.longitude, accuracy: 0.000001)
        XCTAssertNotEqual(GeographicPoint(selected["location"]), choice.point, "Canonical GCJ-02 storage must be retained")
        try store.call("workplacePlace", ["value": selected]); search.didSelect(choice)
        XCTAssertTrue(search.choices.isEmpty); XCTAssertFalse(search.busy)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).state["settings"]["workplaceLocation"], selected["location"])
        await search.submit()?.value
        XCTAssertTrue(search.choices.contains { $0.id == "center" }, "Reopening the map must use the canonical reverse-geocoding result")
        let calls = await transport.calls; XCTAssertEqual(calls, 0, "A configured Tianditu key must not route iOS place queries to the JS transport")
        search.cancel()
    }
    func testOverseasSelectionKeepsWGS84AndPersistsHouseAndWorkplace() async throws {
        let store = try NativeStore(directory: root()), id = try store.add("海外房源")
        let client = OverseasPlaces()
        let search = PlaceSearch(store: store, places: NativePlaceService(client: client), validScope: { true })
        search.query = "California"; await search.submit()?.value
        let choice = try XCTUnwrap(search.choices.first), selected = try search.selected(choice)
        XCTAssertEqual(GeographicPoint(selected["location"]), client.place.point, "Coordinates outside China must not be shifted")
        try store.call("place", ["id": .string(id), "value": selected])
        try store.call("workplacePlace", ["value": selected])
        search.didSelect(choice)
        XCTAssertEqual(search.center, client.place.point)
        XCTAssertTrue(search.choices.isEmpty)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["address"].string, client.place.address)
        XCTAssertEqual(GeographicPoint(restored.house(id)["location"]), client.place.point)
        XCTAssertEqual(GeographicPoint(restored.state["settings"]["workplaceLocation"]), client.place.point)
    }
    func testAppleFailureKeepsSavedAddressAndDoesNotFallbackToTianditu() async throws {
        let transport = PlaceTransportCounter()
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapTransport: transport,
                                         mapKey: "fixture", places: NativePlaceService(client: UnavailableSystemPlaces()))
        try workspace.store.call("settings", ["property": .string("workplace"), "value": .string("已保存地址")])
        let before = workspace.store.state
        let search = PlaceSearch(store: workspace.store, places: workspace.places, validScope: { true })
        search.query = "California"; await search.submit()?.value
        XCTAssertTrue(search.choices.isEmpty); XCTAssertFalse(search.busy)
        XCTAssertEqual(search.message, "地点查询失败，请重试或手动填写地址")
        XCTAssertEqual(workspace.store.state, before)
        let calls = await transport.calls; XCTAssertEqual(calls, 0)
    }
    func testUsingPlaceDismissesCandidatesUntilAnotherSearch() async throws {
        let store = try NativeStore(directory: root())
        let search = PlaceSearch(store: store, places: UtilityNetworkFixture.places, validScope: { true })
        search.query = "阳光"; await search.submit()?.value
        let choice = try XCTUnwrap(search.choices.first)
        try store.call("workplacePlace", ["value": search.selected(choice)])
        search.didSelect(choice)
        defer { search.cancel() }
        XCTAssertFalse(search.busy, "Using a place must not start another nearby query")
        XCTAssertTrue(search.choices.isEmpty)
        XCTAssertEqual(search.query, "")
        XCTAssertThrowsError(try search.selected(choice), "Dismissed candidates must no longer be selectable")
        search.synchronizeLocation(store.state["settings"]["workplaceLocation"])
        XCTAssertFalse(search.busy)
        XCTAssertTrue(search.choices.isEmpty)
        search.query = "办公楼"; await search.submit()?.value
        XCTAssertFalse(search.choices.isEmpty, "An explicit new search must reopen candidates")
        XCTAssertTrue(store.state["settings"]["workplace"].string.contains("阳光小区"))
    }
    func testHouseSelectionRoundTripKeepsCandidatesDismissed() async throws {
        let store = try NativeStore(directory: root()), id = try store.add("坐标回显")
        let search = PlaceSearch(store: store, places: UtilityNetworkFixture.places, validScope: { true })
        search.query = "阳光"; await search.submit()?.value
        let choice = try XCTUnwrap(search.choices.first)
        try store.call("place", ["id": .string(id), "value": search.selected(choice)])
        let saved = store.house(id)["location"]
        XCTAssertNotEqual(GeographicPoint(saved), choice.point, "Storage remains GCJ-02")
        search.didSelect(choice)
        XCTAssertEqual(search.center, search.nativePoint(saved), "The camera must use the same canonical round-trip point as persisted state")
        search.synchronizeLocation(saved)
        XCTAssertFalse(search.busy, "Reading back the selected location must not reopen candidates")
        XCTAssertTrue(search.choices.isEmpty)
        let point = try XCTUnwrap(search.center)
        search.moved(point)
        XCTAssertFalse(search.busy, "Programmatic camera recentering must not reopen candidates")
        search.moved(GeographicPoint(latitude: point.latitude + 0.01, longitude: point.longitude))
        XCTAssertTrue(search.busy, "Moving the map to another point must allow a new search")
        search.cancel()
    }
    func testPlaceSelectionPersistsCanonicalAddressAndWorkplaceWithoutChangingAnswers() async throws {
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapKey: "", places: UtilityNetworkFixture.places)
        let store = workspace.store, id = try store.add("联动房源")
        try store.answer(id, field: "f1_6", value: .string("2800"))
        let search = PlaceSearch(store: store, places: workspace.places, validScope: { workspace.store === store })
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
    func testTimedOutSearchStopsLoadingPreservesAddressAndAllowsFreshSearch() async throws {
        let store = try NativeStore(directory: root())
        try store.call("settings", ["property": .string("workplace"), "value": .string("Saved address")])
        let before = store.state, client = TimedPlaceClient()
        let search = PlaceSearch(store: store, places: NativePlaceService(client: client), validScope: { true })
        search.query = "California"; await search.submit()?.value
        XCTAssertFalse(search.busy); XCTAssertTrue(search.choices.isEmpty)
        XCTAssertEqual(search.message, "地点查询失败，请重试或手动填写地址")
        XCTAssertEqual(store.state, before); XCTAssertEqual(client.cancellations, 1)
        let stale = client.reply
        client.immediate = [NativePlace(name: "Cupertino", address: "Cupertino, CA", point: .init(latitude: 37.33, longitude: -122.03))]
        search.query = "Cupertino"; await search.submit()?.value
        let current = search.choices
        stale?(.success([NativePlace(name: "Wrong old result", address: "Old address", point: .init(latitude: 0, longitude: 0))]))
        XCTAssertFalse(search.busy); XCTAssertTrue(search.message.isEmpty)
        XCTAssertEqual(search.choices.map(\.id), current.map(\.id)); XCTAssertEqual(search.choices.first?.name, "Cupertino")
        XCTAssertEqual(store.state, before)
    }
    func testCancelledPlaceResponseDoesNotRestoreCandidatesOrChangeRecords() async throws {
        let started = expectation(description: "Read-only query started"), client = DelayedPlaceClient(started: started)
        let store = try NativeStore(directory: root())
        let search = PlaceSearch(store: store, places: NativePlaceService(client: client), validScope: { true }), before = store.state
        search.query = "旧地址"; let operation = search.submit()
        let result = await XCTWaiter.fulfillment(of: [started], timeout: 3)
        XCTAssertEqual(result, .completed)
        search.cancel(); client.finish(); await operation?.value
        XCTAssertTrue(search.choices.isEmpty); XCTAssertFalse(search.busy); XCTAssertEqual(store.state, before)
    }
    func testSystemPlacesKeepManualWorkplaceAndCanSearchWithoutMapKey() async throws {
        let workspace = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), mapKey: "", places: UtilityNetworkFixture.places)
        try workspace.store.call("settings", ["property": .string("workplace"), "value": .string("手工填写办公楼")])
        let search = PlaceSearch(store: workspace.store, places: workspace.places, validScope: { true }); search.query = "办公楼"
        await search.submit()?.value
        XCTAssertFalse(search.choices.isEmpty); XCTAssertEqual(search.message, "")
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
    func testClearingOrInvalidatingLocationRemovesDisplayedPointAndOldCandidates() async throws {
        let store = try NativeStore(directory: root(), network: UtilityNetworkFixture.transport)
        let search = PlaceSearch(store: store, places: UtilityNetworkFixture.places, validScope: { true })
        search.query = "阳光"; await search.submit()?.value
        let place = try XCTUnwrap(search.choices.first)
        search.synchronizeLocation(try search.selected(place)["location"])
        XCTAssertNotNil(search.center)
        search.synchronizeLocation(.null)
        XCTAssertNil(search.center); XCTAssertTrue(search.choices.isEmpty)
        search.query = "办公楼"; await search.submit()?.value
        search.reset()
        XCTAssertNil(search.center); XCTAssertEqual(search.query, ""); XCTAssertTrue(search.choices.isEmpty)
    }
}
