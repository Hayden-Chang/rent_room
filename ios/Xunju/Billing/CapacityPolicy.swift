import Foundation

struct CapacityPolicy: Codable, Sendable, Equatable {
    let version: Int
    let freeLimit: Int
    static let initial = CapacityPolicy(version: 2, freeLimit: 1)
    func validated() throws -> Self {
        guard version == 2, freeLimit >= 0, freeLimit <= 9_007_199_254_740_991 else {
            throw CoreFailure(message: "房源额度信息无效，请稍后重试")
        }
        return self
    }
    static func validate(packs: Int, limit: Int, policy: CapacityPolicy?) throws {
        let free = try policy?.validated().freeLimit
        guard packs >= 0, packs <= (9_007_199_254_740_991 - (free ?? 2)) / 10,
              (free.map { limit == $0 + packs * 10 } ?? [1 + packs * 10, 2 + packs * 10].contains(limit)) else {
            throw CoreFailure(message: "房源额度信息无效，请稍后重试")
        }
    }
}

protocol CapacityPolicyServicing: Sendable {
    func fetch() async throws -> CapacityPolicy?
}

struct CapacityPolicyAPI: CapacityPolicyServicing {
    static let endpoint = URL(string: "https://api.keeline.xyz/api/rent-room/catalog")!
    var transport: any AuthTransport = URLSessionAuthTransport()
    func fetch() async throws -> CapacityPolicy? {
        var request = URLRequest(url: Self.endpoint)
        request.timeoutInterval = 12; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("2", forHTTPHeaderField: "x-rent-room-capacity-version")
        let result = try await transport.send(request)
        guard (200...299).contains(result.status) else { throw CoreFailure(message: "暂时无法刷新房源额度，已保留上次额度") }
        struct Catalog: Decodable { let capacity: CapacityPolicy? }
        return try JSONDecoder().decode(Catalog.self, from: result.data).capacity?.validated()
    }
}

struct CapacityPolicyCache {
    let root: URL
    private struct Entry: Codable { let url: String; let capacity: CapacityPolicy }
    private var file: URL { root.appending(path: "capacity-policy.json") }
    func read() -> CapacityPolicy {
        guard let data = try? Data(contentsOf: file), let entry = try? JSONDecoder().decode(Entry.self, from: data),
              entry.url == CapacityPolicyAPI.endpoint.absoluteString, let policy = try? entry.capacity.validated() else { return .initial }
        return policy
    }
    func write(_ policy: CapacityPolicy) throws {
        let entry = try Entry(url: CapacityPolicyAPI.endpoint.absoluteString, capacity: policy.validated())
        try JSONEncoder().encode(entry).write(to: file, options: .atomic)
    }
}
