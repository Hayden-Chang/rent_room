import Foundation

struct CapacityBalance: Codable, Sendable, Equatable {
    let account: String
    let environment: String
    let packs: Int
    let limit: Int
    let revision: Int
    var capacity: CapacityPolicy? = nil
    func validated() throws -> Self {
        try CapacityPolicy.validate(packs: packs, limit: limit, policy: capacity)
        guard account.range(of: "\\A[a-f0-9]{64}\\z", options: .regularExpression) != nil,
              ["Production", "Sandbox"].contains(environment), packs >= 0,
              revision >= 0 else { throw CoreFailure(message: "容量校验失败，请稍后重试") }
        return self
    }
}
