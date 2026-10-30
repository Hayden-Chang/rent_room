import XCTest

@MainActor final class ExampleHousesReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testTwoSimpleExamplesCanBeComparedAndSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "example-houses", "--example-review-id", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.示例·阳光两居"].exists)
        capture("examples-ios-home", app)
        app.buttons["tab.对比"].tap()
        for name in ["示例·地铁一居", "示例·阳光两居"] {
            let card = app.buttons["compare.select.\(name)"]; XCTAssertTrue(card.waitForExistence(timeout: 3)); card.tap()
        }
        capture("examples-ios-selected", app)
        app.buttons["compare.start"].tap()
        let differences = app.switches["隐藏相同属性"]
        XCTAssertTrue(differences.waitForExistence(timeout: 3)); differences.tap()
        XCTAssertTrue(app.otherElements["compare.row.simple_01"].waitForExistence(timeout: 3))
        capture("examples-ios-comparison", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·地铁一居").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·阳光两居").count, 1)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
