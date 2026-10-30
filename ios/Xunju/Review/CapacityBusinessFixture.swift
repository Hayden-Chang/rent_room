#if DEBUG
import Foundation

/// Explicit UUID-scoped tests replace Apple responses, retaining the real local
/// controller, ledger, capacity persistence and production pages. No fake server.
enum CapacityBusinessFixture {
    static let identity = PurchaseIdentity(appTransactionID: "9001", bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "fixture-app-proof")
    static func mode(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let test = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(test + 1), UUID(uuidString: arguments[test + 1]) != nil,
              let index = arguments.firstIndex(of: "--capacity-business-fixture"), arguments.indices.contains(index + 1),
              ["pending", "refund", "unavailable", "zero", "success"].contains(arguments[index + 1]) else { return nil }
        return arguments[index + 1]
    }
    static func suppressesSystemReview(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        mode(arguments: arguments) != nil && arguments.contains("--stub-system-review")
    }
    @MainActor static func workspace(root: URL, mode: String) throws -> AppWorkspace {
        let storefront = try CapacityFixtureStorefront(root: root, mode: mode)
        let workspace = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), storefront: storefront)
        if mode == "refund", workspace.store.houses.isEmpty {
            try workspace.recordPurchases([storefront.transaction], identity: identity)
            for i in 1...3 { _ = try workspace.store.add("退款保留\(i)") }
            _ = try workspace.store.call("reviewRequest")
        }
        if mode == "zero" {
            if workspace.store.houses.isEmpty {
                try workspace.acceptPolicy(CapacityPolicy(version: 2, freeLimit: 2))
                _ = try workspace.store.add("超额保留")
                let archived = try workspace.store.add("零额度待恢复")
                try workspace.store.archive(archived, archived: true)
            }
            try workspace.acceptPolicy(CapacityPolicy(version: 2, freeLimit: 0))
        }
        return workspace
    }
}
@MainActor private final class CapacityFixtureStorefront: CapacityStorefront {
    func identity(refresh: Bool) -> PurchaseIdentity { CapacityBusinessFixture.identity }
    func stopObserving() {}
    let file: URL; let mode: String
    init(root: URL, mode: String) throws {
        file = root.appending(path: "fixture-apple-history.json"); self.mode = mode
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if mode == "refund", !FileManager.default.fileExists(atPath: file.path) { try save([transaction]) }
    }
    var transaction: CapacityTransaction {
        CapacityTransaction(id: "10001", productID: PurchaseLedger.productID, accountToken: nil,
            environment: "Sandbox", appTransactionID: CapacityBusinessFixture.identity.appTransactionID, purchaseDate: Date())
    }
    func product(_ id: String) throws -> CapacityProduct {
        if mode == "unavailable" { throw CoreFailure(message: "房源包暂未开放购买，请稍后再试") }
        return CapacityProduct(id: id, displayPrice: "¥9.90")
    }
    func purchase(_ product: CapacityProduct, accountToken: UUID) throws -> CapacityPurchaseResult {
        if mode == "refund" { return .cancelled }
        try save([transaction])
        return mode == "pending" ? .pending : .verified(transaction)
    }
    func transactions(synchronize: Bool) throws -> [CapacityTransaction] {
        var result = try history()
        if mode == "refund", synchronize {
            result = result.map { value in var changed = value; changed.revocationDate = Date(); changed.signedDate = Date(); return changed }
            try save(result)
        }
        return result
    }
    private func history() throws -> [CapacityTransaction] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        return try JSONDecoder().decode([CapacityTransaction].self, from: Data(contentsOf: file))
    }
    private func save(_ value: [CapacityTransaction]) throws { try JSONEncoder().encode(value).write(to: file, options: .atomic) }
    func finish(_ transaction: CapacityTransaction) {}
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void) {}
}
#endif
