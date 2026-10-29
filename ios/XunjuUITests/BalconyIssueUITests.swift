import XCTest

@MainActor final class BalconyIssueUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testNoBalconyShowsAutomaticIssueAndYesClearsAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("阳台异常验收")
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }
        app.buttons["coach.preference"].tap(); next.tap()
        let search = app.textFields["mp.checklist.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("有阳台")
        app.buttons["checklist.keyboard.done"].tap()
        let no = app.buttons["mp.field.choice.f1_balcony.否"]
        XCTAssertTrue(no.waitForExistence(timeout: 3)); no.tap(); XCTAssertTrue(no.isSelected)
        capture("balcony-no-automatic-issue", app)
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.staticTexts["mp.field.title.f1_balcony"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["需要关注 · 1"].exists)
        capture("balcony-issue-list", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.阳台异常验收"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.staticTexts["mp.field.title.f1_balcony"].waitForExistence(timeout: 3))
        let yes = app.buttons["mp.field.choice.f1_balcony.是"]
        yes.tap()
        XCTAssertTrue(app.staticTexts["目前没有标记的问题"].waitForExistence(timeout: 3))
        capture("balcony-yes-issue-cleared", app)
    }
}
