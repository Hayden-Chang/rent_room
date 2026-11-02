import XCTest

@MainActor final class DevelopmentCreditsReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testVersionLabelRequiresTenTapsAndCanRepeatInChinese() {
        let app = launch(language: "zh-Hans")
        let label = app.buttons["settings.development-credits"]
        XCTAssertTrue(label.waitForExistence(timeout: 8))
        XCTAssertEqual(label.label, "版本")
        capture(app, "development-credits-before-zh")
        // A real native multi-tap burst keeps the interaction within the five-second window.
        label.tap(withNumberOfTaps: 9, numberOfTouches: 1)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertEqual(app.staticTexts["development-review.balance"].label, "0 点")
        label.tap()
        let alert = app.alerts["开发点数"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["已添加 10 个房源点数，仅用于本机开发测试。"].exists)
        capture(app, "development-credits-success-zh")
        alert.buttons["确定"].tap()
        XCTAssertTrue(label.waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["development-review.balance"].label, "10 点")
        label.tap(withNumberOfTaps: 10, numberOfTouches: 1)
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["确定"].tap()
        XCTAssertEqual(app.staticTexts["development-review.balance"].label, "20 点")
        capture(app, "development-credits-repeat-zh")
    }

    func testEnglishVersionLabelAndSuccessCopy() {
        let app = launch(language: "en")
        let label = app.buttons["settings.development-credits"]
        XCTAssertTrue(label.waitForExistence(timeout: 8))
        XCTAssertEqual(label.label, "Version")
        label.tap(withNumberOfTaps: 10, numberOfTouches: 1)
        let alert = app.alerts["Development credits"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["Added 10 property credits for development testing on this device."].exists)
        capture(app, "development-credits-success-en")
    }

    func testFailedGrantShowsFailureAndPreservesBalance() {
        let app = launch(language: "zh-Hans", failure: true)
        let label = app.buttons["settings.development-credits"]
        XCTAssertTrue(label.waitForExistence(timeout: 8))
        label.tap(withNumberOfTaps: 10, numberOfTouches: 1)
        let alert = app.alerts["开发点数"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["点数添加失败，请重试。"].exists)
        capture(app, "development-credits-failure-zh")
        alert.buttons["确定"].tap()
        XCTAssertEqual(app.staticTexts["development-review.balance"].label, "0 点")
    }

    private func launch(language: String, failure: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--local-settings-review", failure ? "developmentCreditsFailure" : "developmentCredits",
            "-AppleLanguages", "(\(language))", "-AppleLocale", language == "en" ? "en_US" : "zh_CN"]
        app.launch()
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
