import XCTest
@testable import Xunju

@MainActor final class CapacityTestStorefront: CapacityStorefront {
    nonisolated static let testIdentity = PurchaseIdentity(appTransactionID: "9001", bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "signed-app-proof")
    var purchaseIdentity = testIdentity
    var identityFails = false, historyFails = false, purchaseFails = false, productFails = false
    var historyGate: CheckedContinuation<Void, Never>?
    var historyStarted: (() -> Void)?
    var result: CapacityPurchaseResult?
    var outstanding: [CapacityTransaction] = [] // Full Apple history, including finished entries.
    var finished: [String] = []
    var syncs = 0, purchases = 0
    var receive: (@MainActor (CapacityTransaction) async -> Void)?
    let accountToken = UUID()
    var transaction: CapacityTransaction { CapacityTransaction(id: "10001", productID: PurchaseLedger.productID, accountToken: nil, environment: "Sandbox", appTransactionID: purchaseIdentity.appTransactionID, purchaseDate: Date()) }
    func identity(refresh: Bool) throws -> PurchaseIdentity {
        if identityFails { throw CoreFailure(message: "offline") }; return purchaseIdentity
    }
    func stopObserving() { receive = nil }
    func product(_ id: String) throws -> CapacityProduct {
        if productFails { throw CoreFailure(message: "商品暂不可用") }; return CapacityProduct(id: id, displayPrice: "$1.99")
    }
    func purchase(_ product: CapacityProduct, accountToken: UUID) throws -> CapacityPurchaseResult {
        purchases += 1
        if purchaseFails { throw CoreFailure(message: "购买凭证未通过校验") }
        let value = result ?? .verified(transaction)
        if case .verified(let transaction) = value { outstanding.append(transaction) }
        return value
    }
    func transactions(synchronize: Bool) async throws -> [CapacityTransaction] {
        if synchronize { syncs += 1 }
        if historyFails { throw CoreFailure(message: "购买历史未通过校验") }
        let snapshot = outstanding
        if historyStarted != nil { await withCheckedContinuation { historyGate = $0; historyStarted?() } }
        return snapshot
    }
    func finish(_ transaction: CapacityTransaction) { finished.append(transaction.id) }
    func observe(_ receive: @escaping @MainActor (CapacityTransaction) async -> Void) { self.receive = receive }
}

