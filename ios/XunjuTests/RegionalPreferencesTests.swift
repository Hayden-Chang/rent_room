import XCTest
@testable import Xunju

final class RegionalPreferencesTests: XCTestCase {
    func testSettingsCurrencyLabelsUseLocalizedYuanAndActualCurrencyCode() {
        XCTAssertEqual(CurrencyCatalog.settingsLabel("CNY", language: .chinese, automatic: true), "自动识别/元")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("CNY", language: .chinese), "人民币/元")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("USD", language: .english, automatic: true), "Auto-Detect/USD")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("USD", language: .english), "US Dollar/USD")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("CNY", language: .english, automatic: true), "Auto-Detect/CNY")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("JPY", language: .english), "Japanese Yen/JPY")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("JPY", language: .chinese), "日元/JPY")
        XCTAssertEqual(CurrencyCatalog.settingsLabel("GBP", language: .english, automatic: true), "Auto-Detect/GBP")
    }

    func testSystemLanguageMatchesPreferenceOrderAndFallsBackToEnglish() {
        XCTAssertEqual(LanguageSelection.system.resolve(["fr-FR", "zh-Hant-TW", "en-US"]), .chinese)
        XCTAssertEqual(LanguageSelection.system.resolve(["en-GB", "zh-Hans"]), .english)
        XCTAssertEqual(LanguageSelection.system.resolve(["zh_CN", "en"]), .chinese)
        XCTAssertEqual(LanguageSelection.system.resolve(["ja-JP"]), .english)
        XCTAssertEqual(LanguageSelection.system.resolve([]), .english)
        XCTAssertEqual(LanguageSelection.chinese.resolve(["en-US"]), .chinese)
        XCTAssertEqual(LanguageSelection.english.resolve(["zh-Hans"]), .english)
    }

    func testCountryDetectionMapsSupportedCountriesAndFallsBackToUSD() {
        for (country, currency) in ["US":"USD", "GB":"GBP", "CN":"CNY", "JP":"JPY", "DE":"EUR", "SG":"SGD", "HK":"HKD", "TW":"TWD", "CA":"CAD", "AU":"AUD", "NZ":"NZD"] {
            XCTAssertEqual(CurrencyCatalog.currency(for: country.lowercased()), currency, country)
        }
        XCTAssertEqual(CurrencyCatalog.currency(for: nil), "USD")
        XCTAssertEqual(CurrencyCatalog.currency(for: "invalid"), "USD")
        XCTAssertEqual(CurrencyCatalog.currency(for: ""), "USD")
    }

    func testDetectionUpdatesOnlyAutomaticSelectionAndDenialUsesUSD() {
        var preferences = RegionalPreferences()
        XCTAssertFalse(preferences.currencyPromptHandled)
        XCTAssertEqual(preferences.currencyCode, "USD")
        preferences.detect(countryCode: "GB")
        XCTAssertEqual(preferences.currencyCode, "GBP")
        XCTAssertTrue(preferences.currencyPromptHandled)
        preferences.detect(countryCode: "JP")
        XCTAssertEqual(preferences.currencyCode, "JPY")
        preferences.declineLocation()
        XCTAssertEqual(preferences.currencyCode, "USD")
        XCTAssertNil(preferences.countryCode)
        XCTAssertTrue(preferences.currencyPromptHandled)
        XCTAssertTrue(preferences.selectCurrency("EUR"))
        preferences.detect(countryCode: "CN")
        preferences.declineLocation()
        XCTAssertEqual(preferences.currencyCode, "EUR")
        XCTAssertEqual(preferences.currencySelection, .manual("EUR"))
        XCTAssertFalse(preferences.selectCurrency("NOT_A_CURRENCY"))
        XCTAssertEqual(preferences.currencyCode, "EUR")
        XCTAssertTrue(preferences.selectCurrency(nil))
        preferences.detect(countryCode: "CN")
        XCTAssertEqual(preferences.currencyCode, "CNY")
    }

    @MainActor func testChoicesPersistIndependentlyOfSystemLanguage() throws {
        let suite = "regional-unit.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = RegionalSettingsModel(defaults: defaults, preferredLanguages: ["zh-Hans"])
        XCTAssertEqual(settings.language, .chinese)
        settings.updateSystemLanguages(["en-GB"])
        XCTAssertEqual(settings.language, .english)
        settings.selectLanguage(.chinese)
        settings.selectCurrency("JPY")
        settings.updateSystemLanguages(["en-US"])
        XCTAssertEqual(settings.language, .chinese)
        let reopened = RegionalSettingsModel(defaults: defaults, preferredLanguages: ["en-US"])
        XCTAssertEqual(reopened.language, .chinese)
        XCTAssertEqual(reopened.preferences.currencyCode, "JPY")
        XCTAssertTrue(reopened.preferences.currencyPromptHandled)
        reopened.selectLanguage(.system)
        XCTAssertEqual(reopened.language, .english)
        reopened.selectCurrency(nil)
        reopened.declineLocation()
        let denied = RegionalSettingsModel(defaults: defaults)
        XCTAssertEqual(denied.preferences.currencyCode, "USD")
        XCTAssertTrue(denied.preferences.currencyPromptHandled)
    }

    func testBilingualCatalogHasMatchingKeysPlaceholdersAndSearchableCurrencies() throws {
        let chinese = try XCTUnwrap(RegionalCopy.entries["zh-Hans"])
        let english = try XCTUnwrap(RegionalCopy.entries["en"])
        XCTAssertEqual(Set(chinese.keys), Set(english.keys))
        XCTAssertGreaterThan(CurrencyCatalog.codes.count, 150)
        let pattern = try NSRegularExpression(pattern: #"\{[a-zA-Z]+\}"#)
        func placeholders(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
                Range($0.range, in: text).map { String(text[$0]) }
            }.sorted()
        }
        for key in chinese.keys {
            let translated = try XCTUnwrap(english[key])
            XCTAssertFalse(translated.isEmpty, key)
            XCTAssertEqual(placeholders(chinese[key]!), placeholders(translated), key)
        }
        XCTAssertEqual(CurrencyCatalog.matching(" usd ", language: .english), ["USD"])
        XCTAssertEqual(CurrencyCatalog.matching("美元", language: .english), ["USD"])
        XCTAssertEqual(CurrencyCatalog.matching("!no-currency!", language: .chinese), [])
        XCTAssertTrue(CurrencyCatalog.matching("pound", language: .chinese).contains("GBP"))
        XCTAssertEqual(RegionalCopy.text("location.title", language: .chinese), "获取当前位置自动识别货币类型")
        let formatted = RegionalCopy.text("location.detected", language: .english, values: ["currency": CurrencyCatalog.name("GBP", language: .english), "code":"GBP"])
        XCTAssertTrue(formatted.contains("GBP")); XCTAssertFalse(formatted.contains("{code}"))
    }

    #if DEBUG
    func testRegionalReviewRequiresExplicitKnownRoute() {
        XCTAssertNil(ReviewSurface.parse(["Xunju"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review", "unknown"]))
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "regional-settings"]), .regionalSettings)
    }
    #endif
}
