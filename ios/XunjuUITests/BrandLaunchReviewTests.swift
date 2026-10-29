import XCTest

@MainActor
final class BrandLaunchReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testBrandComposition() {
        verifyComposition(largeText: false, attachmentName: "brand-launch-default")
    }

    func testBrandCompositionWithAccessibilityText() {
        verifyComposition(largeText: true, attachmentName: "brand-launch-accessibility")
    }

    private func verifyComposition(largeText: Bool, attachmentName: String) {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "brand-launch", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()

        let title = app.staticTexts["brandLaunch.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let subtitle = app.staticTexts["brandLaunch.subtitle"]
        let tagline = app.staticTexts["brandLaunch.tagline"]
        XCTAssertEqual(title.label, "寻居")
        XCTAssertEqual(subtitle.label, "看房手记")
        XCTAssertEqual(tagline.label, "看房有记录，选家更有底")
        for text in [title, subtitle, tagline] {
            XCTAssertTrue(text.isHittable, "Brand copy must remain visible")
            XCTAssertTrue(app.frame.contains(text.frame), "Brand copy must stay within the viewport")
            XCTAssertEqual(text.frame.midX, app.frame.midX, accuracy: 5)
        }
        XCTAssertLessThan(title.frame.maxY, subtitle.frame.minY)
        XCTAssertLessThan(subtitle.frame.maxY, tagline.frame.minY)
        XCTAssertEqual(app.buttons.count, 0, "The static brand surface has no action or skip button")
        if largeText {
            XCTAssertGreaterThan(title.frame.height, 60, "The boundary capture must actually use accessibility text")
        }

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