@MainActor final class CapacityBusinessTests: XCTestCase {
    private func fixture() throws -> (AppWorkspace, CapacityTestStorefront, VolatileSessionStorage) {
        let root = FileManager.default.temporaryDirectory.appending(path: "CapacityTests/\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let keychain = VolatileSessionStorage(), storefront = CapacityTestStorefront()
        return (try AppWorkspace(root: root, keychain: keychain, storefront: storefront), storefront, keychain)
    }
    func testRepeatPurchasesHistoryAndReinstallRestoreExactlyOnce() async throws {
        let (workspace, storefront, keychain) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase()
        var second = storefront.transaction; second = CapacityTransaction(id: "10002", productID: second.productID, accountToken: nil, environment: second.environment, appTransactionID: second.appTransactionID)
        storefront.result = .verified(second); await workspace.billing.purchase()
        await workspace.billing.restore(); await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.limit, 21); XCTAssertEqual(storefront.finished, ["10001", "10002"])
        let root = FileManager.default.temporaryDirectory.appending(path: "ReinstallTests/\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try AppWorkspace(root: root, keychain: keychain, storefront: storefront)
        await installed.billing.restore()
        XCTAssertEqual(installed.store.capacity.limit, 21); XCTAssertNil(installed.session)
    }
    func testCacheFailureDoesNotFinishAndRecoversAfterProcessRelaunch() async throws {
        let (workspace, storefront, keychain) = try fixture()
        let id = try workspace.store.add("保留房源")
        try workspace.store.answer(id, field: "f1_6", value: .string("1800"))
        await workspace.billing.load()
        let cache = workspace.scopes.root.appending(path: "purchase-capacity.json")
        // Block only the purchase's second durable write, after preflight completes.
        storefront.result = .pending; await workspace.billing.purchase(); workspace.billing.start()
        try FileManager.default.removeItem(at: cache)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: false)
        storefront.outstanding = [storefront.transaction]
        await storefront.receive?(storefront.transaction)
        XCTAssertEqual(storefront.finished, []); XCTAssertEqual(workspace.store.capacity.limit, 1)
        XCTAssertEqual(workspace.billing.activity, .pending)
        try FileManager.default.removeItem(at: cache)
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: keychain, storefront: storefront)
        await reopened.billing.restore()
        XCTAssertEqual(reopened.store.capacity.limit, 11); XCTAssertEqual(storefront.finished, ["10001"])
        XCTAssertEqual(reopened.store.house(id)["answers"]["f1_6"]["value"].string, "1800")
    }
    func testCancelledPendingAndUnavailableProductNeverGrantButRestoreWorks() async throws {
        let (workspace, storefront, _) = try fixture()
        await workspace.billing.load(); storefront.result = .cancelled; await workspace.billing.purchase()
        XCTAssertEqual(workspace.store.capacity.limit, 1)
        storefront.result = .pending; await workspace.billing.purchase()
        XCTAssertEqual(workspace.billing.activity, .pending); XCTAssertEqual(storefront.finished, [])
        storefront.productFails = true; storefront.outstanding = [storefront.transaction]
        await workspace.billing.restore(); XCTAssertTrue(workspace.billing.error.isEmpty)
        XCTAssertEqual(workspace.store.capacity.limit, 11)
        await workspace.billing.load(); XCTAssertNil(workspace.billing.product)
    }
    func testRefundRejectsStaleUpdatesAndKeepsAllHousesOffline() async throws {
        let (workspace, storefront, keychain) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase(); workspace.billing.start()
        for i in 1...3 { _ = try workspace.store.add("房源\(i)") }
        var refunded = storefront.transaction; refunded.revocationDate = Date(); refunded.signedDate = Date()
        storefront.outstanding = [refunded]; await workspace.billing.restore()
        await storefront.receive?(storefront.transaction)
        XCTAssertEqual(workspace.store.capacity.limit, 1); XCTAssertEqual(workspace.store.houses.count, 3)
        XCTAssertThrowsError(try workspace.store.add("超额"))
        storefront.identityFails = true
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: keychain, storefront: storefront)
        await reopened.billing.load()
        XCTAssertEqual(reopened.store.capacity.limit, 1); XCTAssertEqual(reopened.store.houses.count, 3)
    }
    func testDuplicateUpdateDuringHistoryCannotBeLostOrCountedTwice() async throws {
        let (workspace, storefront, _) = try fixture()
        await workspace.billing.load(); workspace.billing.start()
        let started = expectation(description: "history snapshot captured")
        storefront.historyStarted = { started.fulfill() }
        let restoring = Task { await workspace.billing.restore() }
        await fulfillment(of: [started], timeout: 3)
        await storefront.receive?(storefront.transaction); await storefront.receive?(storefront.transaction)
        storefront.historyStarted = nil; storefront.historyGate?.resume(); storefront.historyGate = nil
        await restoring.value
        XCTAssertEqual(workspace.store.capacity.limit, 11); XCTAssertEqual(storefront.finished, ["10001"])
    }
    func testInvalidHistoryPreservesCacheAndAccountChangeNeverMovesHouses() async throws {
        let (workspace, storefront, _) = try fixture()
        let id = try workspace.store.add("本机记录"), directory = workspace.store.records.directory
        await workspace.billing.load(); await workspace.billing.purchase()
        storefront.historyFails = true; await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.limit, 11); XCTAssertFalse(workspace.billing.error.isEmpty)
        storefront.historyFails = false
        storefront.purchaseIdentity = PurchaseIdentity(appTransactionID: "9002", bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "new-proof")
        // A mismatching history is not accepted for the new verified account.
        await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.limit, 1); XCTAssertFalse(workspace.billing.error.isEmpty)
        storefront.outstanding = []; await workspace.billing.restore()
        XCTAssertTrue(workspace.billing.error.isEmpty)
        XCTAssertEqual(workspace.store.records.directory, directory); XCTAssertEqual(workspace.store.house(id)["name"].string, "本机记录")
    }
    func testInvalidatedIdentityDuringHistoryCannotGrantOrFinish() async throws {
        let (workspace, storefront, _) = try fixture()
        await workspace.billing.load()
        storefront.outstanding = [storefront.transaction]
        let started = expectation(description: "history in flight")
        storefront.historyStarted = { started.fulfill() }
        let restore = Task { await workspace.billing.restore() }
        await fulfillment(of: [started], timeout: 3)
        workspace.billing.identityChanged()
        storefront.historyStarted = nil; storefront.historyGate?.resume(); storefront.historyGate = nil
        await restore.value
        XCTAssertEqual(workspace.store.capacity.limit, 1); XCTAssertEqual(storefront.finished, [])
    }
    func testFixtureRequiresExplicitUUIDAndKnownMode() {
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: []))
        XCTAssertNil(CapacityBusinessFixture.mode(arguments: ["--business-test", "invalid", "--capacity-business-fixture", "pending"]))
        let args = ["--business-test", UUID().uuidString, "--capacity-business-fixture", "pending"]
        XCTAssertEqual(CapacityBusinessFixture.mode(arguments: args), "pending")
        XCTAssertFalse(CapacityBusinessFixture.suppressesSystemReview(arguments: args))
        XCTAssertTrue(CapacityBusinessFixture.suppressesSystemReview(arguments: args + ["--stub-system-review"]))
    }
}
