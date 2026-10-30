import Foundation
import CryptoKit

/// Apple-signed app acquisition, independent of the app's former login/session.
/// The signed proof stays in memory and is never sent to our services.
struct PurchaseIdentity: Sendable, Equatable {
    let appTransactionID: String
    let bundleID: String
    let environment: String
    let signedAppTransaction: String
    var account: String {
        SHA256.hash(data: Data("rent-room-app-store-v1:\(bundleID):\(environment):\(appTransactionID)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
    var accountToken: UUID {
        let value = Array(account.prefix(32))
        let parts = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32].map { String(value[$0]) }
        return UUID(uuidString: parts.joined(separator: "-"))!
    }
    func validated() throws -> Self {
        guard appTransactionID.range(of: "\\A[0-9]{1,32}\\z", options: .regularExpression) != nil,
              !bundleID.isEmpty, ["Production", "Sandbox"].contains(environment),
              !signedAppTransaction.isEmpty else {
            throw CoreFailure(message: "无法确认 App Store 购买身份，请稍后恢复容量")
        }
        return self
    }
}

/// Purchase capacity is not part of a house backup or a former login session.
struct PurchaseCapacityCache {
    let root: URL
    private var url: URL { root.appending(path: "purchase-capacity.json") }
    func read() throws -> CapacityBalance? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do { return try JSONDecoder().decode(CapacityBalance.self, from: Data(contentsOf: url)).validated() }
        catch { throw CoreFailure(message: "本机购买容量读取失败，原记录已保留，请恢复容量") }
    }
    func legacyPacks(seed: Int?) throws -> Int {
        let file = root.appending(path: "local-legacy-capacity.json")
        if let seed {
            try JSONEncoder().encode(seed).write(to: file, options: .atomic)
            return seed
        }
        guard FileManager.default.fileExists(atPath: file.path) else { return 0 }
        let packs = try JSONDecoder().decode(Int.self, from: Data(contentsOf: file))
        guard packs >= 0, packs <= 900_719_925_474_098 else { throw CoreFailure(message: "原有本机容量读取失败，原记录已保留") }
        return packs
    }
    func write(_ balance: CapacityBalance) throws {
        _ = try balance.validated()
        try JSONEncoder().encode(balance).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
