import XCTest

@MainActor final class SpeedBusinessTests: XCTestCase {
    private let field = "d244dc92-351e-4f3c-8738-45295fec9ff9"
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--speed-measurement-fixture", mode, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); return app
    }
    private func addHouse(_ name: String, _ app: XCUIApplication) {
        app.buttons["home.add"].tap(); let text = app.textFields["prompt.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3)); text.tap(); text.typeText(name); app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["coach.actions"].waitForExistence(timeout: 3))
        app.buttons["coach.preference"].tap(); next.tap(); XCTAssertFalse(next.exists)
        searchSpeed(app)
        let input = app.textFields["input.\(field).value"]; input.tap(); input.typeText("10")
        app.buttons["checklist.keyboard.done"].tap(); XCTAssertEqual(input.value as? String, "10")
    }
    private func searchSpeed(_ app: XCUIApplication) {
        let search = app.textFields["checklist.search"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("实测网速")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.buttons["measurement.\(field)"].waitForExistence(timeout: 3))
    }
    private func wifi(_ app: XCUIApplication) -> XCUIElement {
        let alert = app.alerts["是否已连接 WiFi"]; XCTAssertTrue(alert.waitForExistence(timeout: 5)); return alert
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testMobileConsentAutofillsAndPersistsAfterRelaunch() {
        let app = launch("mobile"); addHouse("网速回填", app)
        app.buttons["measurement.\(field)"].tap(); wifi(app).buttons["是"].tap()
        let mobile = app.alerts["使用当前网络测速？"]; XCTAssertTrue(mobile.waitForExistence(timeout: 3))
        capture("43-business-mobile-speed-consent", app); mobile.buttons["开始测速"].tap()
        let answer = app.textFields["input.\(field).value"]; XCTAssertTrue(answer.waitForExistence(timeout: 10))
        XCTAssertEqual(answer.value as? String, "8.39"); capture("44-business-speed-autofilled", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.网速回填"].waitForExistence(timeout: 10))
        app.buttons["house.网速回填"].tap(); searchSpeed(app); XCTAssertEqual(answer.value as? String, "8.39")
    }
    func testDeclineAndCancelMeasurementKeepManualValue() {
        let app = launch("slow"); addHouse("测速取消", app)
        let answer = app.textFields["input.\(field).value"]
        app.buttons["measurement.\(field)"].tap(); wifi(app).buttons["否"].tap()
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); XCTAssertEqual(answer.value as? String, "10")
        app.buttons["measurement.\(field)"].tap(); wifi(app).buttons["是"].tap()
        let cancel = app.buttons["speed.action"]; XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertFalse(app.alerts["是否已连接 WiFi"].exists); XCTAssertEqual(cancel.label, "取消")
        capture("46-business-speed-cancellable", app); cancel.tap()
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); XCTAssertEqual(answer.value as? String, "10")
        app.buttons["measurement.\(field)"].tap(); _ = wifi(app)
        XCUIDevice.shared.press(.home); app.activate()
        let message = app.staticTexts["speed.message"]; XCTAssertTrue(message.waitForExistence(timeout: 5))
        XCTAssertEqual(message.label, "测速已取消，原值保持不变")
        XCTAssertFalse(app.alerts["是否已连接 WiFi"].exists)
        XCTAssertEqual(cancel.label, "重新测速"); capture("47-business-speed-background-cancelled", app)
        cancel.tap(); wifi(app).buttons["否"].tap()
        XCTAssertTrue(answer.waitForExistence(timeout: 5)); XCTAssertEqual(answer.value as? String, "10")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.测速取消"].waitForExistence(timeout: 10))
        app.buttons["house.测速取消"].tap(); searchSpeed(app); XCTAssertEqual(answer.value as? String, "10")
    }
}
