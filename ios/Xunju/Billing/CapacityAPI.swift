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
struct CapacityContext: Sendable {
    let available: Bool
    let productID: String?
    let appAccountToken: UUID
    let balance: CapacityBalance
}
struct CapacityConfirmation: Sendable {
    let transactionID: String
    let status: String
    let balance: CapacityBalance
}
protocol CapacityServicing: Sendable {
    func context(token: String) async throws -> CapacityContext
    func verify(_ transactionID: String, token: String) async throws -> CapacityConfirmation
    func restore(token: String) async throws -> CapacityBalance
}
struct CapacityAPI: CapacityServicing {
    var baseURL = URL(string: "https://api.keeline.xyz/api/rent-room/ios/storekit")!
    var transport: any AuthTransport = URLSessionAuthTransport()
    private struct Envelope: Decodable {
        let account: String; let environment: String; let packs: Int; let limit: Int; let revision: Int
        let available: Bool?; let productId: String?; let packSize: Int?; let appAccountToken: UUID?
        let transactionId: String?; let status: String?
        let capacity: CapacityPolicy?
        var balance: CapacityBalance { get throws { try CapacityBalance(account: account, environment: environment, packs: packs, limit: limit, revision: revision, capacity: capacity).validated() } }
    }
    func context(token: String) async throws -> CapacityContext {
        let value = try await request("context", token: token)
        guard let available = value.available, value.packSize == 10, let accountToken = value.appAccountToken,
              !available || !(value.productId ?? "").isEmpty else { throw CoreFailure(message: "房源包信息无效，请重试") }
        return try CapacityContext(available: available, productID: value.productId, appAccountToken: accountToken, balance: value.balance)
    }
    func verify(_ transactionID: String, token: String) async throws -> CapacityConfirmation {
        guard transactionID.range(of: "\\A[0-9]{1,32}\\z", options: .regularExpression) != nil else { throw CoreFailure(message: "购买记录标识无效") }
        let value = try await request("verify", token: token, body: ["transactionId": transactionID])
        guard value.transactionId == transactionID, let status = value.status, ["verified", "revoked"].contains(status) else { throw CoreFailure(message: "购买记录暂时无法确认，请恢复容量重试") }
        return try CapacityConfirmation(transactionID: transactionID, status: status, balance: value.balance)
    }
    func restore(token: String) async throws -> CapacityBalance { try await request("restore", token: token, body: [:]).balance }
    private func request(_ path: String, token: String, body: [String: String]? = nil) async throws -> Envelope {
        var request = URLRequest(url: baseURL.appending(path: path)); request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2", forHTTPHeaderField: "x-rent-room-capacity-version")
        if let body {
            request.httpMethod = "POST"; request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let response: HTTPPayload
        do { response = try await transport.send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw CoreFailure(message: "连接购买服务失败，请检查网络后重试") }
        guard (200...299).contains(response.status) else {
            struct Failure: Decodable { struct Detail: Decodable { let message: String }; let detail: Detail }
            throw CoreFailure(message: (try? JSONDecoder().decode(Failure.self, from: response.data))?.detail.message ?? "购买记录暂时无法确认，请稍后重试")
        }
        do { return try JSONDecoder().decode(Envelope.self, from: response.data) }
        catch { throw CoreFailure(message: "购买服务返回无效，请稍后重试") }
    }
}
