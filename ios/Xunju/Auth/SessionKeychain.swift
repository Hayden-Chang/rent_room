import Foundation
import Security

struct LocalSession: Codable {
    let account: String
    let token: String
    let provider: String
    let packs: Int
    let expiresAt: Date
    let capacityRevision: Int?
    let capacityEnvironment: String?

    init(receipt: LoginReceipt, now: Date = Date()) throws {
        _ = try receipt.validated(provider: receipt.provider)
        guard ["phone", "apple", "wechat"].contains(receipt.provider) else { throw CoreFailure(message: "登录方式无效") }
        account = receipt.account; token = receipt.token; provider = receipt.provider; packs = receipt.packs
        expiresAt = now.addingTimeInterval(TimeInterval(receipt.expiresIn))
        capacityRevision = nil; capacityEnvironment = nil
    }
    private init(previous: LocalSession, balance: CapacityBalance) {
        account = previous.account; token = previous.token; provider = previous.provider; expiresAt = previous.expiresAt
        packs = balance.packs; capacityRevision = balance.revision; capacityEnvironment = balance.environment
    }
    func withCapacity(_ balance: CapacityBalance) -> LocalSession { LocalSession(previous: self, balance: balance) }
    func validateStored() throws {
        let receipt = LoginReceipt(account: account, token: token, provider: provider, expiresIn: 1, packs: packs,
                                   limit: packs >= 0 && packs <= (Int.max - 2) / 10 ? 2 + 10 * packs : -1)
        _ = try LocalSession(receipt: receipt)
        guard (capacityRevision == nil && capacityEnvironment == nil) || ((capacityRevision ?? -1) >= 0 && ["Production", "Sandbox"].contains(capacityEnvironment ?? "")),
              expiresAt.timeIntervalSince1970.isFinite else { throw CoreFailure(message: "登录状态无效") }
    }
}

/// Session tokens stay on this device and never enter state.json or ZIP exports.
struct SessionKeychain {
    private let service = "com.keeline.xunju.session"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: "current", kSecAttrSynchronizable as String: false]
    }

    func read() throws -> LocalSession? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw CoreFailure(message: "安全登录状态读取失败，请稍后重试")
        }
        do { return try JSONDecoder().decode(LocalSession.self, from: data) }
        catch { throw CoreFailure(message: "安全登录状态无效，请重新登录") }
    }
    func write(_ session: LocalSession) throws {
        let data = try JSONEncoder().encode(session)
        let changes = [kSecValueData as String: data, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String: Any]
        var status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(changes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw CoreFailure(message: "安全登录状态保存失败，请重试") }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CoreFailure(message: "安全登录状态清除失败，请重试") }
    }
}
