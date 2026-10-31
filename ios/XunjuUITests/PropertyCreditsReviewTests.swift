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
    func testXiaodaReminderOnlyForCreationWithNoCredits() {
        let app = launch(), message = app.otherElements["xiaoda.message"]
        XCTAssertFalse(message.exists)
        state("点数用完", app)
        XCTAssertFalse(message.exists, "A zero balance opened from settings does not ask the user to buy")
        state("新建时点数不足", app)
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        XCTAssertEqual(message.label, "你的房源点数不够啦～")
        let complete = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message)
        wait(for: [complete], timeout: 3)
        XCTAssertLessThan(message.frame.maxY, app.staticTexts["credits.balance"].frame.minY)
        XCTAssertTrue(app.buttons["credits.purchase"].isHittable)
        XCTAssertEqual(app.buttons["credits.purchase"].label, "¥9.90 购买 10 点")
        capture("credits-xiaoda-shortage", app)
        app.buttons["credits.purchase"].tap()
        XCTAssertFalse(app.buttons["credits.purchase"].isEnabled)
        XCTAssertTrue(message.exists)
        state("取消购买", app)
        XCTAssertTrue(message.exists)
        state("新建点数已到账", app)
        XCTAssertTrue(message.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("10"))
        capture("credits-xiaoda-sufficient", app)
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
