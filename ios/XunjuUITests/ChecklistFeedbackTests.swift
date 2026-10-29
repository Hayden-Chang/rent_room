import XCTest

@MainActor final class ChecklistFeedbackTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "parity-feedback", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.staticTexts["feedback.counts"].waitForExistence(timeout: 8))
        counts(app, selection: 0, disclosure: 0)
        return app
    }

    private func counts(_ app: XCUIApplication, selection: Int, disclosure: Int, file: StaticString = #filePath, line: UInt = #line) {
        let expected = "选择 \(selection) · 展开折叠 \(disclosure)"
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: app.staticTexts["feedback.counts"])
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed, file: file, line: line)
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testChoicesAndManualDisclosureEmitOnceAndPreserveAnswers() {
        let app = launch()
        capture(app, "haptics-initial")
        let parent = app.staticTexts["mp.field.title.parent"]
        let yes = app.buttons["mp.field.choice.single.是"]
        let no = app.buttons["mp.field.choice.single.否"]

        // Choosing a collapsed parent also expands it, but emits only one selection.
        app.buttons["mp.field.choice.parent.有"].tap()
        counts(app, selection: 1, disclosure: 0)
        XCTAssertTrue(yes.isHittable)
        yes.tap(); counts(app, selection: 2, disclosure: 0)
        XCTAssertTrue(yes.isSelected)
        no.tap(); counts(app, selection: 3, disclosure: 0)
        XCTAssertTrue(no.isSelected); XCTAssertFalse(yes.isSelected)
        no.tap(); counts(app, selection: 4, disclosure: 0)
        XCTAssertFalse(no.isSelected)
        yes.tap(); counts(app, selection: 5, disclosure: 0)
        capture(app, "haptics-selected")

        parent.tap(); counts(app, selection: 5, disclosure: 1)
        XCTAssertFalse(yes.exists)
        capture(app, "haptics-collapsed")
        parent.tap(); counts(app, selection: 5, disclosure: 2)
        XCTAssertTrue(yes.isSelected)
        XCTAssertTrue(app.buttons["保留备注"].exists)

        let skip = app.buttons["mp.field.choice.parent.不涉及"]
        skip.tap(); counts(app, selection: 6, disclosure: 2)
        XCTAssertTrue(skip.isSelected); XCTAssertFalse(yes.exists)
        skip.tap(); counts(app, selection: 7, disclosure: 2)
        XCTAssertTrue(yes.isSelected)
        let first = app.buttons["mp.field.choice.multiple.联通"]
        let second = app.buttons["mp.field.choice.multiple.移动"]
        first.tap(); counts(app, selection: 8, disclosure: 2)
        second.tap(); counts(app, selection: 9, disclosure: 2)
        XCTAssertTrue(first.isSelected); XCTAssertTrue(second.isSelected)
        first.tap(); counts(app, selection: 10, disclosure: 2)
        XCTAssertFalse(first.isSelected); XCTAssertTrue(second.isSelected)
        let none = app.buttons["mp.field.choice.cost.无"]
        none.tap(); counts(app, selection: 11, disclosure: 2)
        XCTAssertTrue(none.isSelected)
        none.tap(); counts(app, selection: 12, disclosure: 2)
        XCTAssertFalse(none.isSelected)
        XCTAssertEqual(app.textFields["mp.field.input.cost"].value as? String, "3200")
        capture(app, "haptics-choices-retained")
    }

    func testConsumedDisabledAndProgrammaticChangesStaySilent() {
        let app = launch()
        app.buttons["feedback.restore"].tap()
        counts(app, selection: 0, disclosure: 0)
        let yes = app.buttons["mp.field.choice.single.是"]
        XCTAssertTrue(yes.isSelected)
        app.staticTexts["mp.field.title.fixed"].tap()
        counts(app, selection: 0, disclosure: 0)

        yes.swipeLeft()
        let issue = app.buttons["mp.field.action.single.取消问题"]
        XCTAssertTrue(issue.waitForExistence(timeout: 3), "Existing problem flag must be retained")
        // The first tap on another row only closes the tray.
        let choice = app.buttons["mp.field.choice.multiple.联通"]
        choice.tap()
        XCTAssertFalse(issue.exists); XCTAssertFalse(choice.isSelected)
        counts(app, selection: 0, disclosure: 0)
        yes.swipeLeft()
        XCTAssertTrue(issue.waitForExistence(timeout: 3))
        let parent = app.staticTexts["mp.field.title.parent"]
        parent.tap()
        XCTAssertFalse(issue.exists); XCTAssertTrue(yes.exists)
        counts(app, selection: 0, disclosure: 0)

        app.buttons["feedback.readonly"].tap()
        XCTAssertFalse(choice.isEnabled)
        choice.tap()
        XCTAssertFalse(choice.isSelected)
        counts(app, selection: 0, disclosure: 0)
        parent.tap(); counts(app, selection: 0, disclosure: 1)
        XCTAssertFalse(yes.exists)
        parent.tap(); counts(app, selection: 0, disclosure: 2)
        XCTAssertTrue(yes.isSelected); XCTAssertFalse(yes.isEnabled)
        XCTAssertTrue(app.buttons["保留备注"].exists)
        capture(app, "haptics-readonly-disclosure")
    }
}
