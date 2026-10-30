import XCTest

@MainActor
final class ChecklistSoundToggleReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHeaderBellTogglesOffAndOnWithoutChangingChoices() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "sound-toggle", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let bell = app.buttons["checklist.sound.toggle"]
        XCTAssertTrue(bell.waitForExistence(timeout: 10))
        XCTAssertTrue(bell.isHittable)
        XCTAssertEqual(bell.value as? String, "已开启")
        XCTAssertEqual(bell.label, "关闭声音")
        XCTAssertGreaterThanOrEqual(bell.frame.width, 44)
        XCTAssertGreaterThanOrEqual(bell.frame.height, 44)
        let title = app.staticTexts["阳光小区 · 1号房"]
        XCTAssertLessThan(title.frame.midX, bell.frame.minX)
        XCTAssertEqual(bell.frame.midY, app.buttons["navigation.back"].frame.midY, accuracy: 1)
        let yes = app.buttons["mp.field.choice.seal.是"]
        XCTAssertTrue(yes.isSelected)
        capture("bell-on", app: app)

        bell.tap()
        XCTAssertTrue(bell.waitForValue("已关闭"))
        XCTAssertEqual(bell.label, "开启声音")
        XCTAssertTrue(yes.isSelected)
        capture("bell-off", app: app)

        bell.tap()
        XCTAssertTrue(bell.waitForValue("已开启"))
        XCTAssertTrue(yes.isSelected)
        capture("bell-on-restored", app: app)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.staticTexts["sound-toggle.back"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["sound-toggle.back"].label, "已返回")
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let header = XCTAttachment(screenshot: app.otherElements["navigation.header"].screenshot())
        header.name = name + "-header"
        header.lifetime = .keepAlways
        add(header)
    }
}

private extension XCUIElement {
    func waitForValue(_ expected: String) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: self)
        return XCTWaiter.wait(for: [expectation], timeout: 3) == .completed
    }
}
