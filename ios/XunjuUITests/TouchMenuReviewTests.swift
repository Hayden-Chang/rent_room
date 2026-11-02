import XCTest

@MainActor final class TouchMenuReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "touch-menu", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["touch-menu.card.left"].waitForExistence(timeout: 8))
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testLongPressUsesActualTouchAndOutsideTapDismisses() {
        let app = launch(), card = app.buttons["touch-menu.card.left"]
        capture("touch-menu-background-before", app)
        let point = CGPoint(x: card.frame.minX + 24, y: card.frame.minY + 48)
        card.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 24, dy: 48)).press(forDuration: 0.65)
        let panel = app.otherElements["touch-menu.panel"]
        XCTAssertTrue(app.buttons["touch-menu.action.0"].waitForExistence(timeout: 3))
        XCTAssertEqual(panel.frame.minX, point.x + 8, accuracy: 2)
        XCTAssertEqual(panel.frame.minY, point.y, accuracy: 2)
        XCTAssertEqual(app.staticTexts["touch-menu.event"].label, "等待操作")
        capture("touch-menu-left", app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.55)).tap()
        XCTAssertTrue(app.buttons["touch-menu.action.0"].waitForNonExistence(timeout: 3))
        card.tap()
        XCTAssertEqual(app.staticTexts["touch-menu.event"].label, "打开")
    }

    func testRightAndBottomEdgesRemainVisibleAndActionsWork() {
        let app = launch()
        for id in ["right", "bottom-right"] {
            let card = app.buttons["touch-menu.card.\(id)"]
            card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)).press(forDuration: 0.65)
            XCTAssertTrue(app.buttons["touch-menu.action.0"].waitForExistence(timeout: 3))
            let frame = app.otherElements["touch-menu.panel"].frame
            XCTAssertEqual(frame.maxX, app.frame.maxX - 12, accuracy: 2)
            XCTAssertLessThan(frame.maxY, app.frame.maxY)
            XCTAssertTrue(app.buttons["touch-menu.action.2"].isHittable)
            capture("touch-menu-\(id)", app)
            app.buttons["touch-menu.action.2"].tap()
            XCTAssertTrue(app.buttons["touch-menu.action.0"].waitForNonExistence(timeout: 3))
            XCTAssertEqual(app.staticTexts["touch-menu.event"].label, "导出房源 ZIP")
        }
    }
}
