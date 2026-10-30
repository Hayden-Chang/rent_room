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
        XCTAssertEqual(buy.label, "¥9.90 购买 10 点")
        XCTAssertEqual(app.staticTexts["credits.rules"].label, "1 点 = 1 套新增房源")
        XCTAssertFalse(app.staticTexts["10 个房源点数"].exists)
        XCTAssertGreaterThan(app.staticTexts["credits.rules"].frame.minY, app.staticTexts["credits.balance"].frame.maxY)
        XCTAssertLessThan(app.staticTexts["credits.rules"].frame.maxY, buy.frame.minY)
        XCTAssertFalse(app.buttons["先等等"].exists)
        XCTAssertGreaterThan(buy.frame.width, app.frame.width * 0.7)
        XCTAssertGreaterThanOrEqual(buy.frame.height, 52)
        XCTAssertFalse(app.staticTexts["credits.migration"].exists)
        XCTAssertFalse(app.staticTexts["导入或从归档恢复不消耗点数"].exists)
        XCTAssertFalse(app.staticTexts["归档或删除不返还已用点数"].exists)
        capture("credits-ios-china", app)
        buy.tap()
        XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.credits.events"].label.contains("购买回调 1 次"))
        capture("credits-ios-purchasing", app)
        state("取消购买", app)
        XCTAssertTrue(buy.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        state("美国区英文", app)
        XCTAssertEqual(buy.label, "$1.99 Buy 10 credits")
        XCTAssertEqual(app.staticTexts["credits.rules"].label, "1 credit = 1 new property")
        XCTAssertFalse(app.staticTexts["10 property credits"].exists)
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
