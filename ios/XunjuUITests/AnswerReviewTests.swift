import XCTest

@MainActor
final class AnswerReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ surface: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", surface, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testTextNumbersOtherAndMultipleChoices() {
        let app = launch("fields")
        let address = app.textFields["input.f1_1.value"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        XCTAssertEqual(address.value as? String, "朝阳路18号")
        let rent = app.textFields["input.f1_6.value"]
        rent.tap()
        rent.typeText("0")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertTrue(["02800", "28000"].contains(rent.value as? String ?? ""), "Keyboard insertion must preserve the existing digits")
        app.buttons["input.f1_5.choice.其他"].tap()
        let other = app.textFields["input.f1_5.other"]
        XCTAssertTrue(other.exists)
        other.tap(); other.typeText("双面采光")
        app.buttons["完成"].firstMatch.tap()
        app.buttons["input.f83_2.choice.移动"].tap()
        XCTAssertTrue(app.buttons["input.f83_2.choice.移动"].isSelected)
        XCTAssertTrue(app.buttons["input.f83_2.choice.联通"].isSelected)
        capture("08-inputs-other-multiple", app)
        app.buttons["input.f1_5.choice.南"].tap()
        XCTAssertFalse(other.exists)
        app.buttons["input.f1_5.choice.其他"].tap()
        XCTAssertEqual(other.value as? String, "双面采光")
        app.otherElements["input.f1_1"].firstMatch.swipeLeft()
        let note = app.buttons["备注"].firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        capture("09-input-swipe", app)
        note.tap()
        XCTAssertEqual(app.staticTexts["review.answerEvent"].label, "备注")
    }

    func testDecisionCanClearAndNoteKeepsInput() {
        let app = launch("summary")
        let decision = app.buttons["summary.考虑租住"]
        XCTAssertTrue(decision.waitForExistence(timeout: 10))
        decision.tap()
        XCTAssertTrue(decision.isSelected)
        let note = app.textViews["summary.note"]
        note.tap(); note.typeText("采光好，入住时间待确认")
        app.navigationBars.firstMatch.tap()
        capture("10-summary-note", app)
        decision.tap()
        XCTAssertFalse(decision.isSelected)
        XCTAssertEqual(note.value as? String, "采光好，入住时间待确认")
    }
}
