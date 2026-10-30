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

    func testDismissCollapsesSpaceAndStaysDismissedAfterRelaunch() {
        let app = launch()
        let dismiss = app.buttons["home.longPressHint.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 8))
        XCTAssertEqual(dismiss.label, "我知道了")
        XCTAssertEqual(app.staticTexts["home.longPressHint.message"].label, "长按支持更多操作")
        let house = app.buttons["hint.review.house"]
        let before = house.frame.minY
        capture("house-hint-before", app)
        dismiss.tap()
        XCTAssertTrue(dismiss.waitForNonExistence(timeout: 3))
        XCTAssertLessThan(house.frame.minY, before - 50)
        let after = house.frame.minY
        capture("house-hint-after", app)
        app.terminate(); app.launch()
        XCTAssertTrue(house.waitForExistence(timeout: 8))
        XCTAssertFalse(dismiss.exists)
        XCTAssertEqual(house.frame.minY, after, accuracy: 1)
        capture("house-hint-reopened", app)
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
