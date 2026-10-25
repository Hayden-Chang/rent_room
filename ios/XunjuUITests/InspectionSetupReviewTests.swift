import XCTest

@MainActor
final class InspectionSetupReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "inspection-setup", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testTemplateToggleAndNativeDragPreserveDraftAcrossSteps() {
        let app = launch()
        capture("01-xiaoda-template-order", app)
        let toggle = app.buttons["setup.toggle.房源基本信息"]
        toggle.tap()
        XCTAssertEqual(toggle.label, "恢复房源基本信息")
        capture("02-template-disabled", app)
        toggle.tap()
        XCTAssertEqual(toggle.label, "停用房源基本信息")

        let first = app.images["setup.drag.房源基本信息"]
        let second = app.staticTexts["setup.title.周边与小区"]
        XCTAssertTrue(first.isHittable); XCTAssertTrue(second.isHittable)
        first.press(forDuration: 0.8, thenDragTo: second)
        let reordered = NSPredicate { _, _ in
            app.staticTexts["setup.title.周边与小区"].frame.minY < app.staticTexts["setup.title.房源基本信息"].frame.minY
        }
        XCTAssertTrue(reordered.evaluate(with: app))
        capture("03-template-reordered", app)
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.back"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertTrue(reordered.evaluate(with: app))
        XCTAssertEqual(toggle.label, "停用房源基本信息")
    }

    func testModesAreExclusiveAndReturnKeepsSelection() {
        let app = launch()
        app.buttons["setup.next"].tap()
        let simple = app.buttons["setup.mode.simple"], detailed = app.buttons["setup.mode.detailed"]
        XCTAssertTrue(simple.waitForExistence(timeout: 3))
        XCTAssertTrue(simple.isSelected); XCTAssertFalse(detailed.isSelected)
        capture("04-mode-simple-selected", app)
        if !detailed.isHittable { app.swipeUp() }
        detailed.tap()
        XCTAssertTrue(detailed.isSelected); XCTAssertFalse(simple.isSelected)
        app.swipeUp()
        capture("05-mode-detailed-example", app)
        app.buttons["setup.back"].tap()
        XCTAssertTrue(app.buttons["setup.toggle.房源基本信息"].waitForExistence(timeout: 3))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(simple.waitForExistence(timeout: 3))
        XCTAssertTrue(detailed.isSelected); XCTAssertFalse(simple.isSelected)
        capture("06-mode-selection-retained", app)
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.alerts["组件回调已收到"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.alerts.staticTexts["详细模式；首项：房源基本信息。评审草稿未写入房源。"].exists)
    }
}
