import XCTest

@MainActor final class LocalSettingsReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSettingsHasCapacityAndLegalLinksWithoutAccountControls() {
        let app = launch("settings")
        XCTAssertTrue(app.buttons["local-settings.capacity"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["退出登录"].exists)
        XCTAssertFalse(app.textFields["settings.nickname"].exists)
        XCTAssertFalse(app.buttons["settings.avatar"].exists)
        capture(app, "offline-settings-top")
        app.buttons["local-settings.capacity"].tap()
        let privacy = app.buttons["legal.privacy"]
        for _ in 0..<4 { if privacy.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(privacy.isHittable)
        capture(app, "offline-settings-legal")
        privacy.tap()
        let event = app.staticTexts["local-review.event"]
        XCTAssertTrue(event.label.hasSuffix("/privacy-policies/kanfangdazi/privacy-policy.html"))
        app.buttons["legal.support"].tap()
        XCTAssertTrue(event.label.hasSuffix("/kanfangdazi/"))
    }

    func testAccountFreePurchasePendingAndNetworkFailurePreserveDisplayedCapacity() {
        let app = launch("capacity")
        let purchase = app.buttons["capacity.purchase"]
        XCTAssertTrue(purchase.waitForExistence(timeout: 8))
        XCTAssertTrue(purchase.label.contains("¥1.99"))
        XCTAssertFalse(purchase.label.contains("登录"))
        capture(app, "offline-capacity-ready")
        purchase.tap()
        XCTAssertTrue(app.staticTexts["capacity.pending"].waitForExistence(timeout: 3))
        XCTAssertFalse(purchase.isEnabled)
        capture(app, "offline-capacity-pending")
        let restore = app.buttons["capacity.restore"]
        for _ in 0..<3 { if restore.isHittable { break }; app.swipeUp() }
        XCTAssertEqual(restore.label, "恢复已购容量")
        restore.tap()
        XCTAssertTrue(app.staticTexts["capacity.error"].waitForExistence(timeout: 3))
        XCTAssertTrue(purchase.isEnabled)
        XCTAssertTrue(app.staticTexts["capacity.total"].label.contains("1 / 1"))
        capture(app, "offline-capacity-network-error")
    }

    private func launch(_ route: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--local-settings-review", route, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
