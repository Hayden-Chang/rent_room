import XCTest
import StoreKitTest
@testable import Xunju

@MainActor final class NativeStorefrontTests: XCTestCase {
    func testRealStoreKitConsumableUsesAccountTokenAndStaysUnfinishedUntilAcknowledged() async throws {
        let configuration = """
        {"identifier":"XUNJU-LOCAL-TEST","products":[{"displayPrice":"0.99","familyShareable":false,"internalID":"XUNJU10","localizations":[{"description":"Test capacity","displayName":"Test capacity","locale":"en_US"}],"productID":"test.capacity.10","referenceName":"Local capacity test","type":"Consumable"}],"settings":{"_storefront":"USA","_timeRate":0},"subscriptionGroups":[],"nonRenewingSubscriptions":[],"version":{"major":2,"minor":0}}
        """
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).storekit")
        try Data(configuration.utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let session = try SKTestSession(contentsOf: file)
        session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let storefront = NativeStorefront(), account = UUID()
        let product = try await storefront.product("test.capacity.10")
        XCTAssertFalse(product.displayPrice.isEmpty)
        guard case .verified(let first) = try await storefront.purchase(product, accountToken: account) else { return XCTFail("Local purchase did not verify") }
        XCTAssertEqual(first.accountToken, account); XCTAssertEqual(first.environment, "Xcode")
        let outstanding = try await storefront.transactions(synchronize: false)
        XCTAssertTrue(outstanding.contains { $0.id == first.id })
        await storefront.finish(first)
        let completed = try await storefront.transactions(synchronize: false)
        XCTAssertFalse(completed.contains { $0.id == first.id })
        guard case .verified(let second) = try await storefront.purchase(product, accountToken: account) else { return XCTFail("Consumable cannot be bought twice") }
        XCTAssertNotEqual(first.id, second.id); XCTAssertEqual(second.accountToken, account)
        await storefront.finish(second)
    }
}
