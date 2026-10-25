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
        let group = app.buttons["group.墙面地面与门窗"]
        XCTAssertTrue(group.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["choice.纱窗正常.正常"].exists)
        group.tap()
        let normal = app.buttons["choice.纱窗正常.正常"]
        XCTAssertTrue(normal.waitForExistence(timeout: 3))
        XCTAssertEqual(normal.label, "是")
        XCTAssertEqual(app.buttons["choice.纱窗正常.有问题"].label, "否")
        XCTAssertEqual(app.buttons["choice.纱窗正常.没有"].label, "没有")
        normal.tap()
        XCTAssertTrue(normal.isSelected)
        capture("03-checklist-selection", app: app)
        group.tap()
        XCTAssertFalse(normal.exists)
        group.tap()
        XCTAssertTrue(normal.isSelected)
        app.otherElements["row.纱窗正常"].firstMatch.swipeLeft()
        let note = app.buttons["row.纱窗正常.备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        capture("04-checklist-swipe", app: app)
        note.tap()
        XCTAssertEqual(app.staticTexts["review.event"].label, "已触发纱窗备注")
    }

    func testAppleOnlyLoginComponent() {
        let app = launch("account")
        XCTAssertTrue(app.buttons["login.apple"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["login.phone"].exists)
        XCTAssertFalse(app.buttons["login.wechat"].exists)
        XCTAssertTrue(app.staticTexts["未登录也可记录看房"].exists)
        XCTAssertTrue(app.buttons["settings.capacity"].exists)
        XCTAssertFalse(app.buttons["login.apple"].isEnabled, "A component preview cannot authenticate")
        capture("apple-only-component", app: app)
    }
}
