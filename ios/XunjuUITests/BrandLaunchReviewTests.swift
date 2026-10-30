import XCTest

@MainActor
final class BrandLaunchReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testBrandComposition() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "brand-launch", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()

        let icon = app.images["brandLaunch.icon"]
        XCTAssertTrue(icon.waitForExistence(timeout: 10))
        XCTAssertTrue(icon.isHittable)
        XCTAssertTrue(app.frame.contains(icon.frame))
        XCTAssertEqual(icon.frame.midX, app.frame.midX, accuracy: 1)
        XCTAssertEqual(icon.frame.midY, app.frame.midY, accuracy: 1)

        let surface = app.otherElements["brandLaunch.surface"]
        XCTAssertTrue(surface.exists)
        XCTAssertEqual(surface.staticTexts.count, 0, "The launch surface contains no visible copy")
        XCTAssertEqual(surface.images.count, 1, "Only the brand logo is displayed")
        XCTAssertEqual(app.buttons.count, 0, "The static brand surface has no action or skip button")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "brand-launch-mini-program-logo"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
