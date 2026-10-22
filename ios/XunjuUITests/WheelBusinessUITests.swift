import XCTest

@MainActor final class WheelBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let floor = "fc76beec-52e3-4fe9-a937-dec254d4cc4f"
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("轮盘正式表单"); app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }
        app.buttons["coach.preference"].tap(); next.tap()
        XCTAssertTrue(app.textFields["mp.checklist.search"].waitForExistence(timeout: 3))
        return app
    }
    private func search(_ query: String, _ app: XCUIApplication) {
        app.buttons["回到顶部"].tap()
        let input = app.textFields["mp.checklist.search"]; input.tap()
        let old = input.value as? String ?? ""
        if old != "搜索检查项、结果或备注" { input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        input.typeText(query); app.buttons["checklist.keyboard.done"].tap()
    }
    private func open(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons["mp.field.wheel.\(id)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3)); button.tap()
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tab.清单"].isHittable)
    }
    private func choose(_ label: String, _ app: XCUIApplication) {
        let wheel = app.pickerWheels.firstMatch; wheel.adjust(toPickerWheelValue: label)
        let settled = expectation(for: NSPredicate(format: "value == %@", label), evaluatedWith: wheel)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
    }
    private func confirm(_ app: XCUIApplication) {
        app.buttons["wheel.confirm"].tap()
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForNonExistence(timeout: 3))
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testChecklistWheelOtherCancelAndRelaunchPersistence() {
        let app = launch(); search("楼层", app); open(floor, app)
        choose("12 层", app); app.buttons["wheel.close"].tap()
        XCTAssertTrue(app.buttons["wheel.keep"].waitForExistence(timeout: 3)); capture("app-form-discard-warning", app)
        app.buttons["wheel.keep"].tap(); confirm(app)
        open(floor, app); XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "12 层")
        capture("app-form-existing-floor-12", app)
        choose("-1 层", app); confirm(app)
        open(floor, app); app.buttons["wheel.clear"].tap(); app.buttons["wheel.close"].tap()
        app.buttons["wheel.discard"].tap()
        XCTAssertEqual(app.buttons["mp.field.wheel.\(floor)"].value as? String, "-1")
        open(floor, app); app.buttons["wheel.clear"].tap(); confirm(app)
        XCTAssertEqual(app.buttons["mp.field.wheel.\(floor)"].value as? String, "未填写")
        open(floor, app); choose("0 层", app); confirm(app)
        search("朝向", app); open("f1_5", app); choose("其他", app); confirm(app)
        let other = app.textFields["mp.field.other.f1_5"]
        XCTAssertTrue(other.isHittable); capture("app-form-other-empty", app)
        other.tap(); other.typeText("SE 15"); app.buttons["checklist.keyboard.done"].tap()
        open("f1_5", app); choose("南", app); confirm(app); XCTAssertFalse(other.exists)
        open("f1_5", app); choose("其他", app); confirm(app)
        XCTAssertEqual(other.value as? String, "SE 15")
        app.terminate(); app.launch()
        let house = app.buttons["house.轮盘正式表单"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertTrue(app.textFields["mp.checklist.search"].waitForExistence(timeout: 3))
        search("朝向", app); XCTAssertEqual(other.value as? String, "SE 15"); capture("app-form-other-restored", app)
        search("楼层", app); XCTAssertEqual(app.buttons["mp.field.wheel.\(floor)"].value as? String, "0")
        capture("app-form-zero-restored", app)
    }
    func testMonthsIssueEditingAndArchiveReadonly() {
        let app = launch(), penalty = "f113_2"
        search("提前退租违约金", app); open(penalty, app); choose("6 个月", app)
        XCTAssertEqual(app.staticTexts["wheel.suffix"].label, "押金"); capture("app-form-fixed-deposit-six", app); confirm(app)
        let closedRow = app.otherElements["mp.field.\(penalty)"]
        XCTAssertTrue((closedRow.value as? String ?? "").hasPrefix("操作已收起"), closedRow.value as? String ?? "")
        capture("app-form-months-confirmed", app)
        open(penalty, app); choose("0.5 个月", app); capture("app-form-fixed-deposit-half", app)
        app.otherElements["wheel.mask"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(app.buttons["wheel.discard"].waitForExistence(timeout: 3)); app.buttons["wheel.discard"].tap()
        XCTAssertEqual(app.buttons["mp.field.wheel.\(penalty)"].value as? String, "6 个月押金")
        open(penalty, app); let height = app.otherElements["wheel.dialog"].frame.height
        app.buttons["wheel.clear"].tap(); XCTAssertEqual(app.otherElements["wheel.dialog"].frame.height, height, accuracy: 1)
        capture("app-form-deposit-empty", app); confirm(app)
        open(penalty, app); choose("0.5 个月", app); confirm(app)
        app.staticTexts["mp.field.title.\(penalty)"].press(forDuration: 0.6)
        let flag = app.buttons["mp.field.action.\(penalty).标记问题"]; XCTAssertTrue(flag.waitForExistence(timeout: 3))
        capture("app-form-field-actions", app); flag.tap()
        app.buttons["tab.问题"].tap(); open(penalty, app); choose("1 个月", app); confirm(app)
        capture("app-issue-wheel-saved", app)
        app.buttons["tab.清单"].tap(); search("租金", app)
        XCTAssertTrue(app.textFields["mp.field.input.f1_6"].exists); XCTAssertFalse(app.buttons["mp.field.wheel.f1_6"].exists)
        capture("app-form-money-manual", app)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.清单"].waitForNonExistence(timeout: 3))
        let house = app.buttons["house.轮盘正式表单"]; XCTAssertTrue(house.waitForExistence(timeout: 3)); house.press(forDuration: 1)
        let archive = app.buttons["归档"]; XCTAssertTrue(archive.waitForExistence(timeout: 3)); archive.tap()
        app.buttons["tab.我的"].tap()
        let archives = app.buttons["settings.archive"]; if !archives.isHittable { app.swipeUp() }; archives.tap()
        let archived = app.buttons["archive.open.轮盘正式表单"]; XCTAssertTrue(archived.waitForExistence(timeout: 3)); archived.tap()
        XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3))
        search("提前退租违约金", app)
        let disabled = app.buttons["mp.field.wheel.\(penalty)"]; XCTAssertTrue(disabled.exists); XCTAssertFalse(disabled.isEnabled)
        XCTAssertEqual(disabled.value as? String, "1 个月押金"); capture("app-form-archive-readonly", app)
    }
}
