import XCTest

@MainActor
final class LaunchIntegrationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func application(returning: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if returning { app.launchArguments += ["--returning-business-fixture", "--pixel-parity-fixture"] }
        return app
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstLaunchReachesSetupAndRelaunchRetainsChoice() {
        let app = application()
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-first-setup", app)
        let toggle = app.buttons["setup.toggle.房源基本信息"]
        toggle.tap()

        app.terminate()
        app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertEqual(toggle.label, "恢复房源基本信息")
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-setup-choice-restored", app)
        toggle.tap()
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["setup.mode.simple"].waitForExistence(timeout: 3))
        app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["home.first"].waitForExistence(timeout: 5))
        capture("launch-setup-completed-home", app)
    }

    func testReturningLaunchRestoresHomesAndResumeKeepsCurrentPage() {
        let app = application(returning: true)
        app.launch()
        XCTAssertTrue(app.buttons["house.阳光小区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.新城公寓"].exists)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-returning-home", app)

        app.buttons["tab.我的"].tap()
        XCTAssertTrue(app.buttons["settings.capacity"].waitForExistence(timeout: 3))
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        XCTAssertTrue(app.buttons["settings.capacity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.我的"].isSelected)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-background-resume-settings", app)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["house.阳光小区"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["house.新城公寓"].exists)
        XCTAssertFalse(app.images["brandLaunch.icon"].exists)
        capture("launch-returning-home-restored", app)
    }
}
