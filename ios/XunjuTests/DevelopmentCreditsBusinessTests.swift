import XCTest
@testable import Xunju

@MainActor final class DevelopmentCreditsBusinessTests: XCTestCase {
    private func root() -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "DevelopmentCreditTests/\(UUID())")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }

    func testProductionModeRejectsGrantEvenWhenCallerRequestsIt() throws {
        let store = try NativeStore(directory: root(), developmentCreditsEnabled: false)
        let before = store.capacity
        XCTAssertThrowsError(try store.call("grantDevelopmentCredits"))
        XCTAssertEqual(store.capacity, before)
        #if !DEBUG
        let release = try NativeStore(directory: root(), developmentCreditsEnabled: true)
        XCTAssertThrowsError(try release.call("grantDevelopmentCredits"))
        #endif
    }

    #if DEBUG
    func testRepeatGrantsCreateDebitAndRestartPersistWithoutPurchases() throws {
        let directory = root(), store = try NativeStore(directory: directory, freeLimit: 2)
        try store.grantDevelopmentCredits(); try store.grantDevelopmentCredits()
        XCTAssertEqual(store.capacity.remaining, 22); XCTAssertEqual(store.capacity.packs, 0)
        let id = try store.add("开发测试房源")
        try store.answer(id, field: "f1_6", value: .string("1800"))
        XCTAssertEqual(store.capacity.remaining, 21)
        let reopened = try NativeStore(directory: directory, freeLimit: 2)
        XCTAssertEqual(reopened.capacity.remaining, 21)
        XCTAssertEqual(reopened.house(id)["answers"]["f1_6"]["value"].string, "1800")
        XCTAssertEqual(reopened.state["propertyCredits"]["freeSpent"].number, 0)
        let normal = try NativeStore(directory: directory, freeLimit: 2, developmentCreditsEnabled: false)
        XCTAssertEqual(normal.capacity.remaining, 2)
        XCTAssertThrowsError(try normal.call("grantDevelopmentCredits"))
    }

    func testGrantAndCreationWriteFailuresDoNotChangeDurableBalance() throws {
        let directory = root(), store = try NativeStore(directory: directory, freeLimit: 2)
        try store.call("save")
        let stateFile = directory.appending(path: "state.json"), saved = try Data(contentsOf: stateFile)
        try FileManager.default.removeItem(at: stateFile)
        try FileManager.default.createDirectory(at: stateFile, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.grantDevelopmentCredits())
        XCTAssertEqual(store.capacity.remaining, 2)
        try FileManager.default.removeItem(at: stateFile); try saved.write(to: stateFile)
        let reopened = try NativeStore(directory: directory, freeLimit: 2)
        XCTAssertEqual(reopened.capacity.remaining, 2)
        try reopened.grantDevelopmentCredits()
        XCTAssertEqual(reopened.capacity.remaining, 12)
    }

    func testStoreKitRestoreAndAccountChangePreserveLocalGrantWithoutPurchaseEntries() async throws {
        let directory = root(), storefront = CapacityTestStorefront(), sessions = VolatileSessionStorage()
        let workspace = try AppWorkspace(root: directory, keychain: sessions, storefront: storefront)
        try workspace.store.grantDevelopmentCredits()
        _ = try workspace.store.add("赠送点数创建")
        await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.remaining, 11)
        XCTAssertEqual(try PurchaseLedgerStorage(root: directory).read()?.entries.count, 0)
        await workspace.billing.load(); await workspace.billing.purchase()
        XCTAssertEqual(workspace.store.capacity.remaining, 21)
        await workspace.billing.restore(); XCTAssertEqual(workspace.store.capacity.remaining, 21)
        storefront.purchaseIdentity = PurchaseIdentity(appTransactionID: "9002", bundleID: "test.xunju", environment: "Sandbox", signedAppTransaction: "changed")
        storefront.outstanding = []; await workspace.billing.restore()
        XCTAssertEqual(workspace.store.capacity.remaining, 11)
        let reopened = try AppWorkspace(root: directory, keychain: sessions, storefront: storefront)
        XCTAssertEqual(reopened.store.capacity.remaining, 11)
        XCTAssertEqual(reopened.store.houses.count, 1)
    }
    #endif
}
