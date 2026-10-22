import XCTest
@testable import Xunju

private struct MapHTTPStub: AuthTransport {
    let handler: @Sendable (URLRequest) throws -> HTTPPayload
    func send(_ request: URLRequest) async throws -> HTTPPayload { try handler(request) }
}

private struct DelayedRouteHTTP: AuthTransport {
    let returned: XCTestExpectation
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        try await Task.sleep(for: .milliseconds(30))
        returned.fulfill()
        return HTTPPayload(data: Data(#"{"resultCode":0,"results":[{"lines":[{"segments":[{"segmentType":2,"segmentLine":[{"lineName":"2路","segmentTime":12,"segmentDistance":1800,"linePoint":"121.4737,31.2304;121.4837,31.2404"}]}]}]}]}"#.utf8), status: 200)
    }
}

private struct EncodedRouteTransport: MapTransport {
    let returned: XCTestExpectation
    func request(_ input: String) async throws -> String {
        let result = try await NativeMapTransport(transport: DelayedRouteHTTP(returned: XCTestExpectation(description: "HTTP returned"))).request(input)
        returned.fulfill()
        return result
    }
}

private actor DeferredRouteTransport: MapTransport {
    let started: XCTestExpectation
    private var pending: CheckedContinuation<String, Error>?
    init(started: XCTestExpectation) { self.started = started }
    func request(_ input: String) async throws -> String {
        try await withCheckedThrowingContinuation { pending = $0; started.fulfill() }
    }
    func finish() { pending?.resume(returning: #"{"statusCode":200,"data":{"resultCode":0,"results":[]}}"#); pending = nil }
}

@MainActor final class MapCoreTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "map-core-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }; return url
    }
    private func point(_ latitude: Double, _ longitude: Double) -> JSONValue { .object(["latitude": .number(latitude), "longitude": .number(longitude)]) }
    private func response(_ text: String) -> NativeMapTransport {
        NativeMapTransport(transport: MapHTTPStub { _ in HTTPPayload(data: Data(text.utf8), status: 200) })
    }
    func testPlaceSearchUsesCanonicalParsingAndCoordinateBoundaryWithoutMutation() async throws {
        let payload = #"{"status":{"infocode":1000},"pois":[{"hotPointID":"p1","name":"阳光小区","address":"朝阳路18号","city":"上海市","lonlat":"121.4737,31.2304"}]}"#
        let transport = NativeMapTransport(transport: MapHTTPStub { request in
            XCTAssertEqual(request.url?.host, "api.tianditu.gov.cn")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            let post = try XCTUnwrap(query?.first { $0.name == "postStr" }?.value)
            XCTAssertTrue(post.contains("阳光小区")); XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            return HTTPPayload(data: Data(payload.utf8), status: 200)
        })
        let store = try NativeStore(directory: directory(), network: transport), before = store.state
        let wgs = point(31.2304, 121.4737)
        let converted = try store.call("coordinate", ["property": .string("toMap"), "value": wgs])
        let back = try store.call("coordinate", ["property": .string("fromMap"), "value": converted])
        XCTAssertEqual(back["latitude"].number ?? 0, 31.2304, accuracy: 0.000001)
        XCTAssertNotEqual(converted, wgs)
        let result = try await store.query("searchPlaces", ["key": .string("fixture"), "query": .string("阳光小区"), "center": converted]).array
        XCTAssertEqual(result.first?["name"].string, "阳光小区")
        XCTAssertEqual(result.first?["location"], converted)
        XCTAssertEqual(result.first?["address"].string, "上海市朝阳路18号 阳光小区")
        XCTAssertEqual(store.state, before)
    }
    func testRouteQueryAndConfirmedWriteRetainNotesAndRejectChangedEndpointsOrValue() async throws {
        let payload = #"{"resultCode":0,"results":[{"lines":[{"segments":[{"segmentType":2,"segmentLine":[{"lineName":"2路","segmentTime":12,"segmentDistance":1800,"linePoint":"121.4737,31.2304;121.4837,31.2404"}]}]}]}]}"#
        let store = try NativeStore(directory: directory(), network: response(payload)), id = try store.add("路线房源")
        let origin = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2304, 121.4737)])
        let destination = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2404, 121.4837)])
        try store.call("place", ["id": .string(id), "value": .object(["name": .string("公寓"), "address": .string("朝阳路18号"), "location": origin])])
        try store.call("workplacePlace", ["value": .object(["address": .string("办公楼"), "location": destination])])
        let endpoints = try store.call("endpoints", ["id": .string(id)])
        let routes = try await store.query("commuteRoutes", ["key": .string("fixture"), "mode": .string("transit"), "origin": origin, "destination": destination]).array
        XCTAssertEqual(routes.first?["minutes"].int, 12)
        XCTAssertEqual(routes.first?["polyline"].array.first?["points"].array.count, 2)
        let field = "21255282-3663-4abe-b7de-d91eeb3825ed"
        try store.answer(id, field: field, property: "note", value: .string("早高峰复核"))
        let result: JSONValue = .object(["amount": .number(12), "previous": .null, "stamp": endpoints["stamp"]])
        try store.call("computed", ["id": .string(id), "field": .string(field), "value": result])
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["answers"][field]["value"].string, "12")
        XCTAssertEqual(store.house(id)["answers"][field]["note"].string, "早高峰复核")
        try store.answer(id, field: field, value: .string("13"))
        XCTAssertThrowsError(try store.call("computed", ["id": .string(id), "field": .string(field), "value": result.setting("previous", to: .string("12"))]))
        try store.call("settings", ["property": .string("workplace"), "value": .string("另一座公司")])
        XCTAssertEqual(try store.call("endpoints", ["id": .string(id)])["destination"]["location"], .null)
        XCTAssertThrowsError(try store.call("computed", ["id": .string(id), "field": .string(field), "value": result.setting("previous", to: .string("13"))]))
        XCTAssertEqual(store.house(id)["answers"][field]["value"].string, "13")
    }
    func testNegativeRouteTimeAndMissingKeyNeverProduceAResult() async throws {
        let payload = #"{"resultCode":0,"results":[{"lines":[{"segments":[{"segmentType":2,"segmentLine":[{"lineName":"2路","segmentTime":-2,"segmentDistance":1800,"linePoint":"121.4737,31.2304;121.4837,31.2404"}]}]}]}]}"#
        let store = try NativeStore(directory: directory(), network: response(payload))
        let origin = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2304, 121.4737)])
        let destination = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2404, 121.4837)])
        do { _ = try await store.query("commuteRoutes", ["key": .string("fixture"), "mode": .string("transit"), "origin": origin, "destination": destination]); XCTFail("Negative route must be rejected") }
        catch { XCTAssertTrue(error.localizedDescription.contains("暂未查到可用路线")) }
        do { _ = try await store.query("searchPlaces", ["query": .string("地址")]); XCTFail("No key must return manual fallback") }
        catch { XCTAssertTrue(error.localizedDescription.contains("手动填写")) }
    }
    func testCoachPreferenceAndTargetPreserveAnswersAndPersist() throws {
        let store = try NativeStore(directory: directory()), id = try store.add("引导房源")
        try store.answer(id, field: "f1_6", value: .string("2800"))
        let answers = store.house(id)["answers"], coach = try store.call("coach", ["id": .string(id)])
        XCTAssertEqual(coach["steps"].array.map { $0["title"].string }, ["房源信息", "现场检查", "询问与签约", "左滑检查项"])
        XCTAssertFalse(coach["target"]["field"].id.isEmpty)
        try store.call("coachFinish", ["value": .bool(true)])
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertFalse(restored.state["settings"]["onboarding"].bool)
        XCTAssertEqual(restored.house(id)["answers"], answers)
    }
    func testComputedValueFailureRollsBackAndPreservesPreviousAnswer() throws {
        let store = try NativeStore(directory: directory()), id = try store.add("测速保存")
        let field = "d244dc92-351e-4f3c-8738-45295fec9ff9"
        try store.answer(id, field: field, value: .string("10"))
        let file = store.records.directory.appending(path: "state.json")
        try FileManager.default.removeItem(at: file); try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        let result: JSONValue = .object(["amount": .number(108.25), "previous": .string("10")])
        XCTAssertThrowsError(try store.call("computed", ["id": .string(id), "field": .string(field), "value": result]))
        XCTAssertEqual(store.house(id)["answers"][field]["value"].string, "10")
        try FileManager.default.removeItem(at: file)
        try store.call("computed", ["id": .string(id), "field": .string(field), "value": result])
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["answers"][field]["value"].string, "108.25")
    }
    func testSuspendedRouteResponseCompletesJavaScriptBridge() async throws {
        let returned = expectation(description: "Native transport returned")
        let completed = expectation(description: "JavaScript route reply completed")
        let store = try NativeStore(directory: directory(), network: EncodedRouteTransport(returned: returned))
        let before = store.state
        let origin = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2304, 121.4737)])
        let destination = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2404, 121.4837)])
        var routes: [JSONValue] = [], failure = ""
        let task = Task { @MainActor in
            do { routes = try await store.query("commuteRoutes", ["key": .string("fixture"), "mode": .string("transit"), "origin": origin, "destination": destination]).array }
            catch { failure = error.localizedDescription }
            completed.fulfill()
        }
        defer { task.cancel() }
        let sent = await XCTWaiter.fulfillment(of: [returned], timeout: 3)
        XCTAssertEqual(sent, .completed)
        let result = await XCTWaiter.fulfillment(of: [completed], timeout: 3)
        XCTAssertEqual(result, .completed, "The completed transport must settle the JavaScript promise on supported iOS runtimes")
        if result == .completed {
            XCTAssertEqual(failure, ""); XCTAssertEqual(routes.first?["minutes"].int, 12)
            XCTAssertEqual(store.state, before, "Querying must not mutate saved records")
        }
    }
    func testCancellingPendingRouteQueryCompletesBeforeTransportReturns() async throws {
        let started = expectation(description: "Route request started"), completed = expectation(description: "Cancelled query completed")
        let transport = DeferredRouteTransport(started: started), store = try NativeStore(directory: directory(), network: transport)
        let origin = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2304, 121.4737)])
        let destination = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2404, 121.4837)])
        var cancelled = false
        let task = Task { @MainActor in
            do { _ = try await store.query("commuteRoutes", ["key": .string("fixture"), "mode": .string("transit"), "origin": origin, "destination": destination]) }
            catch { cancelled = error is CancellationError }
            completed.fulfill()
        }
        let sent = await XCTWaiter.fulfillment(of: [started], timeout: 3); XCTAssertEqual(sent, .completed)
        task.cancel()
        let finished = await XCTWaiter.fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(finished, .completed, "Cancelling a route must settle its continuation without waiting for network/JS completion")
        await transport.finish()
        guard finished == .completed else { return }
        await task.value
        XCTAssertTrue(cancelled, "A cancelled route must never be treated as a provider response")
    }
    // Supplementary provider integration. A configured browser key opts in;
    // public coordinates only, with status/count evidence and no credential URL.
    func testLiveNativeRouteProviderReturnsUsablePublicRoute() async throws {
        guard !NativeConfiguration.current.tiandituKey.isEmpty else { throw XCTSkip("Live provider requires a configured browser key") }
        let input: JSONValue = .object(["url": .string("https://api.tianditu.gov.cn/transit"), "method": .string("GET"), "timeout": .number(12000), "data": .object(["tk": .string(NativeConfiguration.current.tiandituKey), "type": .string("busline"), "postStr": .string(#"{"startposition":"121.4737,31.2304","endposition":"121.4837,31.2404","linetype":"7"}"#)])])
        let text = try await NativeMapTransport().request(String(decoding: JSONEncoder().encode(input), as: UTF8.self))
        let response = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)), data = response["data"]
        let report = "HTTP=\(response["statusCode"].int), code=\(data["code"].string), message=\(data["msg"].string), resultCode=\(data["resultCode"].string), count=\(data["results"].array.count)"
        let attachment = XCTAttachment(string: report); attachment.name = "native-public-route-provider-result"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertEqual(response["statusCode"].int, 200, report)
        XCTAssertFalse(data["results"].array.isEmpty, report)
    }
    func testStalledRouteDeadlineCompletesAndLateReplyCannotChangeRecords() async throws {
        let started = expectation(description: "Route started"), completed = expectation(description: "Deadline settled")
        let transport = DeferredRouteTransport(started: started)
        let store = try NativeStore(directory: directory(), network: transport, mapQueryTimeout: .milliseconds(50))
        let before = store.state
        let origin = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2304, 121.4737)])
        let destination = try store.call("coordinate", ["property": .string("toMap"), "value": point(31.2404, 121.4837)])
        var failure = ""
        let task = Task { @MainActor in
            do { _ = try await store.query("commuteRoutes", ["key": .string("fixture"), "mode": .string("transit"), "origin": origin, "destination": destination]) }
            catch { failure = error.localizedDescription }
            completed.fulfill()
        }
        let sent = await XCTWaiter.fulfillment(of: [started], timeout: 2); XCTAssertEqual(sent, .completed)
        let settled = await XCTWaiter.fulfillment(of: [completed], timeout: 1)
        XCTAssertEqual(settled, .completed)
        await transport.finish()
        guard settled == .completed else { task.cancel(); return }
        await task.value
        XCTAssertTrue(failure.contains("超时")); XCTAssertEqual(store.state, before)
    }
    func testTransportRejectsUntrustedDomainsAndUnsupportedMethodsBeforeSending() async throws {
        let transport = NativeMapTransport(transport: MapHTTPStub { _ in XCTFail("Invalid request reached network"); return HTTPPayload(data: Data(), status: 500) })
        for (url, method) in [("https://example.com/geocoder", "GET"), ("https://api.tianditu.gov.cn/transit", "POST"), ("https://api.tianditu.gov.cn/private", "GET")] {
            let input: JSONValue = .object(["url": .string(url), "method": .string(method), "timeout": .number(8000), "data": .object([:])])
            do { _ = try await transport.request(String(decoding: JSONEncoder().encode(input), as: UTF8.self)); XCTFail("Invalid endpoint accepted") }
            catch { XCTAssertEqual(error.localizedDescription, "地点查询请求无效") }
        }
    }
}
