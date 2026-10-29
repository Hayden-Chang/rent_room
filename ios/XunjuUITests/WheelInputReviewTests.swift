import XCTest

@MainActor
final class WheelInputReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let period = "f5_3"
    private func launch(legacy: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "wheels", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if legacy { app.launchArguments.append("--wheel-review-legacy") }
        app.launch()
        XCTAssertTrue(app.buttons["wheel.open.\(period)"].waitForExistence(timeout: 10))
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
    private func choose(_ label: String, _ app: XCUIApplication) {
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 3))
        wheel.adjust(toPickerWheelValue: label)
        let settled = expectation(for: NSPredicate(format: "value == %@", label), evaluatedWith: wheel)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 3), .completed)
    }
    private func closed(_ app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForNonExistence(timeout: 3))
    }

    func testDraftConfirmClearAndDiscard() {
        let app = launch()
        capture("01-wheel-fields", app)
        open(period, app)
        let dialog = app.otherElements["wheel.dialog"]
        XCTAssertEqual(dialog.frame.midY, app.frame.midY, accuracy: 45)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "12 天")
        XCTAssertFalse(app.staticTexts["滑动选择"].exists)
        choose("5 天", app); capture("02-floor-basement", app)
        app.buttons["wheel.close"].tap()
        XCTAssertTrue(app.buttons["wheel.keep"].waitForExistence(timeout: 3))
        capture("03-discard-warning", app)
        app.buttons["wheel.keep"].tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "5 天")
        app.buttons["wheel.close"].tap(); app.buttons["wheel.discard"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(period)"].value as? String, "12")
        open(period, app); choose("5 天", app); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(period)"].value as? String, "5")
        open(period, app); app.buttons["wheel.clear"].tap(); capture("04-cleared-draft", app)
        app.buttons["wheel.close"].tap(); app.buttons["wheel.keep"].tap(); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(period)"].value as? String, "未填写")
        open(period, app); choose("0 天", app); app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.\(period)"].value as? String, "0")
        open(period, app); choose("1 天", app); choose("0 天", app); app.buttons["wheel.close"].tap(); closed(app)
        open(period, app); choose("1 天", app)
        let selected = expectation(for: NSPredicate(format: "value == %@", "1 天"), evaluatedWith: app.pickerWheels.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        capture("05-before-outside-cancel", app)
        app.otherElements["wheel.mask"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        XCTAssertTrue(app.buttons["wheel.discard"].waitForExistence(timeout: 3))
        capture("06-outside-cancel-warning", app)
        app.buttons["wheel.discard"].tap(); closed(app)
        capture("05-saved-zero", app)
    }

    func testAllNineRulesAndManualExceptions() {
        let app = launch()
        let samples = [(period, "60 天"), ("f88_1", "6 个月"), ("f88_2", "12 个月"),
            ("f105_0", "60 天"), ("f112_2", "60 天"), ("f113_1", "60 天"), ("f116_1", "当天"),
            ("f112_5", "0.5 个月"), ("f113_2", "6 个月")]
        for (index, sample) in samples.enumerated() {
            open(sample.0, app); choose(sample.1, app)
            XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, sample.1)
            capture(String(format: "rule-%02d-%@", index + 1, sample.0), app)
            app.buttons["wheel.confirm"].tap(); closed(app)
        }
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.textFields["wheel.manual.money"].exists)
        XCTAssertTrue(app.textFields["wheel.manual.speed"].exists)
        capture("06-manual-money-and-speed", app)
    }

    func testExistingValuesAndFixedSuffix() {
        let app = launch(legacy: true)
        open(period, app)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "220 天")
        XCTAssertFalse(app.staticTexts["滑动选择"].exists)
        capture("v2-existing-period-220", app)
        app.buttons["wheel.close"].tap(); closed(app)
        open("f113_2", app); choose("6 个月", app)
        let suffix = app.staticTexts["wheel.suffix"]
        XCTAssertTrue(suffix.exists); XCTAssertEqual(suffix.label, "押金")
        let fixedPosition = suffix.frame
        capture("v2-fixed-deposit-6", app)
        choose("0.5 个月", app)
        XCTAssertEqual(suffix.frame.midY, fixedPosition.midY, accuracy: 0.5)
        XCTAssertEqual(suffix.frame.minX, fixedPosition.minX, accuracy: 0.5)
        capture("v2-fixed-deposit-half", app)
        app.buttons["wheel.confirm"].tap(); closed(app)
        XCTAssertEqual(app.buttons["wheel.open.f113_2"].value as? String, "0.5 个月押金")
        open("f113_2", app)
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "0.5 个月")
        let selectedHeight = app.otherElements["wheel.dialog"].frame.height
        app.buttons["wheel.clear"].tap()
        XCTAssertEqual(app.pickerWheels.firstMatch.value as? String, "未填写")
        XCTAssertFalse(suffix.exists)
        XCTAssertEqual(app.otherElements["wheel.dialog"].frame.height, selectedHeight, accuracy: 1)
        XCTAssertEqual(app.buttons["wheel.clear"].frame.midY, app.buttons["wheel.confirm"].frame.midY, accuracy: 1)
        capture("v2-deposit-empty", app)
        app.buttons["wheel.confirm"].tap(); closed(app)
    }
}
