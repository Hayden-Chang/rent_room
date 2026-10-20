import Foundation

protocol MapTransport: Sendable {
    func request(_ input: String) async throws -> String
}

/// Only the original Tianditu GET endpoints can be reached from JavaScriptCore.
struct NativeMapTransport: MapTransport {
    var transport: any AuthTransport = URLSessionAuthTransport()
    private struct Input: Decodable { let url: String; let method: String; let timeout: Double; let data: [String: JSONValue] }
    func request(_ input: String) async throws -> String {
        let value = try JSONDecoder().decode(Input.self, from: Data(input.utf8))
        guard var components = URLComponents(string: value.url), components.scheme == "https", components.host == "api.tianditu.gov.cn",
              components.user == nil, components.password == nil, components.port == nil,
              ["/v2/search", "/geocoder", "/transit", "/drive"].contains(components.path), value.method == "GET",
              value.timeout > 0, value.timeout <= 12000 else { throw CoreFailure(message: "地点查询请求无效") }
        components.queryItems = value.data.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value.string) }
        guard let url = components.url else { throw CoreFailure(message: "地点查询请求无效") }
        var request = URLRequest(url: url); request.timeoutInterval = value.timeout / 1000
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let response = try await transport.send(request)
        guard response.data.count <= 16 * 1024 * 1024 else { throw CoreFailure(message: "地点查询结果过大，请缩小查询范围") }
        let body = (try? JSONDecoder().decode(JSONValue.self, from: response.data)) ?? .string(String(data: response.data, encoding: .utf8) ?? "")
        let result: JSONValue = .object(["statusCode": .number(Double(response.status)), "data": body])
        return String(decoding: try JSONEncoder().encode(result), as: UTF8.self)
    }
}

struct NativeConfiguration: Decodable {
    let tiandituKey: String
    static var current: NativeConfiguration {
        guard let url = Bundle.main.url(forResource: "NativeConfiguration", withExtension: "json"),
              let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(Self.self, from: data) else { return Self(tiandituKey: "") }
        return value
    }
}
