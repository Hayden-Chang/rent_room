import XCTest

@MainActor final class AccountProfileUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testNicknameAndAvatarPickerCancellationPreserveAccountProfileAfterRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "--capacity-business-fixture", "pending", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10)); app.buttons["tab.我的"].tap()
        let nickname = app.textFields["settings.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 3)); nickname.tap(); nickname.typeText("小林")
        app.dismissKeyboardFromHeader()
        app.buttons["settings.avatar"].tap()
        let cancel = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); cancel.tap()
        XCTAssertEqual(nickname.value as? String, "小林")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10)); app.buttons["tab.我的"].tap()
        XCTAssertTrue(nickname.waitForExistence(timeout: 3)); XCTAssertEqual(nickname.value as? String, "小林")
        XCTAssertTrue(app.staticTexts["已通过 Apple 登录"].exists)
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = "pixel-18-account-profile"; image.lifetime = .keepAlways; add(image)
        let logout = app.buttons["退出登录"]
        for _ in 0..<3 { if logout.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(logout.isHittable)
        let bottom = XCTAttachment(screenshot: app.screenshot()); bottom.name = "pixel-18b-settings-logout"; bottom.lifetime = .keepAlways; add(bottom)
    }
}
