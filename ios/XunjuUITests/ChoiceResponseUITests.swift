import XCTest

@MainActor final class ChoiceResponseUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testYesNoAndGroupResultsUpdateAndSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--returning-business-fixture", "--pixel-parity-fixture",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let house = app.buttons["house.阳光小区"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        search("顶楼", app)
        choose("f1_top", "是", app); choose("f1_top", "否", app)
        choose("f1_top", "否", app, selected: false); choose("f1_top", "是", app)
        capture("choice-top-floor-yes", app)
        search("热水器", app)
        choose("node:group:topic_62", "没有", app)
        choose("node:group:topic_62", "是", app)
        choose("node:group:topic_62", "否", app)
        capture("choice-water-heater-abnormal", app)
        app.terminate(); app.launch()
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        search("顶楼", app)
        XCTAssertTrue(app.buttons["mp.field.choice.f1_top.是"].isSelected)
        search("热水器", app)
        XCTAssertTrue(app.buttons["mp.field.choice.node:group:topic_62.否"].isSelected)
        capture("choice-results-after-relaunch", app)
    }
    private func search(_ text: String, _ app: XCUIApplication) {
        let field = app.textFields["mp.checklist.search"]
        XCTAssertTrue(field.waitForExistence(timeout: 3)); XCTAssertTrue(field.isHittable); field.tap()
        if let value = field.value as? String, value != "搜索检查项", !value.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        field.typeText(text); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }
    private func choose(_ id: String, _ label: String, _ app: XCUIApplication, selected: Bool = true) {
        let button = app.buttons["mp.field.choice.\(id).\(label)"]
        XCTAssertTrue(button.waitForExistence(timeout: 3)); XCTAssertTrue(button.isHittable)
        let started = Date(); button.tap()
        let updated = expectation(for: NSPredicate(format: "selected == %@", NSNumber(value: selected)), evaluatedWith: button)
        XCTAssertEqual(XCTWaiter.wait(for: [updated], timeout: 2), .completed)
        // XCTest includes gesture synthesis and quiescence. Native save/refresh
        // timings are reported separately by ChoicePerformanceTests.
        print("CHOICE_UI id=\(id) label=\(label) tap_and_observation_s=\(Date().timeIntervalSince(started))")
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
