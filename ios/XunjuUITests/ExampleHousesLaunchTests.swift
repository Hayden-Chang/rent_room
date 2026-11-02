import XCTest

@MainActor final class ExampleHousesLaunchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testFirstRealHomeNameExcludesExamplesAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.mode.simple"].tap(); app.buttons["setup.next"].tap()
        let decline = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5)); decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.示例·阳光两居"].exists)
        capture("numbering-ios-two-examples", app)
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        capture("numbering-ios-first-real-home", app)
        XCTAssertEqual(name.value as? String, "第1套")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        app.buttons["home.add"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "第1套")
        capture("numbering-ios-first-real-home-reopened", app)
    }
    func testEnglishExamplesShowPhotosAndCompareWithoutChineseSampleText() {
        let app = XCUIApplication(), names = ["Demo · Metro 1BR", "Demo · Sunny 2BR"]
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.mode.simple"].tap(); app.buttons["setup.next"].tap()
        let decline = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5)); decline.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["house." + names[0]].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house." + names[1]].exists)
        XCTAssertTrue(app.staticTexts["My Homes"].exists)
        assertDollarPrices(app, prefix: "house.", names: names)
        XCTAssertTrue(app.buttons["house." + names[1]].label.contains("1 Issue"))
        XCTAssertFalse(app.buttons["house." + names[1]].label.contains("1 Issues"))
        assertEnglishCardsFit(app, prefix: "house.", names: names)
        capture("examples-ios-english-home", app)
        app.buttons["tab.对比"].tap()
        for name in names {
            let card = app.buttons["compare.select." + name]
            XCTAssertTrue(card.waitForExistence(timeout: 3)); card.tap()
        }
        assertEnglishCardsFit(app, prefix: "compare.select.", names: names)
        assertDollarPrices(app, prefix: "compare.select.", names: names)
        capture("examples-ios-english-selected", app)
        app.buttons["compare.start"].tap()
        let differences = app.switches["Hide identical attributes"]
        XCTAssertTrue(differences.waitForExistence(timeout: 3))
        differences.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let enabled = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: differences)
        wait(for: [enabled], timeout: 3)
        XCTAssertTrue(app.otherElements["compare.row.simple_01"].waitForExistence(timeout: 3))
        let rent = app.otherElements["compare.row.f1_6"]
        XCTAssertTrue(rent.staticTexts["USD 1500"].exists)
        XCTAssertTrue(rent.staticTexts["USD 1900"].exists)
        capture("examples-ios-english-comparison", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house." + names[0]].waitForExistence(timeout: 10))
        for name in names { XCTAssertEqual(app.buttons.matching(identifier: "house." + name).count, 1) }
        assertDollarPrices(app, prefix: "house.", names: names)
    }
    private func assertDollarPrices(_ app: XCUIApplication, prefix: String, names: [String]) {
        for (name, amount) in zip(names, ["1500", "1900"]) {
            let label = app.buttons[prefix + name].label
            XCTAssertTrue(label.contains("USD " + amount))
            XCTAssertFalse(label.contains("CNY"))
        }
    }
    private func assertEnglishCardsFit(_ app: XCUIApplication, prefix: String, names: [String]) {
        let left = app.buttons[prefix + names[0]], right = app.buttons[prefix + names[1]]
        XCTAssertGreaterThanOrEqual(right.frame.minX - left.frame.maxX, 9)
        XCTAssertGreaterThanOrEqual(left.frame.minX, app.frame.minX + 15)
        XCTAssertLessThanOrEqual(right.frame.maxX, app.frame.maxX - 15)
        for card in [left, right] { XCTAssertNil(card.label.range(of: #"[\u3400-\u9fff]"#, options: .regularExpression)) }
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
