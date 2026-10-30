import XCTest

@MainActor final class CapacityReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "capacity", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["credits.purchase"].waitForExistence(timeout: 10)); return app
    }
    private func state(_ name: String, _ app: XCUIApplication) {
        app.buttons["review.credits.state"].tap(); app.buttons[name].tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testPurchaseBusyAndCancellationKeepCreditsWithoutAccountControls() {
        let app = launch(), buy = app.buttons["credits.purchase"], restore = app.buttons["credits.restore"]
        XCTAssertEqual(buy.label, "¥9.90 购买 10 点")
        XCTAssertEqual(restore.label, "恢复购买记录")
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        XCTAssertEqual(app.staticTexts["credits.rules"].label, "1 点 = 1 套新增房源")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '小饼干' OR label CONTAINS '🍪'")).firstMatch.exists)
        capture("shortage-legacy-review-unified", app)
        buy.tap(); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.credits.events"].label.contains("购买回调 1 次"))
        state("取消购买", app); XCTAssertTrue(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertFalse(app.staticTexts["credits.error"].exists)
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
    }
    func testUnavailablePendingRestoreFailureAndZeroCredits() {
        let app = launch(), buy = app.buttons["credits.purchase"], restore = app.buttons["credits.restore"]
        state("商品加载", app); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertEqual(buy.label, "正在加载点数包…")
        state("商品不可用", app); XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertEqual(buy.label, "点数包暂未开放")
        state("等待支付", app); XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.pending"].exists)
        restore.tap(); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.credits.events"].label.contains("恢复回调 1 次"))
        XCTAssertEqual(restore.label, "正在恢复购买记录…")
        state("恢复失败", app); XCTAssertTrue(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["credits.error"].label.contains("购买记录暂时无法确认"))
        XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("7"))
        state("点数用完", app); XCTAssertTrue(app.staticTexts["credits.balance"].label.contains("0"))
        XCTAssertTrue(buy.isEnabled); capture("shortage-legacy-review-zero", app)
    }
}
