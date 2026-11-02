import XCTest

@MainActor final class HouseLongPressHintUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(extra: [String] = [], language: String = "zh-Hans") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "house-long-press-hint", "--hint-review-id", UUID().uuidString,
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"] + extra
        app.launch()
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10))
        currency.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 3))
        return app
    }

    func testDismissCollapsesSpaceAndStaysDismissedAfterRelaunch() {
        let app = launchHome()
        let dismiss = app.buttons["home.longPressHint.dismiss"]
        XCTAssertFalse(dismiss.exists)
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        capture("house-hint-home-empty", app)
        add.tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.replacePromptText("提示验收房源")
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
        app.navigationBackButton.tap()
        XCTAssertTrue(dismiss.waitForExistence(timeout: 8))
        XCTAssertEqual(dismiss.label, "我知道了")
        XCTAssertEqual(app.staticTexts["home.longPressHint.message"].label, "长按支持更多操作")
        let house = app.buttons["house.提示验收房源"]
        let before = house.frame.minY
        let houseLabel = house.label
        capture("house-hint-home-before", app)
        dismiss.tap()
        XCTAssertTrue(dismiss.waitForNonExistence(timeout: 3))
        XCTAssertEqual(before - house.frame.minY, 68, accuracy: 1)
        let after = house.frame.minY
        XCTAssertEqual(house.label, houseLabel)
        capture("house-hint-home-after", app)
        app.buttons["tab.我的"].tap()
        XCTAssertTrue(app.buttons["local-settings.capacity"].waitForExistence(timeout: 5))
        app.buttons["tab.房源"].tap()
        XCTAssertTrue(house.waitForExistence(timeout: 5))
        XCTAssertFalse(dismiss.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(house.waitForExistence(timeout: 8))
        XCTAssertFalse(dismiss.exists)
        XCTAssertEqual(house.frame.minY, after, accuracy: 1)
        XCTAssertEqual(house.label, houseLabel)
        capture("house-hint-home-reopened", app)
        house.press(forDuration: 1)
        XCTAssertTrue(app.buttons["重命名"].waitForExistence(timeout: 3))
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 4, dy: app.frame.height / 2)).tap()
        XCTAssertTrue(app.buttons["重命名"].waitForNonExistence(timeout: 3))
        house.tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
    }

    func testEmptyListWaitsUntilThereIsAHouse() {
        let app = launch(extra: ["--hint-review-empty"])
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["home.longPressHint.dismiss"].exists)
        capture("house-hint-empty", app)
        add.tap()
        XCTAssertTrue(app.buttons["home.longPressHint.dismiss"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["hint.review.house"].exists)
    }

    func testEnglishLargeTextKeepsDismissAccessible() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"], language: "en")
        let dismiss = app.buttons["home.longPressHint.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 8))
        XCTAssertEqual(dismiss.label, "Got it")
        XCTAssertEqual(app.staticTexts["home.longPressHint.message"].label, "Long press for more actions")
        XCTAssertTrue(dismiss.isHittable)
        XCTAssertGreaterThanOrEqual(dismiss.frame.height, 44)
        XCTAssertLessThanOrEqual(dismiss.frame.maxX, app.frame.maxX - 16)
        capture("house-hint-english-large", app)
        dismiss.tap()
        XCTAssertTrue(dismiss.waitForNonExistence(timeout: 3))
    }
}
