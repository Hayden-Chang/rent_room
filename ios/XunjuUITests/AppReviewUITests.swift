import XCTest

@MainActor final class AppReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(purchase: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if purchase { app.launchArguments += ["--capacity-business-fixture", "success"] }
        app.launch(); XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 10)); return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func assertNoDelayedReview(_ app: XCUIApplication) {
        let unexpected = expectation(for: NSPredicate(format: "exists == true"), evaluatedWith: app.staticTexts["喜欢“看房搭子”吗？"])
        unexpected.isInverted = true
        // Observe longer than the production 2-second scheduling delay.
        wait(for: [unexpected], timeout: 3)
    }
    private func dismissSystemReview(_ app: XCUIApplication, name: String) {
        // StoreKit exposes its content as ordinary elements, not XCUIElementTypeAlert.
        let title = app.staticTexts["喜欢“看房搭子”吗？"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "App", "评分")).firstMatch.exists)
        XCTAssertEqual(app.otherElements["评分"].value as? String, "零颗星")
        capture(name)
        let later = app.buttons["以后"]
        XCTAssertTrue(later.exists); later.tap()
        XCTAssertTrue(title.waitForNonExistence(timeout: 3))
    }
    func testThirdCreationRequestsSystemReviewOnceAndKeepsManualFeedback() {
        let app = launch()
        for n in 1...3 {
            app.homeAddButton.tap()
            let name = app.textFields["prompt.text"]
            XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("评分房源\(n)")
            app.buttons["prompt.confirm"].tap()
            XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["喜欢“看房搭子”吗？"].exists)
            app.navigationBackButton.tap()
            let house = app.buttons["house.评分房源\(n)"]
            XCTAssertTrue(house.waitForExistence(timeout: 4))
            XCTAssertFalse(app.buttons["关闭反馈"].exists)
            if n < 3 {
                assertNoDelayedReview(app)
                house.press(forDuration: 1); app.confirmArchiveFromHouseMenu()
                XCTAssertTrue(house.waitForNonExistence(timeout: 3))
            }
        }
        dismissSystemReview(app, name: "review-after-third-creation")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.评分房源3"].waitForExistence(timeout: 10))
        assertNoDelayedReview(app)
        app.buttons["tab.我的"].tap()
        let feedback = app.buttons["local-settings.feedback"]
        for _ in 0..<4 { if feedback.isHittable { break }; app.swipeUp() }
        feedback.tap(); XCTAssertTrue(app.buttons["feedback.ease.方便"].waitForExistence(timeout: 3))
        capture("review-manual-feedback-retained")
        app.buttons["关闭反馈"].tap(); app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.buttons["house.评分房源3"].waitForExistence(timeout: 3))
        assertNoDelayedReview(app)
    }
    func testVerifiedPurchaseRequestsSystemReviewAfterThankYou() {
        let app = launch(purchase: true)
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.capacity"].tap()
        let purchase = app.buttons["capacity.purchase"]
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: purchase)
        wait(for: [enabled], timeout: 8); purchase.tap()
        let granted = expectation(for: NSPredicate(format: "label == %@", "0 / 11 套"), evaluatedWith: app.staticTexts["capacity.total"])
        wait(for: [granted], timeout: 8)
        dismissSystemReview(app, name: "review-after-verified-purchase")
        XCTAssertFalse(app.buttons["关闭反馈"].exists)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 3))
        assertNoDelayedReview(app)
    }
}
