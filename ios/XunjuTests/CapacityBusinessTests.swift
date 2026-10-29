import XCTest
@testable import Xunju

actor CapacityTestAPI: CapacityServicing {
    let account = String(repeating: "a", count: 64)
    let accountToken = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    var packs = 0, revision = 0, calls = 0
    var unavailable = false, failVerification = false, failRestore = false
    var verificationStatus = "verified"
    var granted: Set<String> = []
    var verificationGate: CheckedContinuation<Void, Never>?
    var blockVerification = false
    var started: (() -> Void)?
    func balance() -> CapacityBalance { CapacityBalance(account: account, environment: "Sandbox", packs: packs, limit: 2 + 10 * packs, revision: revision) }
    func context(token: String) -> CapacityContext { CapacityContext(available: !unavailable, productID: "test.capacity.10", appAccountToken: accountToken, balance: balance()) }
    func verify(_ transactionID: String, token: String) async throws -> CapacityConfirmation {
        calls += 1
        if blockVerification { await withCheckedContinuation { verificationGate = $0; started?() } }
        if failVerification { throw CoreFailure(message: "购买记录暂时无法确认，请稍后重试") }
        if verificationStatus == "verified", granted.insert(transactionID).inserted { packs += 1; revision += 1 }
        return CapacityConfirmation(transactionID: transactionID, status: verificationStatus, balance: balance())
    }
    func restore(token: String) throws -> CapacityBalance {
        if failRestore { throw CoreFailure(message: "恢复失败，请重试") }
        return balance()
    }
    func configure(failVerification: Bool = false, failRestore: Bool = false, unavailable: Bool = false, verificationStatus: String = "verified") {
        self.failVerification = failVerification; self.failRestore = failRestore; self.unavailable = unavailable
        self.verificationStatus = verificationStatus
    }
    func gate(_ started: @escaping @Sendable () -> Void) { blockVerification = true; self.started = started }
    func resume() { blockVerification = false; verificationGate?.resume(); verificationGate = nil }
    func refund() { packs = 0; revision += 1 }
}

@MainActor final class CapacityTestStorefront: CapacityStorefront {
    let accountToken = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
    var result: CapacityPurchaseResult?
    var outstanding: [CapacityTransaction] = []
    var finished: [String] = []
    var syncs = 0, purchases = 0
    var productFails = false
    var receive: (@MainActor (CapacityTransaction) async -> Void)?
    var transaction: CapacityTransaction { CapacityTransaction(id: "10001", productID: "test.capacity.10", accountToken: accountToken, environment: "Sandbox") }
    func product(_ id: String) throws -> CapacityProduct {
        if productFails { throw CoreFailure(message: "商品暂不可用") }
        return CapacityProduct(id: id, displayPrice: "$0.99")
    }
    func purchase(_ product: CapacityProduct, accountToken: UUID) -> CapacityPurchaseResult {
        purchases += 1
        let value = result ?? .verified(transaction)
        if case .verified(let transaction) = value { outstanding = [transaction] }
        return value
    }
    func transactions(synchronize: Bool) -> [CapacityTransaction] { if synchronize { syncs += 1 }; return outstanding }
    func finish(_ transaction: CapacityTransaction) { finished.append(transaction.id); outstanding.removeAll { $0.id == transaction.id } }
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void) { self.receive = receive }
}

