import XCTest

@MainActor final class ChecklistHapticsBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testChecklistHasNoSoundControlAndChoicesPersistAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--returning-business-fixture",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10)); currency.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 5))
        app.buttons["home.add"].tap()
        let input = app.textFields["prompt.text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3)); input.replacePromptText("静音清单验收")
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["checklist.sound.toggle"].exists)
        capture("haptics-business-header", app)
        search(app)
        let no = app.buttons["mp.field.choice.f77_0.否"]
        XCTAssertTrue(no.waitForExistence(timeout: 3)); XCTAssertTrue(no.isHittable)
        no.tap(); selected(true, no)
        no.tap(); selected(false, no)
        no.tap(); selected(true, no)
        app.terminate(); app.launch()
        let house = app.buttons["house.静音清单验收"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["checklist.sound.toggle"].exists)
        search(app)
        XCTAssertTrue(no.waitForExistence(timeout: 3)); XCTAssertTrue(no.isSelected)
        capture("haptics-business-answer-restored", app)
    }

    private func search(_ app: XCUIApplication) {
        let search = app.textFields["mp.checklist.search"]
        search.tap(); search.typeText("冬季水管"); app.buttons["checklist.keyboard.done"].tap()
    }
    private func selected(_ expected: Bool, _ choice: XCUIElement) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == %@", NSNumber(value: expected)), object: choice)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
