import XCTest

@MainActor final class AutomaticChoiceIssueUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testSixChoicesAutomaticallyFlagAndPersistWhileNotApplicableClears() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("自动异常验收")
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }; app.buttons["coach.preference"].tap(); next.tap()
        let cases = [
            ("f51_1", "鞋柜", "不够用", "够用", ""),
            ("f51_2", "厨房收纳", "不够用", "没有", ""),
            ("f120_0", "可配合办理居住证", "否", "不涉及", ""),
            ("f21_1", "日照时段", "无", "上午", ""),
            ("f62_1", "出热水速度", "大于 1 分钟", "1分钟内", "topic_62"),
            ("f83_1", "网络类型", "无网络", "独立宽带", "bb080b15-a843-4478-a4c6-5453ec0a2ac6")
        ]
        var previousQuery = ""
        for (index, item) in cases.enumerated() {
            let (field, query, badValue, goodValue, group) = item
            let search = app.textFields["mp.checklist.search"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap()
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: previousQuery.count) + query)
            app.buttons["checklist.keyboard.done"].tap(); previousQuery = query
            if !group.isEmpty {
                let presence = app.buttons["mp.field.choice.node:group:" + group + ".是"]
                XCTAssertTrue(presence.waitForExistence(timeout: 3)); presence.tap()
            }
            let bad = app.buttons["mp.field.choice." + field + "." + badValue]
            XCTAssertTrue(bad.waitForExistence(timeout: 3)); bad.tap(); XCTAssertTrue(bad.isSelected)
            XCTAssertTrue(app.staticTexts["\(index + 1) 项有问题"].exists)
            capture("automatic-issue-" + field, app)
            let good = app.buttons["mp.field.choice." + field + "." + goodValue]
            good.tap(); XCTAssertTrue(app.staticTexts["\(index) 项有问题"].exists)
            bad.tap(); XCTAssertTrue(app.staticTexts["\(index + 1) 项有问题"].exists)
        }
        app.terminate(); app.launch()
        let house = app.buttons["house.自动异常验收"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.staticTexts["需要关注 · 6"].waitForExistence(timeout: 3))
        capture("six-automatic-issues-after-relaunch", app)
        let notApplicable = app.buttons["mp.field.choice.f120_0.不涉及"]
        for _ in 0..<3 { if notApplicable.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(notApplicable.isHittable); notApplicable.tap()
        XCTAssertTrue(app.staticTexts["需要关注 · 5"].waitForExistence(timeout: 3))
        capture("residence-not-applicable-clears-automatic-issue", app)
    }
}
