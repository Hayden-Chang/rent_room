import XCTest

@MainActor final class DevelopmentCreditsBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSettingsGrantPersistsAfterCreationRestoreAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "--capacity-business-fixture", "success", "--stub-system-review",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10)); currency.tap()
        XCTAssertTrue(currency.waitForNonExistence(timeout: 5))
        let settings = app.buttons["tab.我的"]
        XCTAssertTrue(settings.waitForExistence(timeout: 8)); settings.tap()
        let version = app.buttons["settings.development-credits"]
        for _ in 0..<6 { if version.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(version.isHittable)
        capture(app, "settings-development-before")
        version.tap(withNumberOfTaps: 10, numberOfTouches: 1)
        let alert = app.alerts["开发点数"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["已添加 10 个房源点数，仅用于本机开发测试。"].exists)
        capture(app, "settings-development-granted")
        alert.buttons["确定"].tap(); XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        app.buttons["tab.房源"].tap(); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.replacePromptText("开发点数验证")
        app.dismissKeyboardFromHeader()
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 8))
        app.navigationBackButton.tap(); settings.tap()
        let capacity = app.buttons["local-settings.capacity"]
        for _ in 0..<6 { if capacity.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(capacity.isHittable); capacity.tap()
        waitCredits(11, app)
        let restore = app.buttons["credits.restore"]
        for _ in 0..<4 { if restore.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(restore.isHittable); restore.tap()
        let restored = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: restore)
        wait(for: [restored], timeout: 5)
        XCTAssertFalse(app.staticTexts["credits.error"].exists); waitCredits(11, app)
        app.terminate(); app.launch()
        XCTAssertTrue(settings.waitForExistence(timeout: 10)); XCTAssertFalse(currency.exists)
        settings.tap(); app.buttons["local-settings.capacity"].tap()
        waitCredits(11, app)
        capture(app, "settings-development-persisted-after-create")
    }

    private func waitCredits(_ count: Int, _ app: XCUIApplication) {
        let balance = app.staticTexts["credits.balance"]
        XCTAssertTrue(balance.waitForExistence(timeout: 5))
        let ready = expectation(for: NSPredicate(format: "label MATCHES %@", "^\(count)[^0-9]*$"), evaluatedWith: balance)
        wait(for: [ready], timeout: 5)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
