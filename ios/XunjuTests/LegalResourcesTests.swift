import XCTest
@testable import Xunju

final class LegalResourcesTests: XCTestCase {
    func testPublicLinksUseAppSpecificHTTPSPages() {
        XCTAssertEqual(LegalPage.privacy.url.absoluteString, "https://hayden-chang.github.io/support/privacy-policies/kanfangdazi/privacy-policy.html")
        XCTAssertEqual(LegalPage.terms.url.absoluteString, "https://hayden-chang.github.io/support/terms-of-service/kanfangdazi/terms-of-service.html")
        XCTAssertEqual(LegalPage.support.url.absoluteString, "https://hayden-chang.github.io/support/kanfangdazi/")
    }

    func testPrivacyManifestReachesBuiltAppAndDeclaresTimingWithoutTracking() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual(plist["NSPrivacyTrackingDomains"] as? [String], [])
        let accessed = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessed.count, 2)
        let timing = accessed.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategorySystemBootTime" }
        XCTAssertEqual(timing?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["35F9.1"])
        let defaults = accessed.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" }
        XCTAssertEqual(defaults?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        let collected = try XCTUnwrap(plist["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
        XCTAssertTrue(collected.allSatisfy { $0["NSPrivacyCollectedDataTypeTracking"] as? Bool == false })
        XCTAssertFalse(collected.contains { ["NSPrivacyCollectedDataTypePurchaseHistory", "NSPrivacyCollectedDataTypeUserID"].contains($0["NSPrivacyCollectedDataType"] as? String ?? "") })
        XCTAssertTrue(collected.contains { $0["NSPrivacyCollectedDataType"] as? String == "NSPrivacyCollectedDataTypeCustomerSupport" })
    }

    #if DEBUG
    func testLocalReviewRequiresExplicitKnownRoute() {
        XCTAssertNil(LocalSettingsReviewRoute.parse([]))
        XCTAssertNil(LocalSettingsReviewRoute.parse(["--local-settings-review"]))
        XCTAssertNil(LocalSettingsReviewRoute.parse(["--local-settings-review", "unknown"]))
        XCTAssertEqual(LocalSettingsReviewRoute.parse(["--local-settings-review", "settings"]), .settings)
        XCTAssertEqual(LocalSettingsReviewRoute.parse(["--local-settings-review", "capacity"]), .capacity)
    }
    #endif
}
