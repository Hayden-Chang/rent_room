import XCTest
import MapKit
@testable import Xunju

@MainActor private final class PlacesClientStub: NativePlacesClient {
    var results: Result<[NativePlace], Error> = .success([])
    var address: Result<NativePlace?, Error> = .success(nil)
    var queries: [String] = []
    var centers: [GeographicPoint?] = []
    var reverseCalls = 0
    func search(_ keyword: String, center: GeographicPoint?) async throws -> [NativePlace] {
        queries.append(keyword); centers.append(center); return try results.get()
    }
    func reverse(_ point: GeographicPoint) async throws -> NativePlace? {
        reverseCalls += 1; return try address.get()
    }
}

@MainActor final class SystemPlacesTests: XCTestCase {
    private let origin = GeographicPoint(latitude: 31.2304, longitude: 121.4737)
    private func place(_ name: String = "阳光小区", offset: Double = 0, address: String = "上海市朝阳路18号") -> NativePlace {
        NativePlace(name: name, address: address, point: GeographicPoint(latitude: origin.latitude + offset, longitude: origin.longitude))
    }
    func testSystemSearchKeepsNamesAddressesAndCoordinateOrderWithoutCredentials() async throws {
        let client = PlacesClientStub(), nearby = place(), far = place("远处小区", offset: 0.02)
        client.results = .success([far, nearby, nearby, place("空地址", address: ""),
                                  NativePlace(name: "无效", address: "无效", point: GeographicPoint(latitude: 91, longitude: 0))])
        let values = try await NativePlaceService(client: client).query("阳光", center: origin)
        XCTAssertEqual(client.queries, ["阳光"]); XCTAssertEqual(client.centers, [origin]); XCTAssertEqual(client.reverseCalls, 0)
        XCTAssertEqual(values.map(\.name), ["阳光小区", "远处小区"])
        XCTAssertEqual(values.first?.address, "上海市朝阳路18号 阳光小区")
        XCTAssertEqual(values.first?.point, origin); XCTAssertEqual(values.first?.distance, "0米")
        XCTAssertTrue(values[1].distance.hasSuffix("公里"))
    }
    func testNearbyKeepsExactSelectedPointWhenLocalSearchFails() async throws {
        let client = PlacesClientStub()
        client.address = .success(place("定位地址", offset: 0.001))
        client.results = .failure(URLError(.notConnectedToInternet))
        let values = try await NativePlaceService(client: client).query("", center: origin)
        XCTAssertEqual(values.count, 1); XCTAssertEqual(values.first?.id, "center")
        XCTAssertEqual(values.first?.point, origin, "Reverse geocoder must not move the user's chosen pin")
        XCTAssertEqual(values.first?.distance, "选点位置")
        XCTAssertEqual(client.reverseCalls, 1); XCTAssertEqual(client.queries, ["小区"])
    }
    func testNearbyKeepsSearchResultsWhenReverseGeocodingFailsAndLimitsCandidates() async throws {
        let client = PlacesClientStub(); client.address = .failure(URLError(.timedOut))
        client.results = .success((0..<20).map { place("小区\($0)", offset: Double($0) * 0.001) })
        let values = try await NativePlaceService(client: client).query("", center: origin)
        XCTAssertEqual(values.count, 10); XCTAssertFalse(values.contains { $0.id == "center" })
        XCTAssertEqual(values.first?.name, "小区0")
    }
    func testFailuresAndCancellationNeverInventSelectableLocations() async throws {
        let client = PlacesClientStub()
        client.address = .failure(URLError(.timedOut)); client.results = .failure(URLError(.notConnectedToInternet))
        do { _ = try await NativePlaceService(client: client).query("", center: origin); XCTFail("Both providers failed") }
        catch { XCTAssertEqual(error.localizedDescription, "地点查询失败，请重试或手动填写地址") }
        client.results = .success([]); client.address = .success(nil)
        let empty = try await NativePlaceService(client: client).query("", center: origin); XCTAssertTrue(empty.isEmpty)
        let before = client.queries.count
        let operation = Task { @MainActor in try await NativePlaceService(client: client).query("取消", center: origin) }
        operation.cancel()
        do { _ = try await operation.value; XCTFail("Cancelled search returned results") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(client.queries.count, before)
    }
    // Live SDK diagnostic uses only a public landmark, no user location or fixtures.
    func testLivePublicLandmarkSearchCompletesWithRealMapKitResults() async throws {
        do {
            let values = try await SystemPlacesClient().search("上海东方明珠广播电视塔", center: nil)
            XCTAssertTrue(values.contains { $0.name.contains("东方明珠") || $0.address.contains("东方明珠") })
        } catch {
            var codes: [String] = [], current: NSError? = error as NSError
            for _ in 0..<5 {
                guard let value = current else { break }
                codes.append("\(value.domain):\(value.code)")
                current = value.userInfo[NSUnderlyingErrorKey] as? NSError
            }
            let detail = codes.joined(separator: " -> ")
            let attachment = XCTAttachment(string: detail); attachment.name = "public-landmark-sdk-error-codes"; attachment.lifetime = .keepAlways; add(attachment)
            XCTFail("Public landmark SDK request failed: " + detail)
        }
    }
    func testMapKitItemConvertsAddressAndCoordinatesWithoutProviderSpecificFields() throws {
        guard #available(iOS 26.0, *) else { throw XCTSkip("Modern MapKit address representation is iOS 26+") }
        let item = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude),
                             address: MKAddress(fullAddress: "上海市朝阳路18号", shortAddress: "朝阳路18号"))
        item.name = "阳光小区"
        let value = try XCTUnwrap(SystemPlacesClient.place(item))
        XCTAssertEqual(value.name, "阳光小区"); XCTAssertEqual(value.address, "上海市朝阳路18号"); XCTAssertEqual(value.point, origin)
    }
}
