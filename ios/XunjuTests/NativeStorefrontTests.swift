import XCTest
import StoreKitTest
@testable import Xunju

@MainActor final class NativeStorefrontTests: XCTestCase {
    func testFinishedConsumableHistoryAndExistingPrivacyKeysReachBuiltApp() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool, true)
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, "看房搭子")
        for key in ["NSCameraUsageDescription", "NSMicrophoneUsageDescription", "NSLocationWhenInUseUsageDescription"] {
            XCTAssertFalse((Bundle.main.object(forInfoDictionaryKey: key) as? String ?? "").isEmpty)
        }
    }
    func testRealStoreKitConsumableUsesAccountTokenAndStaysUnfinishedUntilAcknowledged() async throws {
        let file = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Capacity", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: file)
        session.disableDialogs = true; session.clearTransactions()
        defer { session.clearTransactions() }
        let storefront = NativeStorefront(), account = UUID()
        let product = try await storefront.product("test.capacity.10")
        XCTAssertFalse(product.displayPrice.isEmpty)
        guard case .verified(let first) = try await storefront.purchase(product, accountToken: account) else { return XCTFail("Local purchase did not verify") }
        XCTAssertEqual(first.accountToken, account); XCTAssertEqual(first.environment, "Xcode")
        XCTAssertNotNil(first.purchaseDate)
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
