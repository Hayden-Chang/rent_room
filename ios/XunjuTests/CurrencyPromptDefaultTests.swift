import XCTest
@testable import Xunju

@MainActor final class CurrencyPromptDefaultTests: XCTestCase {
    private func settings(_ languages: [String]) -> RegionalSettingsModel {
        let suite = "currency-prompt-default.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return RegionalSettingsModel(defaults: defaults, preferredLanguages: languages)
    }

    func testChineseSystemDefaultsToCNYBeforeAndAfterDecliningLocation() {
        for language in ["zh-Hans-CN", "zh-Hant-TW", "zh_HK"] {
            let model = settings([language, "en-US"])
            XCTAssertEqual(model.preferences.currencyCode, "CNY", language)
            model.declineLocation()
            XCTAssertEqual(model.preferences.currencyCode, "CNY", language)
            XCTAssertTrue(model.preferences.currencyPromptHandled)
        }
    }

    func testNonChineseSystemDefaultsToUSDEvenWithChineseAppLanguage() {
        for languages in [["en-US", "zh-Hans"], ["fr-FR", "zh-Hans"], []] {
            let model = settings(languages)
            model.selectLanguage(.chinese)
            model.declineLocation()
            XCTAssertEqual(model.preferences.currencyCode, "USD")
        }
    }

    func testFailedDetectionUsesSystemDefaultAndManualChoiceWins() {
        let model = settings(["zh-Hans"])
        model.selectLanguage(.english)
        model.detect(countryCode: "GB")
        XCTAssertEqual(model.preferences.currencyCode, "GBP")
        model.detect(countryCode: nil)
        XCTAssertEqual(model.preferences.currencyCode, "CNY")
        model.detect(countryCode: "invalid")
        XCTAssertEqual(model.preferences.currencyCode, "CNY")
        model.selectCurrency("EUR")
        model.updateSystemLanguages(["en-US"])
        model.detect(countryCode: nil)
        model.declineLocation()
        XCTAssertEqual(model.preferences.currencyCode, "EUR")
    }

    func testSavedChoiceSurvivesLanguageChangesAndRelaunch() {
        let suite = "currency-prompt-saved.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = RegionalSettingsModel(defaults: defaults, preferredLanguages: ["en-US"])
        model.declineLocation()
        model.updateSystemLanguages(["zh-Hans"])
        XCTAssertEqual(model.preferences.currencyCode, "USD")
        let restored = RegionalSettingsModel(defaults: defaults, preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(restored.preferences.currencyCode, "USD")
        restored.selectCurrency("JPY")
        XCTAssertEqual(RegionalSettingsModel(defaults: defaults, preferredLanguages: ["en-US"]).preferences.currencyCode, "JPY")
    }

    func testSystemLanguageChangeUpdatesOnlyAnUnhandledDefault() {
        let model = settings(["en-US"])
        model.updateSystemLanguages(["zh-Hans"])
        XCTAssertEqual(model.preferences.currencyCode, "CNY")
        model.selectLanguage(.english)
        XCTAssertEqual(model.preferences.currencyCode, "CNY")
        model.detect(countryCode: "GB")
        model.updateSystemLanguages(["en-US"])
        XCTAssertEqual(model.preferences.currencyCode, "GBP")
    }
}
