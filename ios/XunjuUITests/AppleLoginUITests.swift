import XCTest

@MainActor final class AppleLoginUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testLogoutShowsAppleOnlyAndChallengeRetryKeepsGuestRecords() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "--capacity-business-fixture", "pending", "--apple-login-retry-fixture",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap()
        XCTAssertTrue(app.staticTexts["已通过 Apple 登录"].waitForExistence(timeout: 5))
        capture("apple-signed-in-fixture", app)
        app.buttons["退出登录"].tap()
        let confirm = app.sheets.buttons["退出登录"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.tap()
        // Logout opens a fresh guest scope, which needs its own first setup.
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 5))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 5))
        app.buttons["tab.我的"].tap()
        let guide = app.switches["小搭引导"]
        XCTAssertTrue(guide.waitForExistence(timeout: 3))
        if guide.value as? String == "1" { guide.tap() }
        app.buttons["tab.房源"].tap(); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("未登录保留房源")
        app.buttons["prompt.confirm"].tap()
        // First-house teaching is independent of the optional guidance toggle.
        let coach = app.staticTexts["coach.title"]
        XCTAssertTrue(coach.waitForExistence(timeout: 5))
        app.buttons["coach.next"].tap()
        XCTAssertEqual(coach.label, "找到你想看的内容")
        app.buttons["coach.next"].tap()
        XCTAssertEqual(coach.label, "向左滑，试试看")
        let row = app.otherElements["mp.field.simple_01"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3)); row.swipeLeft()
        let lastStep = expectation(for: NSPredicate(format: "label == %@", "随手记下房屋细节"), evaluatedWith: coach)
        wait(for: [lastStep], timeout: 4)
        app.buttons["coach.next"].tap()
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 3)); back.tap()
        let feedback = app.buttons["关闭反馈"]
        XCTAssertTrue(feedback.waitForExistence(timeout: 4)); feedback.tap()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 3)); app.buttons["tab.我的"].tap()
        let error = app.staticTexts["login.apple.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["login.apple"].isEnabled)
        XCTAssertFalse(app.buttons["login.phone"].exists)
        XCTAssertFalse(app.buttons["login.wechat"].exists)
        XCTAssertFalse(app.staticTexts["已通过 Apple 登录"].exists)
        capture("apple-service-unavailable", app)
        app.buttons["login.apple.retry"].tap()
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: app.buttons["login.apple"])
        wait(for: [ready], timeout: 5)
        XCTAssertFalse(error.exists)
        XCTAssertFalse(app.staticTexts["已通过 Apple 登录"].exists, "A challenge never authenticates the user")
        XCTAssertTrue(app.buttons["settings.capacity"].label.contains("1 / 1"))
        capture("apple-only-ready", app)
        app.buttons["tab.房源"].tap()
        XCTAssertTrue(app.buttons["house.未登录保留房源"].waitForExistence(timeout: 3))
    }
}
