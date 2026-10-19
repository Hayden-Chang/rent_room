import XCTest

@MainActor
final class ComponentReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ surface: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", surface, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }

    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testHouseCardsAndEmptyState() {
        let app = launch("homes")
        let first = app.buttons["house.first"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["2 个问题"].exists)
        capture("01-house-cards", app: app)
        first.tap()
        XCTAssertEqual(app.staticTexts["review.event"].label, "已触发打开1号房")
        app.buttons["review.toggleEmpty"].tap()
        let add = app.buttons["house.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        capture("02-house-empty", app: app)
        add.tap()
        XCTAssertEqual(app.staticTexts["review.event"].label, "已触发添加房源")
    }

    func testChecklistDisclosureSelectionAndSwipe() {
        let app = launch("checklist")
        let group = app.buttons["group.家电"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["choice.空调.正常"].exists)
        group.tap()
        let normal = app.buttons["choice.空调.正常"]
        XCTAssertTrue(normal.waitForExistence(timeout: 3))
        normal.tap()
        XCTAssertTrue(normal.isSelected)
        capture("03-checklist-selection", app: app)
        group.tap()
        XCTAssertFalse(normal.exists)
        group.tap()
        XCTAssertTrue(normal.isSelected)
        app.otherElements["row.空调"].firstMatch.swipeLeft()
        let note = app.buttons["row.空调.备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        capture("04-checklist-swipe", app: app)
        note.tap()
        XCTAssertEqual(app.staticTexts["review.event"].label, "已触发空调备注")
    }

    func testLoginEntriesAndPhoneFailureKeepsInput() {
        let app = launch("account")
        let phone = app.buttons["login.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["login.apple"].exists)
        capture("05-login-entries", app: app)
        phone.tap()
        let number = app.textFields["phone.number"]
        XCTAssertTrue(number.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["phone.request"].isEnabled)
        XCTAssertFalse(app.buttons["phone.submit"].isEnabled)
        capture("06-phone-empty", app: app)
        number.tap()
        number.typeText("13800138000")
        app.textFields["phone.code"].tap()
        app.textFields["phone.code"].typeText("012345")
        XCTAssertTrue(app.buttons["phone.request"].isEnabled)
        XCTAssertTrue(app.buttons["phone.submit"].isEnabled)
        app.buttons["phone.request"].tap()
        let error = app.staticTexts["phone.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "短信登录服务尚未接通，请稍后再试")
        XCTAssertEqual(number.value as? String, "13800138000")
        XCTAssertEqual(app.textFields["phone.code"].value as? String, "012345")
        XCTAssertFalse(app.staticTexts["验证码已发送，请查收短信"].exists)
        capture("07-phone-service-error", app: app)
        app.buttons["phone.close"].tap()
        XCTAssertTrue(phone.waitForExistence(timeout: 3))
    }
}
