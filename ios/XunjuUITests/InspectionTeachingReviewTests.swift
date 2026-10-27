import XCTest

@MainActor final class InspectionTeachingReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testGuardedSwipeTeachingAndRentFreeNumberKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "inspection-teaching", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["coach.next"].exists)
        capture("07-swipe-hand-teaching", app)
        target.tap()
        target.press(forDuration: 0.7)
        target.swipeRight()
        target.swipeUp()
        XCTAssertTrue(target.exists)
        XCTAssertEqual(app.staticTexts["teaching.events"].label, "未选择；操作次数：0")
        target.swipeLeft()
        let next = app.buttons["coach.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        XCTAssertEqual(next.label, "我会啦")
        XCTAssertFalse(target.exists)
        let message = app.staticTexts["xiaoda.message"]
        message.tap()
        capture("08-inline-action-icons", app)
        XCTAssertTrue(message.label.contains("标记问题"))
        next.tap()
        let input = app.textFields["mp.field.input.f5_3"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["mp.field.wheel.f5_3"].exists)
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.keys["a"].exists)
        let numeric = app.keyboards.keys["9"]
        XCTAssertTrue(numeric.exists)
        capture("09-rent-free-number-keyboard", app)
        input.typeText("90")
        app.buttons["teaching.dismissKeyboard"].tap()
        XCTAssertTrue(app.staticTexts["teaching.days"].label.contains("90"))
        XCTAssertTrue(app.staticTexts["teaching.days"].label.contains("原有备注"))
        capture("10-rent-free-input-preserves-note", app)
    }
}
