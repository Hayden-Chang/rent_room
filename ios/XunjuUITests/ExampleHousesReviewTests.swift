import XCTest

@MainActor final class ExampleHousesReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testEnglishExamplesShowPhotosAndCompareWithoutChineseSampleText() {
        let app = XCUIApplication(), names = ["Demo · Metro 1BR", "Demo · Sunny 2BR"]
        app.launchArguments = ["--component-review", "example-houses", "--example-review-id", UUID().uuidString, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["house." + names[0]].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house." + names[1]].exists)
        XCTAssertTrue(app.staticTexts["My Homes"].exists)
        assertEnglishCardsFit(app, prefix: "house.", names: names)
        capture("examples-ios-english-home", app)
        app.buttons["tab.对比"].tap()
        for name in names {
            let card = app.buttons["compare.select." + name]
            XCTAssertTrue(card.waitForExistence(timeout: 3)); card.tap()
        }
        assertEnglishCardsFit(app, prefix: "compare.select.", names: names)
        capture("examples-ios-english-selected", app)
        app.buttons["compare.start"].tap()
        let differences = app.switches["Hide identical attributes"]
        XCTAssertTrue(differences.waitForExistence(timeout: 3))
        differences.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let enabled = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: differences)
        wait(for: [enabled], timeout: 3)
        XCTAssertTrue(app.otherElements["compare.row.simple_01"].waitForExistence(timeout: 3))
        capture("examples-ios-english-comparison", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house." + names[0]].waitForExistence(timeout: 10))
        for name in names { XCTAssertEqual(app.buttons.matching(identifier: "house." + name).count, 1) }
    }
    private func assertEnglishCardsFit(_ app: XCUIApplication, prefix: String, names: [String]) {
        let left = app.buttons[prefix + names[0]], right = app.buttons[prefix + names[1]]
        XCTAssertGreaterThanOrEqual(right.frame.minX - left.frame.maxX, 9)
        XCTAssertGreaterThanOrEqual(left.frame.minX, app.frame.minX + 15)
        XCTAssertLessThanOrEqual(right.frame.maxX, app.frame.maxX - 15)
        for card in [left, right] { XCTAssertNil(card.label.range(of: #"[\u3400-\u9fff]"#, options: .regularExpression)) }
    }
    func testTwoSimpleExamplesCanBeComparedAndSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "example-houses", "--example-review-id", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.示例·阳光两居"].exists)
        capture("examples-ios-home", app)
        assertCardsFit(app, prefix: "house.")
        app.buttons["tab.对比"].tap()
        for name in ["示例·地铁一居", "示例·阳光两居"] {
            let card = app.buttons["compare.select.\(name)"]; XCTAssertTrue(card.waitForExistence(timeout: 3)); card.tap()
        }
        capture("examples-ios-selected", app)
        assertCardsFit(app, prefix: "compare.select.")
        app.buttons["compare.start"].tap()
        let differences = app.switches["隐藏相同属性"]
        XCTAssertTrue(differences.waitForExistence(timeout: 3))
        // The custom switch's accessibility frame includes its label; hit its visible thumb.
        differences.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let enabled = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: differences)
        wait(for: [enabled], timeout: 3)
        XCTAssertTrue(app.otherElements["compare.row.simple_01"].waitForExistence(timeout: 3))
        capture("examples-ios-comparison", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·地铁一居").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·阳光两居").count, 1)
    }
    private func assertCardsFit(_ app: XCUIApplication, prefix: String) {
        let left = app.buttons[prefix + "示例·地铁一居"].frame
        let right = app.buttons[prefix + "示例·阳光两居"].frame
        XCTAssertGreaterThanOrEqual(right.minX - left.maxX, 9, "照片不能撑宽卡片或挤掉两列间距")
        XCTAssertGreaterThanOrEqual(left.minX, app.frame.minX + 15)
        XCTAssertLessThanOrEqual(right.maxX, app.frame.maxX - 15)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
