import XCTest

@MainActor
final class TouchTrailReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--touch-trail-review", UUID().uuidString,
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.switches["settings.touch-trails"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String) {
        // Screen capture avoids an app-idleness wait that would outlast the 0.7s trail.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        XCTAssertTrue(toggle.isHittable)
        // MPSwitchStyle exposes the entire row as a switch, but its actual
        // 51pt button is at the trailing edge. The default AX tap hits the label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 0.5))
            .withOffset(CGVector(dx: -25.5, dy: 0)).tap()
    }

    private func openGestures(_ app: XCUIApplication) {
        let toggle = app.switches["settings.touch-trails"]
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        app.buttons["review.gestures"].tap()
        XCTAssertTrue(app.buttons["mp.field.choice.touch-review.是"].waitForExistence(timeout: 3))
    }

    func testFooterSwitchDefaultsOffAndPersistsBothChoices() {
        let app = launch()
        let toggle = app.switches["settings.touch-trails"]
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertLessThan(toggle.frame.maxY, app.staticTexts["版本"].frame.minY)
        capture("touch-trails-01-footer-off")
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        capture("touch-trails-02-footer-on")
        app.terminate()
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "1")
        tapSwitch(toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        app.terminate()
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.value as? String, "0")
    }

    func testEnabledTrailsPreserveSelectionSwipeLongPressAndScroll() {
        let app = launch()
        openGestures(app)
        let yes = app.buttons["mp.field.choice.touch-review.是"]
        yes.tap()
        XCTAssertTrue(yes.isSelected)
        let row = app.otherElements["mp.field.touch-review"].firstMatch
        row.swipeLeft()
        capture("touch-trails-03-real-swipe")
        let note = app.buttons["mp.field.action.touch-review.备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        note.tap()
        XCTAssertEqual(app.staticTexts["review.event"].label, "已打开备注")
        row.swipeRight()
        XCTAssertTrue(yes.isHittable)
        XCTAssertTrue(yes.isSelected)
        row.press(forDuration: 0.6)
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<6 where !app.staticTexts["review.bottom"].isHittable { scroll.swipeUp() }
        XCTAssertTrue(app.staticTexts["review.bottom"].isHittable)
        capture("touch-trails-04-scroll-reaches-bottom")
    }

    func testEnabledTrailsKeepSheetAndFullScreenControlsUsable() {
        let app = launch()
        openGestures(app)
        for (button, title) in [("review.sheet", "半屏弹层"), ("review.fullscreen", "全屏弹层")] {
            app.buttons[button].tap()
            let tap = app.buttons["review.modal.tap"]
            XCTAssertTrue(tap.waitForExistence(timeout: 3))
            tap.tap()
            capture("touch-trails-05-" + button)
            XCTAssertEqual(app.staticTexts["review.modal.event"].label, title + "点击成功")
            app.buttons["review.modal.close"].tap()
            XCTAssertTrue(tap.waitForNonExistence(timeout: 3))
            XCTAssertTrue(app.buttons[button].isHittable)
        }
    }
}
