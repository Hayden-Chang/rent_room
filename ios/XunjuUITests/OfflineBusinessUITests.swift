import XCTest

@MainActor final class OfflineBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testLocalRecordSurvivesRelaunchAndSettingsOffersLegalPagesWithoutLogin() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("离线保留房源"); app.buttons["prompt.confirm"].tap()
        let query = app.textFields["mp.checklist.search"]
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        let rent = app.textFields["mp.field.input.f1_6"]
        XCTAssertTrue(rent.waitForExistence(timeout: 3)); rent.replacePromptText("1800"); app.buttons["checklist.keyboard.done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.离线保留房源"].waitForExistence(timeout: 10)); app.buttons["house.离线保留房源"].tap()
        XCTAssertTrue(query.waitForExistence(timeout: 5)); query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(rent.value as? String, "1800")
        app.navigationBackButton.tap(); app.buttons["tab.我的"].tap()
        XCTAssertTrue(app.buttons["local-settings.capacity"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["local-settings.capacity"].label.contains("1 / 2"))
        XCTAssertFalse(app.buttons["login.apple"].exists); XCTAssertFalse(app.buttons["退出登录"].exists)
        XCTAssertFalse(app.textFields["settings.nickname"].exists)
        capture("offline-business-settings", app)
        app.buttons["local-settings.workplace"].tap()
        let workplace = app.textFields["workplace.address"]
        XCTAssertTrue(workplace.waitForExistence(timeout: 3)); workplace.tap(); workplace.typeText("离线手填地址"); app.buttons["完成"].firstMatch.tap()
        app.navigationBackButton.tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10)); app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertTrue(workplace.waitForExistence(timeout: 3)); XCTAssertEqual(workplace.value as? String, "离线手填地址")
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists)
        XCTAssertFalse(app.staticTexts["place.message"].exists)
        capture("offline-business-saved-address", app)
        app.navigationBackButton.tap()
        let review = app.buttons["settings.appStoreReview"]
        for _ in 0..<3 where !review.isHittable { app.swipeUp() }
        XCTAssertTrue(review.isHittable, "Keep the existing main-branch App Store review entry")
        capture("offline-business-app-store-review", app)
        for page in ["privacy", "terms", "support"] {
            let row = app.buttons["legal.\(page)"]
            for _ in 0..<3 where !row.isHittable { app.swipeUp() }
            XCTAssertTrue(row.isHittable)
        }
        capture("offline-business-legal", app)
        let touchTrail = app.switches["settings.touch-trails"]
        for _ in 0..<3 where !touchTrail.isHittable { app.swipeUp() }
        XCTAssertTrue(touchTrail.isHittable)
        XCTAssertEqual(touchTrail.value as? String, "0")
        capture("offline-business-touch-preference", app)
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