@MainActor final class CapacityBusinessTests: XCTestCase {
    private func fixture() throws -> (AppWorkspace, CapacityTestAPI, CapacityTestStorefront, VolatileSessionStorage) {
        let root = FileManager.default.temporaryDirectory.appending(path: "CapacityTests/\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let keychain = VolatileSessionStorage(), api = CapacityTestAPI(), storefront = CapacityTestStorefront()
        let workspace = try AppWorkspace(root: root, keychain: keychain, capacityAPI: api, storefront: storefront)
        try workspace.accept(LoginReceipt(account: String(repeating: "a", count: 64), token: String(repeating: "t", count: 40), provider: "phone", expiresIn: 7200, packs: 0, limit: 2))
        return (workspace, api, storefront, keychain)
    }
    func testUnconfirmedPurchaseRetainsRecordsAndRestoresExactlyOnceAfterRelaunch() async throws {
        let (workspace, api, storefront, keychain) = try fixture()
        let store = workspace.store, id = try store.add("保留房源")
        try store.answer(id, field: "f1_6", value: .string("0"))
        await api.configure(failVerification: true)
        await workspace.billing.load(); await workspace.billing.purchase()
        XCTAssertEqual(workspace.billing.activity, .pending); XCTAssertFalse(workspace.billing.error.isEmpty)
        XCTAssertEqual(store.capacity.limit, 1); XCTAssertEqual(storefront.finished, [])
        let expiry = try XCTUnwrap(workspace.session?.expiresAt)
        // Process death leaves the StoreKit transaction unfinished, ready to retry.
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: keychain, capacityAPI: api, storefront: storefront)
        await api.configure()
        await reopened.billing.load(); await reopened.billing.restore(); await reopened.billing.restore()
        XCTAssertEqual(reopened.store.capacity.limit, 11); XCTAssertEqual(storefront.finished, ["10001"])
        XCTAssertEqual(reopened.store.house(id)["answers"]["f1_6"]["value"].string, "0")
        XCTAssertEqual(reopened.session?.expiresAt, expiry)
        XCTAssertEqual(keychain.read()?.packs, 1)
        XCTAssertFalse(try reopened.store.call("reviewRequest").bool)
    }
    func testCancellationApprovalAndDisabledProductNeverGrantAndRestoreDoesNotNeedProduct() async throws {
        let (workspace, api, storefront, _) = try fixture()
        await workspace.billing.load(); storefront.result = .cancelled
        await workspace.billing.purchase()
        XCTAssertEqual(workspace.billing.activity, .idle); XCTAssertEqual(workspace.store.capacity.limit, 1)
        storefront.result = .pending; await workspace.billing.purchase(); await workspace.billing.restore()
        XCTAssertEqual(workspace.billing.activity, .pending); XCTAssertEqual(storefront.finished, [])
        let purchases = storefront.purchases; await workspace.billing.purchase(); XCTAssertEqual(storefront.purchases, purchases)
        workspace.billing.start(); await storefront.receive?(storefront.transaction)
        XCTAssertEqual(workspace.store.capacity.limit, 11); XCTAssertEqual(workspace.billing.activity, .idle)
        await api.configure(unavailable: true); storefront.productFails = true
        await workspace.billing.restore(); XCTAssertTrue(workspace.billing.error.isEmpty)
        XCTAssertNil(workspace.billing.product)
        await workspace.billing.load(); XCTAssertNil(workspace.billing.product)
        XCTAssertEqual(workspace.store.capacity.limit, 11)
    }
    func testRefundAndOlderSnapshotsKeepAllHousesAndRejectInconsistentOrForeignBalances() async throws {
        let (workspace, api, _, _) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase()
        let store = workspace.store
        for index in 0..<3 { _ = try store.add("房源\(index)") }
        let old = try await api.restore(token: "test")
        await api.refund(); await workspace.billing.restore()
        XCTAssertTrue(workspace.store === store); XCTAssertEqual(store.capacity.used, 3); XCTAssertEqual(store.capacity.limit, 1)
        XCTAssertThrowsError(try store.add("超额")); XCTAssertEqual(store.houses.count, 3)
        try workspace.applyCapacity(old); XCTAssertEqual(store.capacity.limit, 1)
        XCTAssertThrowsError(try workspace.applyCapacity(CapacityBalance(account: old.account, environment: "Sandbox", packs: 1, limit: 12, revision: 2)))
        XCTAssertThrowsError(try workspace.applyCapacity(CapacityBalance(account: String(repeating: "b", count: 64), environment: "Sandbox", packs: 1, limit: 12, revision: 3)))
        XCTAssertThrowsError(try store.call("setPacks", ["value": .number(-1)]))
        let restored = try NativeStore(directory: store.records.directory, packs: 0)
        XCTAssertEqual(restored.houses.count, 3)
    }
    func testDuplicateForegroundAndBackgroundVerificationSharesOneGrantAndFinish() async throws {
        let (workspace, api, storefront, _) = try fixture()
        await workspace.billing.load(); workspace.billing.start()
        let waiting = expectation(description: "verification in flight")
        await api.gate { waiting.fulfill() }
        let purchase = Task { await workspace.billing.purchase() }
        await fulfillment(of: [waiting], timeout: 5)
        let joined = expectation(description: "background update joined verification")
        let update = Task { joined.fulfill(); await storefront.receive?(storefront.transaction) }
        await fulfillment(of: [joined], timeout: 5)
        await api.resume(); await purchase.value; await update.value
        XCTAssertEqual(workspace.store.capacity.limit, 11)
        XCTAssertEqual(storefront.finished, ["10001"])
        let calls = await api.calls; XCTAssertEqual(calls, 1)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
    }
    func testKeychainFailureKeepsPurchaseUnfinishedUntilCapacityCacheCanBeSaved() async throws {
        final class FailingSessions: SessionStorage {
            var value: LocalSession?; var fail = false
            func read() -> LocalSession? { value }
            func write(_ session: LocalSession) throws { if fail { throw CoreFailure(message: "保存失败") }; value = session }
            func remove() { value = nil }
        }
        let root = FileManager.default.temporaryDirectory.appending(path: "CapacityTests/\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let sessions = FailingSessions(), api = CapacityTestAPI(), storefront = CapacityTestStorefront()
        let workspace = try AppWorkspace(root: root, keychain: sessions, capacityAPI: api, storefront: storefront)
        try workspace.accept(LoginReceipt(account: String(repeating: "a", count: 64), token: String(repeating: "t", count: 40), provider: "phone", expiresIn: 7200, packs: 0, limit: 2))
        await workspace.billing.load()
        // Fail only when saving the confirmed increment, after the preflight context.
        let waiting = expectation(description: "server confirming")
        await api.gate { waiting.fulfill() }
        let purchase = Task { await workspace.billing.purchase() }
        await fulfillment(of: [waiting], timeout: 5)
        sessions.fail = true; await api.resume(); await purchase.value
        XCTAssertEqual(workspace.store.capacity.limit, 1); XCTAssertEqual(storefront.finished, [])
        XCTAssertEqual(workspace.billing.activity, .pending)
        sessions.fail = false; await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.limit, 11); XCTAssertEqual(storefront.finished, ["10001"])
    }
    func testFixtureRequiresExplicitUUIDAndKnownMode() {
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: []))
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: ["--capacity-business-fixture", "pending"]))
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: ["--business-test", "invalid", "--capacity-business-fixture", "pending"]))
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: ["--business-test", UUID().uuidString, "--capacity-business-fixture", "other"]))
        XCTAssertEqual(CapacityBusinessFixture.mode(arguments: ["--business-test", UUID().uuidString, "--capacity-business-fixture", "pending"]), "pending")
        XCTAssertEqual(CapacityBusinessFixture.mode(arguments: ["--business-test", UUID().uuidString, "--capacity-business-fixture", "success"]), "success")
    }
    func testIdentityChangeDuringServerConfirmationCannotGrantOrFinish() async throws {
        let (workspace, api, storefront, _) = try fixture()
        await workspace.billing.load(); workspace.billing.start()
        let waiting = expectation(description: "verification reached server")
        await api.gate { waiting.fulfill() }
        let purchase = Task { await workspace.billing.purchase() }
        await fulfillment(of: [waiting], timeout: 5)
        try workspace.logout()
        try workspace.accept(LoginReceipt(account: String(repeating: "b", count: 64), token: String(repeating: "u", count: 40), provider: "apple", expiresIn: 7200, packs: 0, limit: 2))
        await api.resume(); await purchase.value
        XCTAssertEqual(workspace.store.capacity.limit, 1); XCTAssertEqual(storefront.finished, [])
        XCTAssertEqual(workspace.billing.activity, .idle)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
    }
}
