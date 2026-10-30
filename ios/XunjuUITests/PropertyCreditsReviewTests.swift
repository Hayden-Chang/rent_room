import XCTest

@MainActor final class PropertyCreditsReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "property-credits", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["credits.purchase"].waitForExistence(timeout: 10))
        return app
    }
    private func state(_ name: String, _ app: XCUIApplication) {
        app.buttons["review.credits.state"].tap(); app.buttons[name].tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLocalizedPricesRulesAndPurchaseCancellationPreserveBalance() {
        let app = launch(), buy = app.buttons["credits.purchase"], restore = app.buttons["credits.restore"]
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        XCTAssertEqual(buy.label, "¥9.90 购买小饼干")
        XCTAssertTrue(app.staticTexts["新建 1 套房源消耗 1 点"].exists)
        XCTAssertTrue(app.staticTexts["导入或从归档恢复不消耗点数"].exists)
        XCTAssertTrue(app.staticTexts["归档或删除不返还已用点数"].exists)
        capture("credits-ios-china", app)
        buy.tap()
        XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.credits.events"].label.contains("购买回调 1 次"))
        capture("credits-ios-purchasing", app)
        state("取消购买", app)
        XCTAssertTrue(buy.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        state("美国区英文", app)
        XCTAssertEqual(buy.label, "$1.99 Buy a cookie")
        XCTAssertTrue(app.staticTexts["Creating a property uses 1 credit"].exists)
        XCTAssertTrue(app.staticTexts["Importing or restoring an archived property is free"].exists)
        capture("credits-ios-us-english", app)
        state("点数用完", app)
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("0"))
        XCTAssertTrue(buy.isEnabled)
        capture("credits-ios-empty", app)
    }
    func testUnavailablePendingAndRestoreFailureDoNotGrantCredits() {
        let app = launch(), buy = app.buttons["credits.purchase"], restore = app.buttons["credits.restore"]
        state("商品加载", app)
        XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        state("商品不可用", app)
        XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        capture("credits-ios-unavailable", app)
        state("等待支付", app)
        XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.pending"].exists)
        capture("credits-ios-pending", app)
        restore.tap()
        XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.credits.events"].label.contains("恢复回调 1 次"))
        state("恢复失败", app)
        XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.error"].exists)
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        capture("credits-ios-restore-error", app)
    }
}
