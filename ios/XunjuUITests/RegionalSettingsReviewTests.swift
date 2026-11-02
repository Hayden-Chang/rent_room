import XCTest

@MainActor final class RegionalSettingsReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func application(id: String = UUID().uuidString, language: String = "zh-Hans", denied: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "regional-settings", "--regional-review-id", id,
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"]
        if denied { app.launchArguments.append("--regional-review-denied") }
        return app
    }

    private func launch(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.buttons["settings.language"].waitForExistence(timeout: 8))
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLanguageSwitchIsImmediateKeepsScreenAndPersistsAfterRelaunch() {
        let app = application()
        launch(app)
        capture("01-regional-settings-zh", app)
        app.buttons["settings.language"].tap()
        XCTAssertTrue(app.buttons["language.system"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["language.system"].isSelected)
        capture("02-language-follow-system-zh", app)
        app.buttons["language.english"].tap()
        XCTAssertTrue(app.buttons["language.english"].isSelected)
        XCTAssertEqual(app.buttons["language.system"].label, "System Default") // Exact agy output.
        capture("03-language-english-selected", app)
        app.buttons["regional.back"].tap()
        XCTAssertTrue(app.buttons["settings.language"].waitForExistence(timeout: 3))
        capture("04-regional-settings-en", app)
        app.terminate()
        launch(app)
        app.buttons["settings.language"].tap()
        XCTAssertTrue(app.buttons["language.english"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["language.english"].isSelected)
        XCTAssertEqual(app.buttons["language.system"].label, "System Default")
        app.buttons["language.system"].tap()
        XCTAssertTrue(app.buttons["language.system"].isSelected)
        XCTAssertEqual(app.buttons["language.system"].label, "跟随系统")
        capture("05-language-return-to-system-zh", app)
    }

    func testCurrencySearchManualSelectionAndAutomaticCountryChange() {
        let app = application(language: "en")
        launch(app)
        XCTAssertTrue(app.buttons["settings.currency"].label.hasPrefix("Currency")) // Exact agy output.
        app.buttons["settings.currency"].tap()
        XCTAssertTrue(app.buttons["currency.automatic"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["currency.automatic"].isSelected)
        capture("06-currency-list-en", app)
        let search = app.textFields["currency.search"]
        search.tap(); search.typeText("JPY")
        let yen = app.buttons["currency.JPY"]
        XCTAssertTrue(yen.waitForExistence(timeout: 3))
        yen.tap()
        XCTAssertTrue(yen.isSelected)
        capture("07-currency-search-selection-en", app)
        app.buttons["regional.back"].tap()
        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("JPY"))
        app.terminate(); launch(app)
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("JPY"))
        app.buttons["settings.currency"].tap()
        XCTAssertTrue(app.buttons["currency.automatic"].waitForExistence(timeout: 3))
        app.buttons["currency.automatic"].tap()
        XCTAssertTrue(app.buttons["currency.automatic"].isSelected)
        app.buttons["regional.back"].tap()
        app.buttons["regional.review.prompt"].tap()
        XCTAssertTrue(app.buttons["currency.prompt.allow"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons["currency.prompt.decline"].label, "Use USD")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Set your default currency for rent")).firstMatch.exists)
        capture("08-currency-location-prompt-en", app)
        app.buttons["currency.prompt.allow"].tap()
        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("GBP"))
        capture("09-country-result-gbp-en", app)
    }

    func testLocationDeclineAndDeniedCallbackUseCNYAndManualChoiceRemainsAvailable() {
        let app = application(denied: true)
        launch(app)
        app.buttons["regional.review.prompt"].tap()
        XCTAssertTrue(app.buttons["currency.prompt.decline"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["currency.prompt.title"].label, "获取当前位置自动识别货币类型")
        XCTAssertEqual(app.buttons["currency.prompt.decline"].label, "使用人民币")
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "根据你所在的国家或地区")).firstMatch.exists)
        capture("10-currency-location-prompt-zh", app)
        app.buttons["currency.prompt.decline"].tap()
        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("CNY"))
        capture("11-currency-declined-cny-zh", app)
        app.terminate(); launch(app)
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("CNY"))
        app.buttons["regional.review.prompt"].tap()
        XCTAssertTrue(app.buttons["currency.prompt.allow"].waitForExistence(timeout: 3))
        app.buttons["currency.prompt.allow"].tap()
        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("CNY"))
        app.buttons["regional.review.prompt"].tap()
        XCTAssertTrue(app.buttons["currency.prompt.manual"].waitForExistence(timeout: 3))
        app.buttons["currency.prompt.manual"].tap()
        XCTAssertTrue(app.buttons["currency.JPY"].waitForExistence(timeout: 3))
        app.buttons["currency.JPY"].tap()
        XCTAssertTrue(app.buttons["currency.JPY"].isSelected)
        XCTAssertTrue(app.buttons["currency.automatic"].label.contains("CNY"),
                      "Manual selection must not relabel the detected currency.")
        capture("12-currency-manual-jpy-zh", app)
        app.buttons["regional.back"].tap()
        XCTAssertTrue(app.buttons["settings.currency"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("JPY"))
    }
}
