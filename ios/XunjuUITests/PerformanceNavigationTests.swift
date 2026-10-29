import XCTest

@MainActor final class PerformanceNavigationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testTemplateEditorsOpenSaveAndReopenWithoutLayoutLoop() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--pixel-parity-fixture", "--business-test", UUID().uuidString,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap()
        let templates = app.buttons["settings.templates"]
        for _ in 0..<5 { if templates.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(templates.isHittable); templates.tap()
        let simple = app.buttons["templates.edit.simple"]
        XCTAssertTrue(simple.waitForExistence(timeout: 3)); simple.tap()
        let toggle = app.buttons["setup.toggle.周边与小区"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "Template navigation must settle and expose editable content")
        XCTAssertEqual(toggle.label, "停用周边与小区"); toggle.tap()
        XCTAssertEqual(toggle.label, "恢复周边与小区")
        app.buttons["template.save"].tap()
        XCTAssertTrue(app.buttons["templates.confirm"].waitForExistence(timeout: 3))
        app.buttons["templates.edit.detailed"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 3)); XCTAssertEqual(toggle.label, "停用周边与小区")
        capture("performance-template-detailed", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(simple.waitForExistence(timeout: 3)); simple.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 3)); XCTAssertEqual(toggle.label, "恢复周边与小区")
        capture("performance-template-simple-reopened", app)
        toggle.tap(); app.buttons["template.save"].tap()
        XCTAssertTrue(app.buttons["templates.confirm"].waitForExistence(timeout: 3))
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
