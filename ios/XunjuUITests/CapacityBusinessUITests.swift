import XCTest

@MainActor final class CapacityBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ id: String, mode: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", id, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if let mode { app.launchArguments += ["--capacity-business-fixture", mode] }
        app.launch(); XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.capacity"].tap()
        XCTAssertTrue(app.buttons["capacity.purchase"].waitForExistence(timeout: 5))
        return app
    }
    private func waitTotal(_ text: String, _ app: XCUIApplication) {
        let ready = expectation(for: NSPredicate(format: "label == %@", text), evaluatedWith: app.staticTexts["capacity.total"])
        wait(for: [ready], timeout: 8)
    }
    private func idle(_ app: XCUIApplication) {
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["capacity.restore"])
        wait(for: [ready], timeout: 8)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testGuestCapacityOpensExistingLoginAndSMSFormWithoutRequestingCode() {
        let app = launch(UUID().uuidString)
        XCTAssertEqual(app.buttons["capacity.purchase"].label, "登录后购买")
        waitTotal("0 / 2 套", app); app.buttons["capacity.purchase"].tap()
        XCTAssertTrue(app.buttons["login.phone"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["login.wechat"].exists); XCTAssertTrue(app.buttons["login.apple"].exists)
        app.buttons["login.phone"].tap()
        XCTAssertTrue(app.textFields["phone.number"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["phone.request"].isEnabled)
        capture("94-capacity-guest-phone-login", app)
    }
    func testPendingPurchaseDoesNotGrantAndRestoresOnceAcrossProcessRelaunch() {
        let id = UUID().uuidString, app = launch(id, mode: "pending")
        idle(app); XCTAssertEqual(app.buttons["capacity.purchase"].label, "¥1.99 扩容10个")
        app.buttons["capacity.purchase"].tap()
        XCTAssertTrue(app.staticTexts["capacity.pending"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["capacity.purchase"].isEnabled); waitTotal("0 / 2 套", app)
        capture("95-capacity-unconfirmed-no-grant", app)
        app.buttons["capacity.restore"].tap(); waitTotal("0 / 12 套", app); idle(app)
        XCTAssertFalse(app.staticTexts["capacity.pending"].exists)
        capture("96-capacity-server-confirmed", app)
        app.terminate()
        let reopened = launch(id, mode: "pending"); idle(reopened); waitTotal("0 / 12 套", reopened)
        reopened.buttons["capacity.restore"].tap(); idle(reopened); waitTotal("0 / 12 套", reopened)
        capture("97-capacity-relaunch-restore-idempotent", reopened)
    }
    func testCancellationRefundAndUnavailableProductPreserveOverCapacityHouses() {
        let id = UUID().uuidString, app = launch(id, mode: "refund")
        idle(app); waitTotal("3 / 12 套", app)
        app.buttons["capacity.purchase"].tap(); idle(app); waitTotal("3 / 12 套", app)
        XCTAssertFalse(app.staticTexts["capacity.error"].exists)
        app.buttons["capacity.restore"].tap(); idle(app); waitTotal("3 / 2 套", app)
        capture("98-capacity-refund-retains-houses", app)
        app.terminate()
        let reopened = launch(id, mode: "unavailable"); idle(reopened); waitTotal("3 / 2 套", reopened)
        XCTAssertFalse(reopened.buttons["capacity.purchase"].isEnabled)
        capture("99-capacity-unavailable-retains-houses", reopened)
        reopened.navigationBars.buttons.element(boundBy: 0).tap(); reopened.buttons["tab.房源"].tap()
        for i in 1...3 { XCTAssertTrue(reopened.staticTexts["退款保留\(i)"].exists) }
    }
}
