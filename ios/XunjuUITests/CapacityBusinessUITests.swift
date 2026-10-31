import XCTest

@MainActor final class CapacityBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ id: String, mode: String? = nil, firstLaunch: Bool = true, openCapacity: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", id, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if let mode { app.launchArguments += ["--capacity-business-fixture", mode, "--stub-system-review"] }
        app.launch()
        let currencyPrompt = app.buttons["currency.prompt.decline"]
        if firstLaunch {
            XCTAssertTrue(currencyPrompt.waitForExistence(timeout: 10))
            currencyPrompt.tap()
            XCTAssertTrue(currencyPrompt.waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        XCTAssertFalse(currencyPrompt.exists, "Currency choice must persist across a process relaunch")
        if openCapacity {
            app.buttons["tab.我的"].tap(); app.buttons["local-settings.capacity"].tap()
            XCTAssertTrue(app.buttons["credits.purchase"].waitForExistence(timeout: 5))
        }
        return app
    }
    private func waitCredits(_ count: Int, _ app: XCUIApplication) {
        let ready = expectation(for: NSPredicate(format: "label MATCHES %@", "^\(count)[^0-9]*$"), evaluatedWith: app.staticTexts["credits.balance"])
        wait(for: [ready], timeout: 8)
    }
    private func idle(_ app: XCUIApplication) {
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["credits.restore"])
        wait(for: [ready], timeout: 8)
    }
    private func waitShortageReminder(_ app: XCUIApplication) {
        let message = app.otherElements["xiaoda.message"]
        XCTAssertTrue(message.waitForExistence(timeout: 3))
        XCTAssertEqual(message.label, "你的房源点数不够啦～")
        let complete = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message)
        wait(for: [complete], timeout: 3)
        XCTAssertLessThan(message.frame.maxY, app.staticTexts["credits.balance"].frame.minY)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testNewPropertyAtZeroCreditsShowsPointPurchaseAndCanReturn() {
        let app = launch(UUID().uuidString, mode: "zero", openCapacity: false)
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        app.buttons["home.add"].tap()
        let buy = app.buttons["credits.purchase"]
        XCTAssertTrue(buy.waitForExistence(timeout: 5)); idle(app); waitCredits(0, app)
        XCTAssertEqual(buy.label, "¥9.90 购买 10 点")
        XCTAssertEqual(app.staticTexts["credits.rules"].label, "1 点 = 1 套新增房源")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '小饼干' OR label CONTAINS '🍪' OR label CONTAINS '已转换'")).firstMatch.exists)
        XCTAssertFalse(app.buttons["先等等"].exists)
        XCTAssertFalse(app.textFields["prompt.text"].exists)
        waitShortageReminder(app)
        capture("new-property-zero-credits-purchase", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["house.超额保留"].exists)
        XCTAssertFalse(app.textFields["prompt.text"].exists)
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.capacity"].tap()
        waitCredits(0, app); idle(app)
        XCTAssertFalse(app.otherElements["xiaoda.message"].exists, "Settings must not show the new-property reminder")
        capture("settings-zero-credits-without-reminder", app)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        app.buttons["home.add"].tap(); waitCredits(0, app)
        waitShortageReminder(app)
        XCTAssertEqual(buy.label, "¥9.90 购买 10 点")
    }
    func testPendingPurchaseDoesNotGrantAndRestoresOnceAcrossProcessRelaunch() {
        let id = UUID().uuidString, app = launch(id, mode: "pending")
        idle(app); XCTAssertEqual(app.buttons["credits.purchase"].label, "¥9.90 购买 10 点")
        XCTAssertFalse(app.otherElements["xiaoda.message"].exists)
        app.buttons["credits.purchase"].tap()
        XCTAssertTrue(app.staticTexts["credits.pending"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["credits.purchase"].isEnabled); waitCredits(2, app)
        capture("95-capacity-unconfirmed-no-grant", app)
        app.buttons["credits.restore"].tap(); waitCredits(12, app); idle(app)
        XCTAssertFalse(app.staticTexts["credits.pending"].exists)
        capture("96-capacity-locally-confirmed", app)
        app.terminate()
        let reopened = launch(id, mode: "pending", firstLaunch: false); idle(reopened); waitCredits(12, reopened)
        reopened.buttons["credits.restore"].tap(); idle(reopened); waitCredits(12, reopened)
        capture("97-capacity-relaunch-restore-idempotent", reopened)
    }
    func testCancellationRefundAndUnavailableProductPreserveOverCapacityHouses() {
        let id = UUID().uuidString, app = launch(id, mode: "refund")
        idle(app); waitCredits(9, app)
        app.buttons["credits.purchase"].tap(); idle(app); waitCredits(9, app)
        XCTAssertFalse(app.staticTexts["credits.error"].exists)
        app.buttons["credits.restore"].tap(); idle(app); waitCredits(0, app)
        capture("98-capacity-refund-retains-houses", app)
        app.terminate()
        let reopened = launch(id, mode: "unavailable", firstLaunch: false); idle(reopened); waitCredits(0, reopened)
        XCTAssertFalse(reopened.buttons["credits.purchase"].isEnabled)
        capture("99-capacity-unavailable-retains-houses", reopened)
        reopened.navigationBackButton.tap(); reopened.buttons["tab.房源"].tap()
        for i in 1...3 { XCTAssertTrue(reopened.staticTexts["退款保留\(i)"].exists) }
    }
    func testZeroCreditsKeepExistingHouseEditableBlockCreateAndAllowRestore() {
        let id = UUID().uuidString, app = launch(id, mode: "zero")
        idle(app); waitCredits(0, app)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        app.buttons["house.超额保留"].tap()
        let query = app.textFields["mp.checklist.search"]
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        let rent = app.textFields["mp.field.input.f1_6"]; XCTAssertTrue(rent.waitForExistence(timeout: 3))
        rent.replacePromptText("1800"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(rent.value as? String, "1800")
        app.navigationBackButton.tap(); app.buttons["home.add"].tap()
        waitCredits(0, app); XCTAssertFalse(app.textFields["prompt.text"].exists)
        capture("business-zero-capacity-create-blocked", app)
        app.navigationBackButton.tap(); app.buttons["tab.我的"].tap(); app.buttons["local-settings.archive"].tap()
        app.buttons["archive.open.零额度待恢复"].press(forDuration: 1)
        app.buttons["archive.restore.零额度待恢复"].tap()
        XCTAssertTrue(app.buttons["archive.open.零额度待恢复"].waitForNonExistence(timeout: 5))
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.buttons["house.零额度待恢复"].waitForExistence(timeout: 5))
        capture("credits-zero-archive-restored", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.超额保留"].waitForExistence(timeout: 10)); app.buttons["house.超额保留"].tap()
        query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(rent.value as? String, "1800")
    }
    func testConfirmedRestoreContinuesInterruptedCreateWithoutAutoCreatingHouse() {
        let app = launch(UUID().uuidString, mode: "pending")
        idle(app); app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        for _ in 0..<2 {
            app.buttons["home.add"].tap(); XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3)); app.buttons["prompt.confirm"].tap()
            XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5)); app.navigationBackButton.tap()
        }
        app.buttons["home.add"].tap(); waitCredits(0, app); idle(app)
        waitShortageReminder(app)
        app.buttons["credits.purchase"].tap(); XCTAssertTrue(app.staticTexts["credits.pending"].waitForExistence(timeout: 5))
        waitCredits(0, app); XCTAssertFalse(app.textFields["prompt.text"].exists)
        waitShortageReminder(app)
        capture("new-property-pending-credits-reminder", app)
        app.buttons["credits.restore"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 12))
        XCTAssertEqual(name.value as? String, "第3套")
        XCTAssertFalse(app.otherElements["xiaoda.message"].exists)
        capture("business-capacity-resumes-original-create", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["house.第1套"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["house.第2套"].exists); XCTAssertFalse(app.buttons["house.第3套"].exists)
    }

}
