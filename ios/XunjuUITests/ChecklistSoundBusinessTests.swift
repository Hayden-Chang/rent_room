import XCTest

@MainActor final class ChecklistSoundBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testBellPersistsAcrossHousesAndRelaunchWithoutChangingAnswers() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--returning-business-fixture", "--two-room-policy-fixture",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        addHouse("阳光小区", app)
        let bell = app.buttons["checklist.sound.toggle"]
        soundState("已开启", app)
        bell.tap(); soundState("已关闭", app)
        capture("sound-business-muted", app)
        let search = app.textFields["mp.checklist.search"]
        search.tap(); search.typeText("冬季水管"); app.buttons["checklist.keyboard.done"].tap()
        let no = app.buttons["mp.field.choice.f77_0.否"]
        XCTAssertTrue(no.waitForExistence(timeout: 3)); XCTAssertTrue(no.isHittable)
        no.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: no)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        app.navigationBackButton.tap()
        addHouse("新城公寓", app)
        soundState("已关闭", app)
        app.terminate(); app.launch()
        openHouse("阳光小区", app)
        soundState("已关闭", app)
        search.tap(); search.typeText("冬季水管"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(no.isSelected, "Muting must not block or clear committed answers")
        bell.tap(); soundState("已开启", app)
        XCTAssertTrue(no.isSelected)
        capture("sound-business-restored", app)
        app.terminate(); app.launch()
        openHouse("阳光小区", app)
        soundState("已开启", app)
    }

    private func addHouse(_ name: String, _ app: XCUIApplication) {
        // Two real creations avoid the unrelated system review requested by the
        // three-house pixel fixture. Keep normal navigation and persistence.
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 10)); app.homeAddButton.tap()
        let input = app.textFields["prompt.text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3)); input.replacePromptText(name)
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["checklist.sound.toggle"].waitForExistence(timeout: 5))
    }

    private func openHouse(_ name: String, _ app: XCUIApplication) {
        let house = app.buttons["house." + name]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); XCTAssertTrue(house.isHittable); house.tap()
        XCTAssertTrue(app.buttons["checklist.sound.toggle"].waitForExistence(timeout: 3))
    }
    private func soundState(_ value: String, _ app: XCUIApplication) {
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: app.buttons["checklist.sound.toggle"])
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 3), .completed)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
