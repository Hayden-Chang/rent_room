#if DEBUG
import Foundation

/// An explicit UUID sandbox replaces only external services, retaining the real
/// CapacityAPI decoder, controller, identity store, persistence and pages.
enum CapacityBusinessFixture {
    static let identity = PurchaseIdentity(appTransactionID: "9001", bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "fixture-app-proof")
    static func mode(arguments: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let test = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(test + 1), UUID(uuidString: arguments[test + 1]) != nil,
              let index = arguments.firstIndex(of: "--capacity-business-fixture"), arguments.indices.contains(index + 1),
              ["pending", "refund", "unavailable", "zero"].contains(arguments[index + 1]) else { return nil }
        return arguments[index + 1]
    }
    @MainActor static func workspace(root: URL, mode: String) throws -> AppWorkspace {
        let transport = try CapacityFixtureHTTP(root: root, mode: mode)
        let storefront = CapacityFixtureStorefront(root: root, mode: mode)
        let workspace = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), capacityAPI: CapacityAPI(transport: transport), storefront: storefront)
        let packs = mode == "refund" ? 1 : 0
        if workspace.purchaseBalance == nil {
            try workspace.applyPurchaseCapacity(CapacityBalance(account: identity.account, environment: "Sandbox", packs: packs, limit: 2 + 10 * packs, revision: 0), identity: identity)
        }
        if mode == "refund", workspace.store.houses.isEmpty {
            for i in 1...3 { _ = try workspace.store.add("退款保留\(i)") }
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
private actor CapacityFixtureHTTP: AuthTransport {
    struct State: Codable { var packs: Int; var revision = 0; var failed = false; var ids: Set<String> = [] }
    let file: URL; let mode: String
    var state: State
    init(root: URL, mode: String) throws {
        self.mode = mode; file = root.appending(path: "fixture-capacity-server.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        state = (try? JSONDecoder().decode(State.self, from: Data(contentsOf: file))) ?? State(packs: mode == "refund" ? 1 : 0)
    }
    func send(_ request: URLRequest) throws -> HTTPPayload {
        var status = 200
        var value: [String: Any] = [:]
        switch request.url?.lastPathComponent {
        case "context":
            value = ["available": mode != "unavailable", "productId": "fixture.capacity.10", "packSize": 10, "appAccountToken": "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"]
        case "verify":
            if !state.failed { state.failed = true; status = 503; value = ["detail": ["message": "购买记录暂时无法确认，请稍后重试"]] }
            else {
                let payload = try JSONDecoder().decode([String: String].self, from: request.httpBody!)
                let id = payload["transactionId"]!
                if state.ids.insert(id).inserted { state.packs += 1; state.revision += 1 }
                value = ["transactionId": id, "status": "verified"]
            }
        case "restore":
            if mode == "refund", state.packs > 0 { state.packs = 0; state.revision += 1 }
        default: throw CoreFailure(message: "Unexpected fixture request")
        }
        try JSONEncoder().encode(state).write(to: file, options: .atomic)
        if status == 200 {
            let free = mode == "zero" ? 0 : 1
            value.merge(["account": CapacityBusinessFixture.identity.account, "environment": "Sandbox", "packs": state.packs, "limit": free + 10 * state.packs, "revision": state.revision,
                         "capacity": ["version": 2, "freeLimit": free]]) { _, new in new }
        }
        return HTTPPayload(data: try JSONSerialization.data(withJSONObject: value), status: status)
    }
}
@MainActor private final class CapacityFixtureStorefront: CapacityStorefront {
    func identity(refresh: Bool) -> PurchaseIdentity { CapacityBusinessFixture.identity }
    func stopObserving() {}
    let file: URL; let mode: String
    init(root: URL, mode: String) { file = root.appending(path: "fixture-storekit-unfinished"); self.mode = mode }
    var transaction: CapacityTransaction { CapacityTransaction(id: "10001", productID: "fixture.capacity.10", accountToken: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"), environment: "Sandbox", appTransactionID: CapacityBusinessFixture.identity.appTransactionID) }
    func product(_ id: String) -> CapacityProduct { CapacityProduct(id: id, displayPrice: "¥1.99") }
    func purchase(_ product: CapacityProduct, accountToken: UUID) throws -> CapacityPurchaseResult {
        if mode == "refund" { return .cancelled }
        try Data().write(to: file, options: .atomic)
        return .verified(transaction)
    }
    func transactions(synchronize: Bool) -> [CapacityTransaction] { FileManager.default.fileExists(atPath: file.path) ? [transaction] : [] }
    func finish(_ transaction: CapacityTransaction) { try? FileManager.default.removeItem(at: file) }
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void) { }
}
#endif
