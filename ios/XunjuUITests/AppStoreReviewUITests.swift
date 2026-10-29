import XCTest

@MainActor final class AppStoreReviewUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "app-store-review", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["settings.appStoreReview"].waitForExistence(timeout: 10))
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testReviewRowOpensWriteReviewURLOnEveryTap() {
        let app = launch()
        let row = app.buttons["settings.appStoreReview"]
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(row.label.contains("在 App Store 中评价"))
        capture("app-store-review-row", app)
        row.tap()
        let destination = app.staticTexts["review.openedURL"]
        XCTAssertTrue(destination.waitForExistence(timeout: 3))
        XCTAssertEqual(destination.label, "https://apps.apple.com/app/id1234567890?action=write-review")
        XCTAssertEqual(app.staticTexts["review.openCount"].label, "打开次数：1")
        row.tap()
        XCTAssertEqual(app.staticTexts["review.openCount"].label, "打开次数：2")
        XCTAssertFalse(app.alerts.firstMatch.exists)
        capture("app-store-review-url-request", app)
    }

    func testOpenFailureShowsDismissibleErrorAndAllowsRetry() {
        let app = launch(["--review-open-fails"])
        let row = app.buttons["settings.appStoreReview"]
        row.tap()
        let alert = app.alerts["无法打开 App Store"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        XCTAssertTrue(alert.staticTexts["暂时无法打开评价页面，请稍后重试。"].exists)
        capture("app-store-review-open-error", app)
        alert.buttons["好"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        row.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 3))
        alert.buttons["好"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["review.openCount"].label, "打开次数：2")
    }

    func testMissingAppIDShowsErrorWithoutOpeningURL() {
        let app = launch(["--review-missing-id"])
        app.buttons["settings.appStoreReview"].tap()
        XCTAssertTrue(app.alerts["无法打开 App Store"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["review.openedURL"].exists)
        capture("app-store-review-missing-id", app)
    }
}
