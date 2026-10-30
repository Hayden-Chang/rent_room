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

/// Local policy cache also reads the previous envelope; its URL is no longer used.
struct CapacityPolicyCache {
    let root: URL
    private struct Entry: Codable { let capacity: CapacityPolicy }
    private var file: URL { root.appending(path: "capacity-policy.json") }
    func read() -> CapacityPolicy {
        guard let data = try? Data(contentsOf: file), let entry = try? JSONDecoder().decode(Entry.self, from: data),
              let policy = try? entry.capacity.validated() else { return .initial }
        return policy
    }
    func write(_ policy: CapacityPolicy) throws {
        try JSONEncoder().encode(Entry(capacity: policy.validated())).write(to: file, options: .atomic)
    }
}
