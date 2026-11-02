import XCTest

@MainActor
final class OutsideInputBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testChecklistAndSummarySaveOnOutsideTapAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--returning-business-fixture",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10)); currency.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 3))
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5)); add.tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("外部点击保存验收")
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
        searchFurniture(app)
        let furniture = app.textFields["mp.field.input.f54_0"]
        XCTAssertTrue(furniture.waitForExistence(timeout: 3)); furniture.tap(); furniture.typeText("衣柜、书桌")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        capture("outside-business-01-editing", app)
        app.staticTexts["mp.field.title.f54_0"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertEqual(furniture.value as? String, "衣柜、书桌")
        capture("outside-business-02-title-saved", app)

        app.buttons["tab.总结"].tap()
        let note = app.textViews["summary.note"]
        XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap(); note.typeText("采光好\n入住时间待确认")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let decision = app.buttons["summary.考虑租住"]
        decision.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        XCTAssertTrue(decision.isSelected, "The outside button must execute on the first tap")
        XCTAssertEqual(note.value as? String, "采光好\n入住时间待确认")
        capture("outside-business-03-summary-saved", app)

        app.terminate(); app.launch()
        let house = app.buttons["house.外部点击保存验收"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 3))
        searchFurniture(app)
        XCTAssertEqual(furniture.value as? String, "衣柜、书桌")
        app.buttons["tab.总结"].tap()
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        XCTAssertTrue(decision.isSelected)
        XCTAssertEqual(note.value as? String, "采光好\n入住时间待确认")
        capture("outside-business-04-reopened", app)
    }

    private func searchFurniture(_ app: XCUIApplication) {
        let search = app.textFields["mp.checklist.search"]
        search.tap(); search.typeText("缺少的家具")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
