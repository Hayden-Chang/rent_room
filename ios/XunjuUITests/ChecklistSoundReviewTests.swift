import XCTest

@MainActor final class ChecklistSoundReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func counts(_ app: XCUIApplication, _ positive: Int, _ problem: Int, file: StaticString = #filePath, line: UInt = #line) {
        let expected = "叮 \(positive) · 嘟嘟 \(problem)"
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: app.staticTexts["sound.counts"])
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed, file: file, line: line)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testRealChoicesAndGroupUndoEmitCorrectSoundWhileSilentActionsStaySilent() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "parity-feedback", "--parity-state", "sound", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.staticTexts["sound.ready"].waitForExistence(timeout: 10))
        counts(app, 0, 0)
        app.buttons["sound.restore"].tap()
        counts(app, 0, 0)
        let yes = app.buttons["mp.field.choice.f77_0.是"]
        XCTAssertTrue(yes.isSelected)
        app.buttons["mp.field.choice.f77_0.否"].tap(); counts(app, 0, 1)
        capture(app, "sound-automatic-problem")
        yes.tap(); counts(app, 1, 1)
        yes.tap(); counts(app, 1, 1)
        XCTAssertFalse(yes.isSelected)
        app.buttons["mp.field.choice.f77_0.不涉及"].tap(); counts(app, 1, 1)

        let parent = "node:group:topic_37"
        app.buttons["mp.field.choice.\(parent).否"].tap(); counts(app, 1, 2)
        let parentYes = app.buttons["mp.field.choice.\(parent).是"]
        parentYes.tap(); counts(app, 2, 2)
        parentYes.tap(); counts(app, 2, 2)
        XCTAssertTrue(app.buttons["mp.field.choice.\(parent).否"].isSelected)
        app.staticTexts["mp.field.title.\(parent)"].tap(); counts(app, 2, 2)
        app.staticTexts["mp.field.title.\(parent)"].tap(); counts(app, 2, 2)

        let none = app.buttons["mp.field.choice.f21_1.无"]
        none.tap(); counts(app, 2, 3)
        none.tap(); counts(app, 2, 3)
        app.buttons["mp.field.choice.f21_1.上午"].tap(); counts(app, 3, 3)
        capture(app, "sound-neutral-choice-and-group-retained")
        app.buttons["sound.readonly"].tap()
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == false"), object: yes)
        XCTAssertEqual(XCTWaiter.wait(for: [disabled], timeout: 3), .completed)
        yes.tap(); counts(app, 3, 3)
        capture(app, "sound-readonly-silent")
    }
}
