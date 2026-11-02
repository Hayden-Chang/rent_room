import XCTest

@MainActor
final class OutsideInputReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "outside-input", "--input-review-id", UUID().uuidString,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.textFields["mp.field.input.rent"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testOutsideTitleButtonAndFocusTransferRetainValuesAfterRelaunch() {
        let app = launch()
        let rent = app.textFields["mp.field.input.rent"]
        let furniture = app.textFields["mp.field.input.furniture"]
        rent.tap(); rent.typeText("2800")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        capture("outside-01-editing-rent", app)
        app.staticTexts["outside.title"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(rent.value as? String, "2800")
        capture("outside-02-title-saved", app)
        furniture.tap(); furniture.typeText("desk")
        furniture.tap(); furniture.typeText(" chair")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Editing inside the field must retain its keyboard")
        rent.tap(); rent.typeText("0")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Switching inputs keeps the new input active")
        let savedRent = rent.value as? String
        XCTAssertEqual(savedRent?.sorted(), "28000".sorted(), "Typing after focus transfer must update the newly selected field")
        app.buttons["outside.action"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.buttons["outside.action"].label, "标记关注（1）", "One tap must also execute the target button")
        capture("outside-03-button-and-saved", app)
        let savedFurniture = furniture.value as? String
        app.terminate(); app.launch()
        XCTAssertTrue(rent.waitForExistence(timeout: 10))
        XCTAssertEqual(rent.value as? String, savedRent)
        XCTAssertEqual(furniture.value as? String, savedFurniture)
        capture("outside-04-reopened", app)
    }
    func testOtherTextMultilineAndDoneKeepContent() {
        let app = launch()
        let other = app.textFields["mp.field.other.other"]
        other.tap(); other.typeText("south east")
        app.buttons["outside.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(other.value as? String, "south east")
        let note = app.textViews["summary.note"]
        note.tap(); note.typeText("quiet\nbright")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.navigationBars.firstMatch.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(note.value as? String, "quiet\nbright")
        capture("outside-05-multiline-saved", app)
        app.terminate(); app.launch()
        XCTAssertTrue(other.waitForExistence(timeout: 10))
        XCTAssertEqual(other.value as? String, "south east")
        XCTAssertEqual(note.value as? String, "quiet\nbright")
    }
}
