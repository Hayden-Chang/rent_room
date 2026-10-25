import XCTest

@MainActor final class InspectionBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10)); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 130 && element.frame.minY > 105 { return }
            if element.exists && element.frame.minY < 105 { app.scrollViews.firstMatch.swipeDown() }
            else { app.scrollViews.firstMatch.swipeUp() }
        }
        XCTFail("Control not visible: " + element.identifier)
    }
    private func finishSetup(_ app: XCUIApplication, mode: String) {
        app.buttons["setup.next"].tap()
        let choice = app.buttons["setup.mode." + mode]; XCTAssertTrue(choice.waitForExistence(timeout: 3))
        reveal(choice, app); choice.tap(); app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
    }
    private func addAndLearn(_ app: XCUIApplication, simple: Bool) {
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "第1套"); app.buttons["prompt.confirm"].tap()
        let title = app.staticTexts["coach.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); XCTAssertEqual(title.label, "看房的三个阶段")
        capture("business-01-three-phases", app); app.buttons["coach.next"].tap()
        XCTAssertEqual(title.label, "找到你想看的内容"); capture("business-02-filter-teaching", app)
        app.buttons["coach.next"].tap(); XCTAssertEqual(title.label, "向左滑，试试看")
        XCTAssertFalse(app.buttons["coach.next"].exists)
        let row = app.otherElements["mp.field." + (simple ? "simple_01" : "f56_1")].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3)); XCTAssertTrue(row.isHittable)
        capture("business-03-swipe-teaching", app); row.swipeLeft()
        let step4 = expectation(for: NSPredicate(format: "label == %@", "随手记下房屋细节"), evaluatedWith: title)
        wait(for: [step4], timeout: 4); capture("business-04-swipe-actions", app)
        app.buttons["coach.next"].tap()
        XCTAssertTrue(app.buttons["xiaoda.accept"].waitForExistence(timeout: 4))
        capture("business-05-intro-guidance", app); app.buttons["xiaoda.accept"].tap()
    }
    private func search(_ text: String, _ app: XCUIApplication) {
        let top = app.buttons["回到顶部"]; if top.exists { top.tap() }
        let all = app.buttons["mp.phase.全部"]; reveal(all, app); all.tap()
        let field = app.textFields["mp.checklist.search"]; field.tap()
        if let value = field.value as? String, value != "搜索检查项" && !value.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
        field.typeText(text); app.buttons["checklist.keyboard.done"].tap()
    }
    private func homeAndSkipFeedback(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        let close = app.buttons["关闭反馈"]
        XCTAssertTrue(close.waitForExistence(timeout: 4)); close.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3))
    }
    func testFirstSetupResumeRealSwipeSimpleAnswerFeedbackAndCapacity() {
        let app = launch()
        let toggle = app.buttons["setup.toggle.房源基本信息"]; toggle.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10)); XCTAssertEqual(toggle.label, "恢复房源基本信息")
        toggle.tap(); app.buttons["setup.next"].tap()
        app.terminate(); app.launch()
        let simple = app.buttons["setup.mode.simple"]
        XCTAssertTrue(simple.waitForExistence(timeout: 10)); XCTAssertTrue(simple.isSelected)
        capture("business-00-setup-resumed", app); app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["home.first"].waitForExistence(timeout: 5))
        addAndLearn(app, simple: true); search("生活配套", app)
        let description = app.staticTexts["mp.field.description.simple_02"]; reveal(description, app)
        XCTAssertTrue(description.label.contains("菜市场"))
        let no = app.buttons["mp.field.choice.simple_02.否"]; no.tap(); XCTAssertTrue(no.isSelected)
        let title = app.staticTexts["mp.field.title.simple_02"], left = title.frame.minX
        description.swipeLeft()
        app.buttons["mp.field.action.simple_02.备注"].tap()
        let note = app.textViews["mp.note.text"]; XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap(); note.typeText("附近没有菜市场")
        app.buttons["mp.note.save"].tap()
        XCTAssertTrue(app.buttons["附近没有菜市场"].waitForExistence(timeout: 3)); XCTAssertEqual(title.frame.minX, left, accuracy: 1)
        capture("business-06-simple-description-note", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.第1套"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertFalse(app.buttons["coach.next"].exists); search("生活配套", app)
        XCTAssertTrue(no.isSelected); XCTAssertTrue(app.buttons["附近没有菜市场"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        let ease = app.buttons["feedback.ease.方便"]; XCTAssertTrue(ease.waitForExistence(timeout: 4)); ease.tap()
        capture("business-07-feedback-draft", app); app.terminate(); app.launch()
        XCTAssertTrue(ease.waitForExistence(timeout: 10)); XCTAssertTrue(ease.isSelected)
        app.buttons["关闭反馈"].tap(); app.buttons["home.add"].tap()
        XCTAssertTrue(app.buttons["capacity.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["capacity.continue"].isEnabled)
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "1 / 1 套")
        capture("business-08-capacity-interruption", app)
    }
    func testDetailedNoneTemplateChangesAndArchivedSnapshot() {
        let app = launch(); finishSetup(app, mode: "detailed"); addAndLearn(app, simple: false)
        search("缺少的家具", app)
        let input = app.textFields["mp.field.input.f54_0"]; reveal(input, app); input.tap(); input.typeText("需要衣柜")
        app.buttons["checklist.keyboard.done"].tap()
        let none = app.buttons["mp.field.choice.f54_0.无"]; none.tap()
        XCTAssertTrue(none.isSelected); XCTAssertFalse(input.isEnabled); capture("business-09-missing-furniture-none", app)
        none.tap(); XCTAssertEqual(input.value as? String, "需要衣柜")
        homeAndSkipFeedback(app)
        app.buttons["tab.我的"].tap(); let templates = app.buttons["settings.templates"]; reveal(templates, app); templates.tap()
        XCTAssertTrue(app.buttons["setup.mode.detailed"].isSelected)
        let simple = app.buttons["setup.mode.simple"]; reveal(simple, app); simple.tap()
        app.navigationBars.buttons["返回"].tap()
        XCTAssertTrue(app.buttons["继续编辑"].waitForExistence(timeout: 3)); app.buttons["继续编辑"].tap()
        let edit = app.buttons["templates.edit.simple"]; reveal(edit, app); edit.tap()
        let toggle = app.buttons["setup.toggle.周边与小区"]; XCTAssertTrue(toggle.waitForExistence(timeout: 3)); toggle.tap()
        app.buttons["template.save"].tap(); app.buttons["templates.confirm"].tap()
        app.buttons["tab.房源"].tap(); let old = app.buttons["house.第1套"]; old.press(forDuration: 1)
        app.buttons["归档"].tap(); app.buttons["home.add"].tap()
        XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3)); app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["coach.next"].exists)
        app.buttons["xiaoda.accept"].tap(); search("生活配套", app)
        XCTAssertTrue(app.staticTexts["没有符合条件的检查项"].exists)
        capture("business-10-new-template-disabled-category", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["tab.我的"].tap()
        let archive = app.buttons["settings.archive"]; reveal(archive, app); archive.tap()
        app.buttons["archive.open.第1套"].tap(); search("缺少的家具", app)
        XCTAssertEqual(input.value as? String, "需要衣柜"); XCTAssertFalse(input.isEnabled)
        capture("business-11-old-detailed-snapshot", app)
    }
    func testTemplateEdgeScrollAndCompletionLaterRestoresReadingPosition() {
        let app = launch(), scroll = app.scrollViews.firstMatch
        let first = app.images["setup.drag.房源基本信息"]
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let edge = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.98))
        start.press(forDuration: 0.6, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 2)
        let moved = app.staticTexts["setup.title.房源基本信息"], last = app.staticTexts["setup.title.身份与合同"]
        XCTAssertTrue(last.isHittable); XCTAssertGreaterThan(moved.frame.minY, last.frame.minY)
        capture("business-12-template-edge-scroll", app)
        finishSetup(app, mode: "simple"); addAndLearn(app, simple: true)
        search("室内环境", app)
        for id in ["simple_11", "simple_12", "simple_13"] {
            let yes = app.buttons["mp.field.choice." + id + ".是"]; reveal(yes, app); yes.tap()
        }
        let lastYes = app.buttons["mp.field.choice.simple_49.是"]; reveal(lastYes, app)
        let label = app.staticTexts["mp.field.title.simple_49"], before = label.frame.minY
        lastYes.tap()
        let later = app.buttons["xiaoda.later"]; XCTAssertTrue(later.waitForExistence(timeout: 5))
        capture("business-13-completion-guidance", app); later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 3))
        let position = expectation(for: NSPredicate { _, _ in abs(label.frame.minY - before) < 2 }, evaluatedWith: label)
        wait(for: [position], timeout: 3)
        capture("business-14-later-keeps-position", app)
        lastYes.tap(); lastYes.tap()
        XCTAssertFalse(app.buttons["xiaoda.later"].exists)
    }

}
