import XCTest

@MainActor final class TopFloorReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testYesAutomaticIssueSwipeCancellationAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "top-floor", "--top-floor-review-id", UUID().uuidString, "--parity-trace",
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let yes = app.buttons["mp.field.choice.f1_top.是"], no = app.buttons["mp.field.choice.f1_top.否"]
        let title = app.staticTexts["mp.field.title.f1_top"]
        XCTAssertTrue(yes.waitForExistence(timeout: 10)); XCTAssertEqual(title.label, "顶楼")
        capture("top-floor-01-unanswered", app)
        yes.tap(); XCTAssertTrue(yes.isSelected)
        XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：1")
        capture("top-floor-02-yes-automatic-issue", app)
        // Swipe the field users slide, rather than a 44-point choice button.
        let row = app.otherElements["mp.field.f1_top"].firstMatch
        XCTAssertTrue(row.isHittable)
        row.swipeLeft()
        let trace = XCTAttachment(string: row.value as? String ?? "")
        trace.name = "top-floor-native-pan-trace"; trace.lifetime = .keepAlways; add(trace)
        let cancel = app.buttons["mp.field.action.f1_top.取消问题"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3)); capture("top-floor-03-swipe-cancel-action", app)
        cancel.tap(); XCTAssertTrue(yes.isSelected)
        XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：0")
        capture("top-floor-04-manually-cancelled", app)
        app.terminate(); app.launch(); XCTAssertTrue(yes.waitForExistence(timeout: 10))
        XCTAssertTrue(yes.isSelected); XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：0")
        capture("top-floor-05-cancellation-after-relaunch", app)
        no.tap(); XCTAssertTrue(no.isSelected)
        XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：0")
        yes.tap(); XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：1")
        no.tap(); XCTAssertEqual(app.staticTexts["review.topFloor.issues"].label, "异常项：0")
        capture("top-floor-06-no-clears-automatic-issue", app)
    }
}
