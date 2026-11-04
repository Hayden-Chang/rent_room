import XCTest

@MainActor final class AppReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(purchase: Bool = false, filled: Bool = false, creation: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if purchase { app.launchArguments += ["--capacity-business-fixture", "success"] }
        if filled { app.launchArguments += ["--filled-review-fixture"] }
        if creation { app.launchArguments += ["--review-creation-fixture"] }
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
        let app = launch(creation: true)
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
        let purchase = app.buttons["credits.purchase"]
        let enabled = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: purchase)
        wait(for: [enabled], timeout: 8); purchase.tap()
        let granted = expectation(for: NSPredicate(format: "label MATCHES %@", "^12[^0-9]*$"), evaluatedWith: app.staticTexts["credits.balance"])
        wait(for: [granted], timeout: 8)
        dismissSystemReview(app, name: "review-after-verified-purchase")
        XCTAssertFalse(app.buttons["关闭反馈"].exists)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 3))
        assertNoDelayedReview(app)
    }
    func testFiftyFirstFilledItemRequestsOnlyAfterReturningHomeAndOnlyOnce() {
        let app = launch(filled: true)
        let house = app.buttons["house.评分检查项房源"]
        XCTAssertTrue(house.exists)
        assertNoDelayedReview(app)
        house.tap()
        let search = app.textFields["mp.checklist.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap(); search.typeText("租金")
        app.buttons["checklist.keyboard.done"].tap()
        let rent = app.textFields["mp.field.input.f1_6"]
        XCTAssertTrue(rent.waitForExistence(timeout: 3)); rent.tap(); rent.typeText("2800")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertEqual(rent.value as? String, "2800")
        assertNoDelayedReview(app)
        capture("review-51-items-still-in-detail")
        app.navigationBackButton.tap()
        XCTAssertTrue(house.waitForExistence(timeout: 4))
        dismissSystemReview(app, name: "review-after-51-items-return-home")
        app.terminate(); app.launch()
        XCTAssertTrue(house.waitForExistence(timeout: 10))
        assertNoDelayedReview(app)
        capture("review-51-items-relaunch-no-repeat")
    }
}
