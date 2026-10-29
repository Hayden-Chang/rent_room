import XCTest
@testable import Xunju

@MainActor final class AppReviewTests: XCTestCase {
    private func fixture() throws -> (AppWorkspace, CapacityTestAPI, CapacityTestStorefront, VolatileSessionStorage) {
        let root = FileManager.default.temporaryDirectory.appending(path: "AppReviewTests/\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let api = CapacityTestAPI(), storefront = CapacityTestStorefront(), sessions = VolatileSessionStorage()
        let workspace = try AppWorkspace(root: root, keychain: sessions, capacityAPI: api, storefront: storefront)
        try workspace.accept(LoginReceipt(account: String(repeating: "a", count: 64), token: String(repeating: "t", count: 40), provider: "apple", expiresIn: 7200, packs: 0, limit: 2))
        return (workspace, api, storefront, sessions)
    }
    func testPurchaseAndThirdCreationShareOneDurableRequest() async throws {
        let (workspace, api, storefront, sessions) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase()
        XCTAssertEqual(workspace.store.capacity.packs, 1)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        for index in 1...3 { _ = try workspace.store.add("房源\(index)") }
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: sessions, capacityAPI: api, storefront: storefront)
        XCTAssertFalse(try reopened.store.call("reviewRequest").bool)
    }
    func testCancelledPendingFailedAndRevokedPurchasesDoNotRequest() async throws {
        for outcome in ["cancelled", "pending", "failed", "revoked"] {
            let (workspace, api, storefront, _) = try fixture()
            if outcome == "cancelled" { storefront.result = .cancelled }
            if outcome == "pending" { storefront.result = .pending }
            await api.configure(failVerification: outcome == "failed", verificationStatus: outcome == "revoked" ? "revoked" : "verified")
            await workspace.billing.load(); await workspace.billing.purchase()
            XCTAssertFalse(try workspace.store.call("reviewRequest").bool, outcome)
        }
    }
    func testLoadedAndRestoredTransactionsDoNotRequest() async throws {
        for restore in [false, true] {
            let (workspace, _, storefront, _) = try fixture()
            storefront.outstanding = [storefront.transaction]
            if restore { await workspace.billing.restore() } else { await workspace.billing.load() }
            XCTAssertEqual(workspace.store.capacity.packs, 1)
            XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        }
    }
    func testPendingApprovalRequestsOnlyAfterVerifiedUpdate() async throws {
        let (workspace, _, storefront, _) = try fixture()
        await workspace.billing.load(); workspace.billing.start()
        storefront.result = .pending; await workspace.billing.purchase()
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        await storefront.receive?(storefront.transaction)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        await storefront.receive?(storefront.transaction)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
    }
    func testReviewPersistenceFailureDoesNotFailConfirmedPurchase() async throws {
        let (workspace, api, storefront, _) = try fixture()
        await workspace.billing.load()
        let current = workspace.store.records.directory.appending(path: "state.json")
        try FileManager.default.removeItem(at: current)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        await workspace.billing.purchase()
        XCTAssertEqual(workspace.store.capacity.packs, 1)
        XCTAssertEqual(storefront.finished, ["10001"])
        XCTAssertTrue(workspace.billing.error.isEmpty)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        let calls = await api.calls; XCTAssertEqual(calls, 1)
    }
}
