import XCTest
@testable import Xunju

@MainActor final class AppReviewTests: XCTestCase {
    private func fixture() throws -> (AppWorkspace, CapacityTestStorefront, VolatileSessionStorage) {
        let root = FileManager.default.temporaryDirectory.appending(path: "AppReviewTests/\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let storefront = CapacityTestStorefront(), sessions = VolatileSessionStorage()
        let workspace = try AppWorkspace(root: root, keychain: sessions, storefront: storefront)
        return (workspace, storefront, sessions)
    }
    func testPurchaseAndThirdCreationShareOneDurableRequest() async throws {
        let (workspace, storefront, sessions) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase()
        XCTAssertEqual(workspace.store.capacity.packs, 1)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        for index in 1...3 { _ = try workspace.store.add("房源\(index)") }
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: sessions, storefront: storefront)
        XCTAssertFalse(try reopened.store.call("reviewRequest").bool)
    }
    func testFilledItemsEligibilityIsHomeOnlyAndSharesDurableRequest() throws {
        let (workspace, storefront, sessions) = try fixture()
        try FilledReviewFixture.prepare(workspace.store)
        let store = workspace.store
        let id = try XCTUnwrap(store.houses.first?.id)
        XCTAssertEqual(store.houses.first?.stats.done, 50)
        XCTAssertEqual(store.state["iosReview"]["created"].int, 1)
        XCTAssertFalse(AppReviewPrompt.isEligible(store: store, includeFilledItems: true))
        XCTAssertFalse(try store.call("reviewRequest", ["value": .bool(true)]).bool)
        try store.answer(id, field: "f1_6", value: .string("2800"))
        XCTAssertEqual(store.houses.first?.stats.done, 51)
        XCTAssertTrue(AppReviewPrompt.isEligible(store: store, includeFilledItems: true))
        XCTAssertFalse(AppReviewPrompt.isEligible(store: store, includeFilledItems: false))
        XCTAssertFalse(try store.call("reviewRequest").bool)
        XCTAssertTrue(try store.call("reviewRequest", ["value": .bool(true)]).bool)
        XCTAssertFalse(AppReviewPrompt.isEligible(store: store, includeFilledItems: true))
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: sessions, storefront: storefront)
        XCTAssertEqual(reopened.store.houses.first?.stats.done, 51)
        XCTAssertFalse(try reopened.store.call("reviewRequest", ["value": .bool(true)]).bool)
    }
    func testFilledReviewFixtureRequiresExplicitDisposableScope() {
        XCTAssertFalse(FilledReviewFixture.enabled([]))
        XCTAssertFalse(FilledReviewFixture.enabled(["--filled-review-fixture"]))
        XCTAssertFalse(FilledReviewFixture.enabled(["--filled-review-fixture", "--returning-business-fixture", "--business-test", "invalid"]))
        let scoped = ["--returning-business-fixture", "--business-test", UUID().uuidString]
        XCTAssertFalse(FilledReviewFixture.enabled(scoped))
        XCTAssertTrue(FilledReviewFixture.enabled(scoped + ["--filled-review-fixture"]))
        XCTAssertFalse(FilledReviewFixture.creationEnabled(["--review-creation-fixture"]))
        XCTAssertFalse(FilledReviewFixture.creationEnabled(scoped))
        XCTAssertTrue(FilledReviewFixture.creationEnabled(scoped + ["--review-creation-fixture"]))
    }
    func testCancelledPendingFailedAndRevokedPurchasesDoNotRequest() async throws {
        for outcome in ["cancelled", "pending", "failed", "revoked"] {
            let (workspace, storefront, _) = try fixture()
            if outcome == "cancelled" { storefront.result = .cancelled }
            if outcome == "pending" { storefront.result = .pending }
            storefront.purchaseFails = outcome == "failed"
            if outcome == "revoked" { var value = storefront.transaction; value.revocationDate = Date(); storefront.result = .verified(value) }
            await workspace.billing.load(); await workspace.billing.purchase()
            XCTAssertFalse(try workspace.store.call("reviewRequest").bool, outcome)
        }
    }
    func testLoadedAndRestoredTransactionsDoNotRequest() async throws {
        for restore in [false, true] {
            let (workspace, storefront, _) = try fixture()
            storefront.outstanding = [storefront.transaction]
            if restore { await workspace.billing.restore() } else { await workspace.billing.load() }
            XCTAssertEqual(workspace.store.capacity.packs, 1)
            XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        }
    }
    func testPendingApprovalRequestsOnlyAfterVerifiedUpdate() async throws {
        let (workspace, storefront, _) = try fixture()
        await workspace.billing.load(); workspace.billing.start()
        storefront.result = .pending; await workspace.billing.purchase()
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
        await storefront.receive?(storefront.transaction)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        await storefront.receive?(storefront.transaction)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
    }
    func testPendingApprovalAndFailedLocalSaveSurviveRelaunch() async throws {
        for approval in [false, true] {
            let (workspace, storefront, sessions) = try fixture()
            storefront.result = .pending
            await workspace.billing.load(); await workspace.billing.purchase()
            if !approval {
                workspace.billing.start()
                let cache = workspace.scopes.root.appending(path: "purchase-capacity.json")
                try FileManager.default.removeItem(at: cache)
                try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: false)
                await storefront.receive?(storefront.transaction)
                try FileManager.default.removeItem(at: cache)
            }
            XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
            let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: sessions, storefront: storefront)
            storefront.outstanding = [storefront.transaction]
            await reopened.billing.load()
            XCTAssertEqual(reopened.store.capacity.packs, 1)
            XCTAssertTrue(try reopened.store.call("reviewRequest").bool)
            await reopened.billing.restore()
            XCTAssertFalse(try reopened.store.call("reviewRequest").bool)
        }
    }
    func testPendingApprovalDoesNotTreatRestoredHistoryAsNewPurchase() async throws {
        let (workspace, storefront, sessions) = try fixture()
        await workspace.billing.load()
        storefront.result = .pending; await workspace.billing.purchase()
        let reopened = try AppWorkspace(root: workspace.scopes.root, keychain: sessions, storefront: storefront)
        storefront.outstanding = [CapacityTransaction(id: "old", productID: PurchaseLedger.productID, accountToken: storefront.accountToken, environment: "Sandbox", appTransactionID: storefront.purchaseIdentity.appTransactionID, purchaseDate: .distantPast)]
        await reopened.billing.restore()
        XCTAssertFalse(try reopened.store.call("reviewRequest").bool)
        XCTAssertTrue(reopened.store.state["iosReview"]["pendingPurchase"].string.hasPrefix("approval:"))
        reopened.billing.start()
        await storefront.receive?(storefront.transaction)
        XCTAssertTrue(try reopened.store.call("reviewRequest").bool)
    }
    func testFailedReviewRequestDoesNotUndoConfirmedPurchase() async throws {
        let (workspace, storefront, _) = try fixture()
        await workspace.billing.load(); await workspace.billing.purchase()
        XCTAssertTrue(workspace.store.state["iosReview"]["purchased"].bool)
        let current = workspace.store.records.directory.appending(path: "state.json")
        let saved = try Data(contentsOf: current)
        try FileManager.default.removeItem(at: current)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        XCTAssertThrowsError(try workspace.store.call("reviewRequest"))
        XCTAssertEqual(workspace.store.capacity.packs, 1)
        XCTAssertEqual(storefront.finished, ["10001"])
        XCTAssertTrue(workspace.billing.error.isEmpty)
        XCTAssertFalse(workspace.store.state["iosReview"]["requested"].bool)
        try FileManager.default.removeItem(at: current)
        try saved.write(to: current)
        XCTAssertTrue(try workspace.store.call("reviewRequest").bool)
        XCTAssertFalse(try workspace.store.call("reviewRequest").bool)
    }
}
