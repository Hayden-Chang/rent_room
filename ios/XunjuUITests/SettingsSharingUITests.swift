import XCTest

@MainActor final class SettingsSharingUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testChineseSettingsOmitsAppSharingAndKeepsFeedbackAndReview() {
        verifySettings(english: false)
    }

    func testEnglishSettingsOmitsAppSharingAndKeepsFeedbackAndReview() {
        verifySettings(english: true)
    }

    private func verifySettings(english: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "-AppleLanguages", english ? "(en)" : "(zh-Hans)",
            "-AppleLocale", english ? "en_US" : "zh_CN"]
        app.launch()
        let decline = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 10))
        decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 5))
        let myTab = app.buttons["tab.我的"]
        XCTAssertTrue(myTab.waitForExistence(timeout: 10))
        myTab.tap()
        let review = app.buttons["settings.appStoreReview"]
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        for _ in 0..<4 {
            if review.isHittable && review.frame.maxY < myTab.frame.minY { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(review.isHittable)
        XCTAssertLessThan(review.frame.maxY, myTab.frame.minY)
        XCTAssertTrue(app.buttons["local-settings.feedback"].exists)
        XCTAssertTrue(app.buttons["legal.privacy"].exists)
        XCTAssertFalse(app.buttons["local-settings.share"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format:
            "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@",
            "分享看房搭子", "Share Xunju", "Share Xunjun")).firstMatch.exists)
        XCTAssertEqual(review.label.contains("在 App Store 中评价"), !english)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = english ? "settings-without-app-sharing-en" : "settings-without-app-sharing-zh"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
