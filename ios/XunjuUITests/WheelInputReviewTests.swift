import XCTest

@MainActor
final class WheelInputReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let floor = "fc76beec-52e3-4fe9-a937-dec254d4cc4f"
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "wheels", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["wheel.open.\(floor)"].waitForExistence(timeout: 10))
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func open(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons["wheel.open.\(id)"]
        for _ in 0..<5 where !button.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(button.isHittable); button.tap()
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForExistence(timeout: 3))
    }
    private func choose(_ label: String, _ app: XCUIApplication) { app.pickerWheels.firstMatch.adjust(toPickerWheelValue: label) }
    private func closed(_ app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForNonExistence(timeout: 3))
    }

    func testDraftConfirmClearAndDiscard() {
        let app = launch()
        capture("01-wheel-fields", app)
        open(floor, app)
        let dialog = app.otherElements["wheel.dialog"]
        XCTAssertEqual(dialog.frame.midY, app.frame.midY, accuracy: 45)
        choose("-1 层", app); capture("02-floor-basement", app)
        app.buttons["wheel.close"].tap()
        XCTAssertTrue(app.buttons["wheel.keep"].waitForExistence(timeout: 3))
        capture("03-discard-warning", app)
        app.buttons["wheel.keep"].tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "-1 层")
        app.buttons["wheel.close"].tap(); app.buttons["wheel.discard"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(floor)"].value as? String, "12")
        open(floor, app); choose("-1 层", app); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(floor)"].value as? String, "-1")
        open(floor, app); app.buttons["wheel.clear"].tap(); capture("04-cleared-draft", app)
        app.buttons["wheel.close"].tap(); app.buttons["wheel.keep"].tap(); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(floor)"].value as? String, "未填写")
        open(floor, app); choose("0 层", app); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(floor)"].value as? String, "0")
        open(floor, app); choose("1 层", app); choose("0 层", app); app.buttons["wheel.close"].tap(); closed(app)
        open(floor, app); choose("1 层", app)
        let selected = expectation(for: NSPredicate(format: "value == %@", "1 层"), evaluatedWith: app.pickerWheels.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        capture("05-before-outside-cancel", app)
        app.otherElements["wheel.mask"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(app.buttons["wheel.discard"].waitForExistence(timeout: 3))
        capture("06-outside-cancel-warning", app)
        app.buttons["wheel.discard"].tap(); closed(app)
        capture("05-saved-zero", app)
    }

    func testAllSeventeenRulesAndManualExceptions() {
        let app = launch()
        let samples = [(floor, "50 层"), ("f1_3", "200 ㎡"), ("f1_5", "其他"), ("f5_3", "60 天"),
            ("21255282-3663-4abe-b7de-d91eeb3825ed", "120 分钟"), ("3c70cda2-7c6c-4fa6-b2db-b647af24ba72", "120 分钟"),
            ("f41_3", "0.5 米"), ("f88_1", "6 个月"), ("f88_2", "12 个月"), ("f44_1", "210 cm"), ("f44_0", "135 cm"),
            ("f105_0", "60 天"), ("f112_2", "60 天"), ("f113_1", "60 天"), ("f116_1", "当天"),
            ("f112_5", "0.5 个月押金"), ("f113_2", "6 个月押金")]
        for (index, sample) in samples.enumerated() {
            open(sample.0, app); choose(sample.1, app)
            XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, sample.1)
            capture(String(format: "rule-%02d-%@", index + 1, sample.0), app)
            app.buttons["wheel.confirm"].tap(); closed(app)
        }
        XCTAssertTrue(app.textFields["wheel.other"].exists)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.textFields["wheel.manual.money"].exists)
        XCTAssertTrue(app.textFields["wheel.manual.speed"].exists)
        capture("06-manual-money-and-speed", app)
    }
}
