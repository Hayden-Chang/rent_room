import XCTest
import CoreLocation

@MainActor final class RegionalBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(returning: Bool = false, english: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", english ? "(en)" : "(zh-Hans)", "-AppleLocale", english ? "en_GB" : "zh_CN"]
        if returning { app.launchArguments += ["--returning-business-fixture", "--two-room-policy-fixture"] }
        app.resetAuthorizationStatus(for: .location)
        app.launch(); return app
    }
    private func tap(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons[id]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        if !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        button.tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
    private func openSettings(_ app: XCUIApplication) { tap("tab.我的", app) }
    private func chooseCurrency(_ code: String, _ app: XCUIApplication) {
        tap("settings.currency", app); tap("currency." + code, app); app.navigationBackButton.tap()
    }
    func testFirstChecklistPromptsOnceAndLiveCountryDetectionUsesGBP() {
        let prior = XCUIDevice.shared.location
        addTeardownBlock { @MainActor in XCUIDevice.shared.location = prior }
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 51.5074, longitude: -0.1278))
        let app = launch(english: true)
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
        capture("regional-business-11-english-onboarding", app)
        XCTAssertEqual(app.staticTexts["setup.title.房源基本信息"].label, "Basic Home Info")
        tap("setup.next", app); tap("setup.mode.simple", app); tap("setup.next", app)
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["currency.prompt.title"].label, "Use Location to Detect Currency")
        capture("regional-business-08-first-checklist-prompt", app)
        tap("currency.prompt.allow", app)
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "regional-business-09-system-location-purpose"; screenshot.lifetime = .keepAlways; add(screenshot)
        let names = ["允许一次", "Allow Once", "使用App时允许", "使用 App 时允许", "Allow While Using App"]
        guard let allow = names.map({ alert.buttons[$0] }).first(where: \.exists) else { return XCTFail("Missing location authorization action") }
        allow.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 35))
        openSettings(app)
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("GBP"), "Real geocoder must identify the simulated UK coordinate")
        capture("regional-business-10-live-country-gbp", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
    }
    func testDeclineUSDManualCurrencyNewHouseAndExistingAmountPersist() {
        let app = launch(returning: true)
        tap("currency.prompt.decline", app)
        openSettings(app)
        XCTAssertTrue(app.buttons["settings.currency"].label.contains("USD"))
        chooseCurrency("GBP", app); tap("tab.房源", app)
        app.homeAddButton.tap()
        let input = app.textFields["prompt.text"]; XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.replacePromptText("放弃"); tap("prompt.confirm", app)
        let search = app.textFields["mp.checklist.search"]; XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("租金"); app.dismissKeyboardFromHeader()
        let rent = app.textFields["mp.field.input.f1_6"]
        XCTAssertTrue(rent.waitForExistence(timeout: 5)); rent.tap(); rent.typeText("2000"); app.dismissKeyboardFromHeader()
        XCTAssertTrue(app.staticTexts["mp.field.title.f1_6"].label.contains("GBP"))
        capture("regional-business-05-gbp-rent", app)
        app.navigationBackButton.tap(); openSettings(app); chooseCurrency("EUR", app)
        tap("tab.房源", app)
        XCTAssertTrue(app.buttons["house.放弃"].label.contains("GBP 2000"))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.放弃"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.放弃"].label.contains("GBP 2000"))
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
        capture("regional-business-06-existing-currency-relaunch", app)
        openSettings(app); XCTAssertTrue(app.buttons["settings.currency"].label.contains("EUR"))
        tap("settings.language", app); tap("language.english", app); app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["settings.language"].label.contains("English"))
        capture("regional-business-12-english-settings", app)
        let trails = app.switches["settings.touch-trails"]
        for _ in 0..<3 where !trails.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(trails.isHittable); XCTAssertFalse(trails.label.contains("触摸轨迹"))
        capture("regional-business-16-english-settings-footer", app)
        tap("tab.房源", app)
        XCTAssertTrue(app.buttons["house.放弃"].exists)
        app.homeAddButton.tap()
        let nextName = app.textFields["prompt.text"]; XCTAssertTrue(nextName.waitForExistence(timeout: 5))
        nextName.replacePromptText("欧元房源"); tap("prompt.confirm", app)
        let englishSearch = app.textFields["mp.checklist.search"]; XCTAssertTrue(englishSearch.waitForExistence(timeout: 5))
        englishSearch.tap(); englishSearch.typeText("rent"); app.dismissKeyboardFromHeader()
        let nextRent = app.textFields["mp.field.input.f1_6"]
        XCTAssertTrue(nextRent.waitForExistence(timeout: 5)); nextRent.tap(); nextRent.typeText("1500"); app.dismissKeyboardFromHeader()
        let title = app.staticTexts["mp.field.title.f1_6"].label
        XCTAssertTrue(title.contains("EUR")); XCTAssertFalse(title.contains("租金"))
        capture("regional-business-13-english-rent-eur", app)
        app.navigationBackButton.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.欧元房源"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.欧元房源"].label.contains("EUR 1500"))
        XCTAssertTrue(app.buttons["house.放弃"].label.contains("GBP 2000"))
        capture("regional-business-14-english-homes-persisted", app)
        tap("tab.对比", app); tap("compare.select.放弃", app); tap("compare.select.欧元房源", app); tap("compare.start", app)
        let comparedRent = app.otherElements["compare.row.f1_6"]
        XCTAssertTrue(comparedRent.waitForExistence(timeout: 5))
        XCTAssertTrue(comparedRent.staticTexts.allElementsBoundByIndex.contains { $0.label.contains("GBP 2000") })
        XCTAssertTrue(comparedRent.staticTexts.allElementsBoundByIndex.contains { $0.label.contains("EUR 1500") })
        if !comparedRent.isHittable { app.scrollViews.firstMatch.swipeUp() }
        capture("regional-business-15-english-comparison", app)
        openSettings(app); XCTAssertTrue(app.buttons["settings.language"].label.contains("English"))
        tap("settings.language", app); tap("language.system", app); app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["settings.language"].label.contains("跟随系统"))
    }
    func testSystemLocationDenialUsesUSDAndDoesNotRepeatAfterRelaunch() {
        let app = launch(returning: true)
        tap("currency.prompt.allow", app)
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = system.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        let deny = alert.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS '允许'")).allElementsBoundByIndex.first { $0.label.contains("Don’t") || $0.label.contains("Don't") || $0.label.contains("不允许") }
        XCTAssertNotNil(deny); deny?.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 8))
        openSettings(app); XCTAssertTrue(app.buttons["settings.currency"].label.contains("USD"))
        capture("regional-business-07-system-denial-usd", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
        XCTAssertFalse(system.alerts.firstMatch.exists)
    }
}
