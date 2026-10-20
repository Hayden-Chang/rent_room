#if DEBUG
import Foundation

// Only a UUID-isolated business run can opt into deterministic network data.
// It uses the real query parser, choose command, scope guards and persistence.
enum UtilityNetworkFixture {
    static func enabled(_ arguments: [String]) -> Bool {
        guard arguments.contains("--utility-network-fixture"), let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1) else { return false }
        return UUID(uuidString: arguments[index + 1]) != nil
    }
    static var enabled: Bool { enabled(ProcessInfo.processInfo.arguments) }
    static var transport: NativeMapTransport { NativeMapTransport(transport: FixtureHTTP()) }
    private struct FixtureHTTP: AuthTransport {
        func send(_ request: URLRequest) async throws -> HTTPPayload {
            guard let url = request.url, url.host == "api.tianditu.gov.cn" else { throw CoreFailure(message: "测试请求地址不符") }
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let post = items.first { $0.name == "postStr" }?.value ?? "{}"
            let value = try JSONDecoder().decode(JSONValue.self, from: Data(post.utf8))
            if url.path == "/geocoder" {
                guard let latitude = value["lat"].number, let longitude = value["lon"].number,
                      (30...32).contains(latitude), (121...123).contains(longitude) else {
                    throw CoreFailure(message: "测试地图中心未保持所选位置")
                }
            }
            if !value["pointLonlat"].string.isEmpty {
                let parts = value["pointLonlat"].string.split(separator: ",").compactMap { Double($0) }
                guard parts.count == 2, (121...123).contains(parts[0]), (30...32).contains(parts[1]) else {
                    throw CoreFailure(message: "测试地图中心未保持所选位置")
                }
            }
            let text: String
            switch url.path {
            case "/v2/search":
                if value["keyWord"].string.contains("办公") {
                    text = #"{"status":{"infocode":1000},"pois":[{"hotPointID":"office","name":"办公楼","address":"新城路8号","city":"上海市","lonlat":"121.4837,31.2404"}]}"#
                } else {
                    text = #"{"status":{"infocode":1000},"pois":[{"hotPointID":"house","name":"阳光小区","address":"朝阳路18号","city":"上海市","lonlat":"121.4737,31.2304"}]}"#
                }
            case "/geocoder":
                text = (value["lon"].number ?? 0) > 121.48
                    ? #"{"status":"0","result":{"formatted_address":"上海市新城路8号 办公楼","addressComponent":{"poi":"办公楼"}}}"#
                    : #"{"status":"0","result":{"formatted_address":"上海市朝阳路18号 阳光小区","addressComponent":{"poi":"阳光小区"}}}"#
            case "/transit": text = #"{"resultCode":0,"results":[{"lines":[{"segments":[{"segmentType":2,"segmentLine":[{"lineName":"地铁2号线","segmentTime":24,"segmentDistance":7200,"linePoint":"121.4737,31.2304;121.4787,31.2354;121.4837,31.2404"}]}]}]}]}"#
            default: throw CoreFailure(message: "测试夹具不支持此请求")
            }
            return HTTPPayload(data: Data(text.utf8), status: 200)
        }
    }
}
#endif
