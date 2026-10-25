import XCTest

@MainActor final class CapacityBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ id: String, mode: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", id, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
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
    func testGuestCapacityOpensAppleOnlyLogin() {
        let app = launch(UUID().uuidString)
        XCTAssertEqual(app.buttons["capacity.purchase"].label, "登录后购买")
        waitTotal("0 / 1 套", app); app.buttons["capacity.purchase"].tap()
        XCTAssertTrue(app.buttons["login.apple"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["login.wechat"].exists)
        XCTAssertFalse(app.buttons["login.phone"].exists)
        capture("94-capacity-guest-apple-login", app)
    }
    func testPendingPurchaseDoesNotGrantAndRestoresOnceAcrossProcessRelaunch() {
        let id = UUID().uuidString, app = launch(id, mode: "pending")
        idle(app); XCTAssertEqual(app.buttons["capacity.purchase"].label, "¥1.99 扩容10个")
        app.buttons["capacity.purchase"].tap()
        XCTAssertTrue(app.staticTexts["capacity.pending"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["capacity.purchase"].isEnabled); waitTotal("0 / 1 套", app)
        capture("95-capacity-unconfirmed-no-grant", app)
        app.buttons["capacity.restore"].tap(); waitTotal("0 / 11 套", app); idle(app)
        XCTAssertFalse(app.staticTexts["capacity.pending"].exists)
        capture("96-capacity-server-confirmed", app)
        app.terminate()
        let reopened = launch(id, mode: "pending"); idle(reopened); waitTotal("0 / 11 套", reopened)
        reopened.buttons["capacity.restore"].tap(); idle(reopened); waitTotal("0 / 11 套", reopened)
        capture("97-capacity-relaunch-restore-idempotent", reopened)
    }
    func testCancellationRefundAndUnavailableProductPreserveOverCapacityHouses() {
        let id = UUID().uuidString, app = launch(id, mode: "refund")
        idle(app); waitTotal("3 / 11 套", app)
        app.buttons["capacity.purchase"].tap(); idle(app); waitTotal("3 / 11 套", app)
        XCTAssertFalse(app.staticTexts["capacity.error"].exists)
        app.buttons["capacity.restore"].tap(); idle(app); waitTotal("3 / 1 套", app)
        capture("98-capacity-refund-retains-houses", app)
        app.terminate()
        let reopened = launch(id, mode: "unavailable"); idle(reopened); waitTotal("3 / 1 套", reopened)
        XCTAssertFalse(reopened.buttons["capacity.purchase"].isEnabled)
        capture("99-capacity-unavailable-retains-houses", reopened)
        reopened.navigationBars.buttons.element(boundBy: 0).tap(); reopened.buttons["tab.房源"].tap()
        for i in 1...3 { XCTAssertTrue(reopened.staticTexts["退款保留\(i)"].exists) }
    }
    func testZeroPolicyKeepsExistingHouseEditableAndBlocksCreateAndRestore() {
        let id = UUID().uuidString, app = launch(id, mode: "zero")
        idle(app); waitTotal("1 / 0 套", app)
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.buttons["tab.房源"].tap()
        app.buttons["house.超额保留"].tap()
        let query = app.textFields["mp.checklist.search"]
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        let rent = app.textFields["mp.field.input.f1_6"]; XCTAssertTrue(rent.waitForExistence(timeout: 3))
        rent.replacePromptText("1800"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(rent.value as? String, "1800")
        app.navigationBars.buttons.element(boundBy: 0).tap(); app.buttons["home.add"].tap()
        waitTotal("1 / 0 套", app); XCTAssertFalse(app.buttons["capacity.continue"].isEnabled)
        capture("business-zero-capacity-create-blocked", app)
        app.navigationBars.buttons["返回"].tap(); app.buttons["tab.我的"].tap(); app.buttons["settings.archive"].tap()
        app.buttons["archive.restore.零额度待恢复"].tap()
        waitTotal("1 / 0 套", app); XCTAssertFalse(app.buttons["capacity.continue"].isEnabled)
        app.navigationBars.buttons["返回"].tap()
        XCTAssertTrue(app.buttons["archive.open.零额度待恢复"].waitForExistence(timeout: 3))
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.超额保留"].waitForExistence(timeout: 10)); app.buttons["house.超额保留"].tap()
        query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(rent.value as? String, "1800")
    }
    func testConfirmedRestoreContinuesInterruptedCreateWithoutAutoCreatingHouse() {
        let app = launch(UUID().uuidString, mode: "pending")
        idle(app); app.navigationBars.buttons.element(boundBy: 0).tap(); app.buttons["tab.房源"].tap()
        app.buttons["home.add"].tap(); XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3)); app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5)); app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["home.add"].tap(); waitTotal("1 / 1 套", app); idle(app)
        app.buttons["capacity.purchase"].tap(); XCTAssertTrue(app.staticTexts["capacity.pending"].waitForExistence(timeout: 5))
        waitTotal("1 / 1 套", app); XCTAssertFalse(app.textFields["prompt.text"].exists)
        app.buttons["capacity.restore"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 12))
        XCTAssertEqual(name.value as? String, "第2套")
        capture("business-capacity-resumes-original-create", app)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["house.第1套"].waitForExistence(timeout: 3)); XCTAssertFalse(app.buttons["house.第2套"].exists)
    }

}
