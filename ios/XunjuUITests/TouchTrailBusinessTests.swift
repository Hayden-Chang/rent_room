import XCTest

@MainActor
final class TouchTrailBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "--pixel-parity-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 {
            if element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }

    private func footer(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["tab.我的"].tap()
        let toggle = app.switches["settings.touch-trails"]
        reveal(toggle, in: app)
        return toggle
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.isHittable)
        // The existing MPSwitchStyle's 51pt button is at the row's trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25.5, dy: 0)).tap()
    }

    private func enable(_ app: XCUIApplication) {
        let toggle = footer(app)
        XCTAssertEqual(toggle.value as? String, "0")
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testSettingsFooterDefaultsOffAndPersistsBothChoices() {
        let app = launch()
        let toggle = footer(app)
        XCTAssertEqual(toggle.value as? String, "0")
        reveal(app.staticTexts["版本"], in: app)
        XCTAssertLessThan(toggle.frame.maxY, app.staticTexts["版本"].frame.minY)
        capture("touch-trails-business-01-footer-off")
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        capture("touch-trails-business-02-footer-on")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        XCTAssertEqual(footer(app).value as? String, "1")
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        XCTAssertEqual(footer(app).value as? String, "0")
    }

    func testEnabledTrailsPreserveChecklistGesturesAndSavedNote() {
        let app = launch()
        enable(app)
        app.buttons["tab.房源"].tap()
        app.buttons["house.阳光小区"].tap()
        let search = app.textFields["mp.checklist.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("纱窗")
        app.buttons["checklist.keyboard.done"].tap()
        let yes = app.buttons["mp.field.choice.f38_result.是"]
        reveal(yes, in: app)
        if !yes.isSelected { yes.tap() }
        XCTAssertTrue(yes.isSelected)
        let row = app.otherElements["mp.field.f38_result"].firstMatch
        row.swipeLeft()
        capture("touch-trails-business-03-checklist-swipe")
        let note = app.buttons["mp.field.action.f38_result.备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        row.swipeRight()
        XCTAssertTrue(yes.isHittable)
        row.press(forDuration: 0.6)
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        let editor = app.textViews["mp.note.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 3))
        editor.tap(); editor.typeText("触摸轨迹验收备注")
        app.buttons["mp.note.save"].tap()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["触摸轨迹验收备注"].isHittable)
        XCTAssertTrue(yes.isSelected)
        capture("touch-trails-business-04-note-saved")
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["house.阳光小区"].waitForExistence(timeout: 3))
        app.terminate(); app.launch()
        let house = app.buttons["house.阳光小区"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap(); search.typeText("纱窗"); app.buttons["checklist.keyboard.done"].tap()
        reveal(yes, in: app)
        XCTAssertTrue(yes.isSelected)
        XCTAssertTrue(app.buttons["触摸轨迹验收备注"].exists)
    }

    func testEnabledTrailsPreserveFeedbackFullScreenAndNavigation() {
        let app = launch()
        enable(app)
        let feedback = app.buttons["settings.feedback"]
        XCTAssertTrue(feedback.isHittable); feedback.tap()
        let choice = app.buttons["feedback.ease.方便"]
        XCTAssertTrue(choice.waitForExistence(timeout: 3)); choice.tap()
        capture("touch-trails-business-05-feedback-touch")
        XCTAssertTrue(choice.isSelected)
        app.buttons["关闭反馈"].tap()
        XCTAssertTrue(choice.waitForNonExistence(timeout: 3))
        XCTAssertTrue(feedback.isHittable)
        XCTAssertEqual(app.switches["settings.touch-trails"].value as? String, "1")
        app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.buttons["house.阳光小区"].isHittable)
    }
}
