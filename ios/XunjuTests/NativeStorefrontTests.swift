import XCTest
import StoreKitTest
@testable import Xunju

@MainActor final class NativeStorefrontTests: XCTestCase {
    func testFinishedConsumableHistoryAndExistingPrivacyKeysReachBuiltApp() throws {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String, "18.0")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool, true)
        let names = ["zh-Hans": "寻居", "en": "Xunju"]
        for (language, name) in names {
            let url = try XCTUnwrap(Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "\(language).lproj"))
            let values = try XCTUnwrap(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
            XCTAssertEqual(values["CFBundleDisplayName"], name)
        }
        XCTAssertTrue(names.values.contains(try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)))
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
        let product = try await storefront.product("com.keeline.xunju.ios.capacity10")
        XCTAssertFalse(product.displayPrice.isEmpty)
        guard case .verified(let first) = try await storefront.purchase(product, accountToken: account) else { return XCTFail("Local purchase did not verify") }
        XCTAssertEqual(first.accountToken, account); XCTAssertEqual(first.environment, "Xcode")
        XCTAssertNotNil(first.purchaseDate); XCTAssertEqual(first.quantity, 1)
        let outstanding = try await storefront.transactions(synchronize: false)
        XCTAssertTrue(outstanding.contains { $0.id == first.id })
        await storefront.finish(first)
        let completed = try await storefront.transactions(synchronize: false)
        XCTAssertTrue(completed.contains { $0.id == first.id }, "Finished consumables must remain restorable on iOS 18")
        guard case .verified(let second) = try await storefront.purchase(product, accountToken: account) else { return XCTFail("Consumable cannot be bought twice") }
        XCTAssertNotEqual(first.id, second.id); XCTAssertEqual(second.accountToken, account)
        await storefront.finish(second)
    }
}
