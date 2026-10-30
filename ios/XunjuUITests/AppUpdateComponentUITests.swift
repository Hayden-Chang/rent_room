import XCTest

@MainActor final class AppUpdateComponentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "app-update", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["settings.checkUpdate"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func expectValue(_ value: String, _ app: XCUIApplication) {
        let condition = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: app.buttons["settings.checkUpdate"])
        wait(for: [condition], timeout: 4)
    }

    private func respond(_ response: String, expected: String, _ app: XCUIApplication) {
        app.buttons["review.update.response"].tap()
        app.buttons[response].tap()
        app.buttons["settings.checkUpdate"].tap()
        XCTAssertTrue(app.buttons["review.update.finish"].waitForExistence(timeout: 3))
        app.buttons["review.update.finish"].tap()
        expectValue(expected, app)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertTrue(app.buttons["settings.checkUpdate"].isEnabled)
        XCTAssertEqual(app.buttons["settings.checkUpdate"].label, "检查更新")
    }

    func testCheckingNewVersionLaterAndStoreHandoffFailure() {
        let app = launch(), row = app.buttons["settings.checkUpdate"]
        let version = app.staticTexts["settings.version"], title = app.staticTexts["settings.versionLabel"]
        XCTAssertTrue(version.exists)
        XCTAssertEqual(row.label, "检查更新")
        XCTAssertEqual(title.frame.midY, version.frame.midY, accuracy: 1)
        XCTAssertEqual(version.frame.midY, row.frame.midY, accuracy: 1)
        XCTAssertGreaterThan(version.frame.minX, title.frame.maxX)
        XCTAssertLessThanOrEqual(version.frame.minX - title.frame.maxX, 9)
        XCTAssertGreaterThan(row.frame.minX, version.frame.maxX)
        capture("update-01-idle", app)
        let ready = expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: row)
        wait(for: [ready], timeout: 4)
        row.tap()
        expectValue("正在检查…", app)
        XCTAssertFalse(row.isEnabled)
        capture("update-02-checking", app)
        app.buttons["review.update.finish"].tap()
        let alert = app.alerts["发现新版本"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["版本 1.2.0 已可下载，前往 App Store 更新。"].exists)
        capture("update-03-new-version", app)
        alert.buttons["稍后"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        expectValue("新版本 1.2.0", app)
        XCTAssertEqual(row.label, "去更新")
        XCTAssertEqual(app.staticTexts["review.update.events"].label, "检查 1 次 · 商店跳转回调 0 次")
        capture("update-04-later", app)
        row.tap()
        expectValue("无法打开 App Store，请重试", app)
        XCTAssertEqual(app.staticTexts["review.update.events"].label, "检查 1 次 · 商店跳转回调 1 次")
        XCTAssertFalse(app.buttons["review.update.finish"].exists)
        capture("update-05-store-failure", app)
        row.tap()
        XCTAssertTrue(app.buttons["review.update.finish"].waitForExistence(timeout: 3))
        app.buttons["review.update.finish"].tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["去更新"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        expectValue("无法打开 App Store，请重试", app)
        XCTAssertEqual(app.staticTexts["review.update.events"].label, "检查 2 次 · 商店跳转回调 2 次")
    }

    func testCurrentUnavailableAndNetworkFailureCanRetry() {
        let app = launch()
        respond("已是最新版本", expected: "已是最新版本", app)
        capture("update-06-current", app)
        respond("商店暂无版本", expected: "暂未查询到上架版本", app)
        capture("update-07-unavailable", app)
        respond("网络失败", expected: "检查失败，请重试", app)
        capture("update-08-network-failure", app)
        respond("已是最新版本", expected: "已是最新版本", app)
        XCTAssertEqual(app.staticTexts["review.update.events"].label, "检查 4 次 · 商店跳转回调 0 次")
    }

    func testSystemRequirementAndMissingStorefrontDoNotOfferUpdate() {
        let app = launch()
        respond("需要升级系统", expected: "需 iOS 26.0 或更高版本", app)
        capture("update-09-system-required", app)
        respond("无法获取商店", expected: "暂时无法获取商店信息", app)
        capture("update-10-storefront-unavailable", app)
        XCTAssertEqual(app.staticTexts["review.update.events"].label, "检查 2 次 · 商店跳转回调 0 次")
    }
}
