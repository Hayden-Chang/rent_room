import XCTest

@MainActor final class CapacityReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "capacity", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["capacity.purchase"].waitForExistence(timeout: 10)); return app
    }
    private func state(_ name: String, _ app: XCUIApplication) {
        app.buttons["review.capacity.state"].tap(); app.buttons[name].tap()
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testGuestLoginPurchaseBusyAndCancelKeepCapacity() {
        let app = launch(), buy = app.buttons["capacity.purchase"], restore = app.buttons["capacity.restore"]
        XCTAssertEqual(buy.label, "登录后购买"); XCTAssertEqual(restore.label, "登录并恢复容量")
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "2 / 2 套")
        capture("85-capacity-guest", app)
        buy.tap(); restore.tap()
        XCTAssertTrue(app.staticTexts["review.capacity.events"].label.contains("登录回调 2 次"))
        state("已登录", app); XCTAssertEqual(buy.label, "¥1.99 扩容10个"); XCTAssertEqual(restore.label, "恢复已购容量")
        capture("86-capacity-ready", app)
        buy.tap(); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.capacity.events"].label.contains("购买回调 1 次"))
        capture("87-capacity-purchase-waiting", app)
        state("取消购买", app); XCTAssertTrue(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertFalse(app.staticTexts["capacity.error"].exists)
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "2 / 2 套")
    }
    func testUnavailablePendingRestoreFailureAndOverCapacityKeepRecords() {
        let app = launch(), buy = app.buttons["capacity.purchase"], restore = app.buttons["capacity.restore"]
        state("商品加载", app); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertEqual(buy.label, "正在加载房源包…")
        capture("88-capacity-product-loading", app)
        state("商品未开放", app); XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertEqual(app.staticTexts["capacity.price"].label, "暂不可用")
        XCTAssertTrue(app.staticTexts["capacity.error"].label.contains("暂未开放"))
        capture("89-capacity-product-unavailable", app)
        state("等待购买确认", app); XCTAssertFalse(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["capacity.pending"].exists); capture("90-capacity-purchase-pending", app)
        restore.tap(); XCTAssertFalse(buy.isEnabled); XCTAssertFalse(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["review.capacity.events"].label.contains("恢复回调 1 次"))
        let restoring = app.buttons.matching(NSPredicate(format: "identifier == 'capacity.restore' AND label CONTAINS '正在恢复容量'")).firstMatch
        XCTAssertTrue(restoring.waitForExistence(timeout: 3))
        capture("91-capacity-restore-waiting", app)
        state("恢复失败", app); XCTAssertTrue(buy.isEnabled); XCTAssertTrue(restore.isEnabled)
        XCTAssertTrue(app.staticTexts["capacity.error"].label.contains("购买记录暂时无法确认"))
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "2 / 2 套"); capture("92-capacity-restore-error", app)
        restore.tap(); XCTAssertTrue(app.staticTexts["review.capacity.events"].label.contains("恢复回调 2 次"))
        state("已有记录超过容量", app); XCTAssertEqual(app.staticTexts["capacity.total"].label, "12 / 2 套")
        capture("93-capacity-existing-over-limit", app)
    }
}
