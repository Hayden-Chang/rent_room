import XCTest

@MainActor final class ExampleHousesLaunchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testFirstHomeWaitDismissesReminderAndKeepsCreationAndTeachingAvailable() {
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
        let later = app.buttons["再等等"], message = app.otherElements["xiaoda.message"].firstMatch
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "点这里，新建你的第一套房源吧！")
        let typed = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message)
        wait(for: [typed], timeout: 4)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'house.'")).count, 2)
        capture("first-home-wait-01-before", app)
        later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 3))
        XCTAssertFalse(message.exists)
        XCTAssertTrue(app.buttons["home.add"].isHittable)
        capture("first-home-wait-02-dismissed", app)
        app.buttons["tab.我的"].tap(); app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3))
        XCTAssertFalse(later.exists)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        XCTAssertFalse(later.exists)
        XCTAssertFalse(message.exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'house.'")).count, 2)
        capture("first-home-wait-03-reopened", app)
        app.buttons["home.add"].tap()
        XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3))
        capture("first-home-wait-04-create-available", app)
        app.buttons["prompt.confirm"].tap()
        let title = app.staticTexts["coach.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "看房的三个阶段")
        capture("first-home-wait-05-teaching-preserved", app)
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
