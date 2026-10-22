import XCTest

@MainActor final class ElevatorRatioUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testRatioChoicesAutomaticIssueAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("电梯住户比验收")
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }; app.buttons["coach.preference"].tap(); next.tap()
        let search = app.textFields["mp.checklist.search"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("电梯住户比")
        app.buttons["checklist.keyboard.done"].tap()
        let group = app.buttons["mp.field.choice.node:group:topic_16.是"]
        XCTAssertTrue(group.waitForExistence(timeout: 3)); group.tap()
        let low = app.buttons["mp.field.choice.f16_0.≤ 1:3（优质）"], middle = app.buttons["mp.field.choice.f16_0.1:4（高峰等待）"], high = app.buttons["mp.field.choice.f16_0.≥ 1:5（拥挤）"]
        XCTAssertTrue(low.exists); XCTAssertTrue(middle.exists); XCTAssertTrue(high.exists)
        low.tap(); XCTAssertTrue(low.isSelected); middle.tap(); XCTAssertTrue(middle.isSelected)
        capture("elevator-ratio-middle-normal", app)
        high.tap(); XCTAssertTrue(high.isSelected); capture("elevator-ratio-high-automatic-issue", app)
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.staticTexts["mp.field.title.f16_0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["需要关注 · 1"].exists)
        app.terminate(); app.launch()
        let house = app.buttons["house.电梯住户比验收"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(high.waitForExistence(timeout: 3)); XCTAssertTrue(high.isSelected)
        high.tap(); XCTAssertTrue(app.staticTexts["目前没有标记的问题"].waitForExistence(timeout: 3))
        capture("elevator-ratio-cleared-after-relaunch", app)
    }
}
