import XCTest

@MainActor
final class LaunchIntegrationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func application(returning: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if returning { app.launchArguments += ["--returning-business-fixture", "--pixel-parity-fixture", "--stub-system-review"] }
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func chooseDefaultCurrency(_ app: XCUIApplication) {
        let decline = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5))
        decline.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 5))
    }

    func testFirstLaunchReachesSetupAndRelaunchRetainsChoice() {
        let app = application()
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-first-setup", app)
        let toggle = app.buttons["setup.toggle.房源基本信息"]
        toggle.tap()

        app.terminate()
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "恢复房源基本信息")
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-setup-choice-restored", app)
        toggle.tap()
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.next"].tap()
        chooseDefaultCurrency(app)
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["house.示例·阳光两居"].exists)
        assertExampleCardsFit(app, prefix: "house.")
        assertYuanPrices(app, prefix: "house.")
        capture("launch-setup-completed-home", app)
        app.buttons["tab.对比"].tap()
        for name in ["示例·地铁一居", "示例·阳光两居"] {
            let card = app.buttons["compare.select." + name]
            XCTAssertTrue(card.waitForExistence(timeout: 3)); card.tap()
        }
        assertExampleCardsFit(app, prefix: "compare.select.")
        assertYuanPrices(app, prefix: "compare.select.")
        capture("launch-examples-selected", app)
        app.buttons["compare.start"].tap()
        let differences = app.switches["隐藏相同属性"]
        XCTAssertTrue(differences.waitForExistence(timeout: 3))
        differences.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let enabled = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: differences)
        wait(for: [enabled], timeout: 3)
        XCTAssertTrue(app.otherElements["compare.row.simple_01"].waitForExistence(timeout: 3))
        let rent = app.otherElements["compare.row.f1_6"]
        XCTAssertTrue(rent.staticTexts["2800 元"].exists)
        XCTAssertTrue(rent.staticTexts["3600 元"].exists)
        capture("launch-examples-comparison", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.示例·地铁一居"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·地铁一居").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "house.示例·阳光两居").count, 1)
        assertYuanPrices(app, prefix: "house.")
        XCTAssertFalse(app.buttons["setup.next"].exists)
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
    }

    private func assertExampleCardsFit(_ app: XCUIApplication, prefix: String) {
        let left = app.buttons[prefix + "示例·地铁一居"].frame
        let right = app.buttons[prefix + "示例·阳光两居"].frame
        XCTAssertGreaterThanOrEqual(right.minX - left.maxX, 9)
        XCTAssertGreaterThanOrEqual(left.minX, app.frame.minX + 15)
        XCTAssertLessThanOrEqual(right.maxX, app.frame.maxX - 15)
    }
    private func assertYuanPrices(_ app: XCUIApplication, prefix: String) {
        for (name, amount) in zip(["示例·地铁一居", "示例·阳光两居"], ["2800", "3600"]) {
            let label = app.buttons[prefix + name].label
            XCTAssertTrue(label.contains(amount + " 元/月"))
            XCTAssertFalse(label.contains("CNY"))
        }
    }

    func testReturningLaunchRestoresHomesAndResumeKeepsCurrentPage() {
        let app = application(returning: true)
        app.launch()
        chooseDefaultCurrency(app)
        XCTAssertTrue(app.buttons["house.阳光小区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.新城公寓"].exists)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        XCTAssertFalse(app.buttons["house.示例·地铁一居"].exists)
        XCTAssertFalse(app.buttons["house.示例·阳光两居"].exists)
        capture("launch-returning-home", app)

        app.buttons["tab.我的"].tap()
        XCTAssertTrue(app.buttons["local-settings.capacity"].waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.buttons["local-settings.capacity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.我的"].isSelected)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-background-resume-settings", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["house.阳光小区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.新城公寓"].exists)
        XCTAssertFalse(app.staticTexts["currency.prompt.title"].exists)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        XCTAssertFalse(app.buttons["house.示例·地铁一居"].exists)
        XCTAssertFalse(app.buttons["house.示例·阳光两居"].exists)
        capture("launch-returning-home-restored", app)
    }
}
