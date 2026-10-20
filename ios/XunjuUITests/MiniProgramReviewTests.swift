import XCTest

@MainActor final class MiniProgramReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ route: String, state: String = "") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "parity-" + route, "--parity-state", state, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let item = XCTAttachment(screenshot: app.screenshot())
        item.name = "mp-" + name; item.lifetime = .keepAlways; add(item)
    }
    private func wait(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), file: file, line: line)
    }
    private func label(_ element: XCUIElement, equals value: String) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }
    func testHomePromptAndArchiveConfirmation() {
        let app = launch("home")
        wait(app.buttons["mp.home.add"]); capture("01-home", app)
        app.buttons["mp.home.add"].tap()
        wait(app.textFields["mp.prompt.text"]); capture("02-house-dialog", app)
        app.textFields["mp.prompt.text"].tap(); app.textFields["mp.prompt.text"].typeText("评审房源")
        app.buttons["mp.prompt.save"].tap()
        XCTAssertTrue(app.buttons["mp.home.add"].waitForExistence(timeout: 3))
        app.buttons["mp.house.one"].press(forDuration: 1)
        wait(app.buttons["归档房源"]); capture("03-house-menu", app)
        app.buttons["归档房源"].tap()
        wait(app.buttons["mp.confirm"])
        XCTAssertTrue(app.staticTexts["归档后保留全部记录，可在设置中还原"].exists)
        capture("04-archive-confirmation", app)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["mp.home.add"].isHittable)
    }
    func testEmptyHomeAndArchiveCards() {
        let app = launch("home", state: "empty")
        wait(app.buttons["添加房源"])
        XCTAssertFalse(app.buttons["mp.home.add"].exists); capture("05-home-empty", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-archive", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["mp.archive.one"]); capture("06-archive", app)
        app.buttons["mp.archive.two"].press(forDuration: 1)
        wait(app.buttons["还原房源"]); XCTAssertTrue(app.buttons["永久删除"].exists); capture("07-archive-menu", app)
    }
    func testChecklistSwipeNoteAndRetainedTabs() {
        let app = launch("detail")
        wait(app.buttons["mp.field.choice.seal.是"])
        label(app.buttons["mp.tab.影像"], equals: "影像 4")
        capture("08-checklist", app)
        app.buttons["mp.field.choice.seal.是"].swipeLeft()
        wait(app.buttons["mp.field.action.seal.标记问题"])
        capture("09-field-swipe", app)
        app.buttons["mp.field.action.seal.标记问题"].tap()
        app.buttons["mp.field.choice.seal.是"].swipeLeft()
        wait(app.buttons["mp.field.action.seal.备注"]); app.buttons["mp.field.action.seal.备注"].tap()
        wait(app.textViews["mp.note.text"]); capture("10-note-sheet", app)
        app.textViews["mp.note.text"].tap(); app.textViews["mp.note.text"].typeText("雨后再确认")
        app.buttons["mp.note.save"].tap()
        wait(app.buttons["mp.tab.影像"]); app.buttons["mp.tab.影像"].tap()
        wait(app.buttons["mp.media.filter.视频"]); app.buttons["mp.media.filter.视频"].tap()
        app.buttons["mp.tab.清单"].tap()
        wait(app.buttons["mp.field.choice.seal.是"])
        XCTAssertTrue(app.buttons["雨后再确认"].exists)
        capture("11-field-marked-note", app)
        app.buttons["mp.tab.影像"].tap()
        XCTAssertTrue(app.buttons["mp.media.preview.video"].exists)
        XCTAssertFalse(app.buttons["mp.media.preview.image1"].exists)
        app.buttons["mp.tab.清单"].tap()
        app.buttons["筛选"].tap()
        wait(app.buttons["未记录"]); capture("12-checklist-filters", app)
    }
    func testMediaFilterLongPressAndGroupedPreview() {
        let app = launch("detail", state: "media")
        wait(app.buttons["mp.media.preview.image1"]); capture("13-media", app)
        XCTAssertTrue(app.staticTexts["视频 12s"].exists)
        app.buttons["mp.media.preview.image1"].tap()
        wait(app.staticTexts["mp.preview.index"]); label(app.staticTexts["mp.preview.index"], equals: "1 / 4")
        capture("14-media-preview", app)
        app.otherElements["mp.preview.pages"].swipeLeft()
        label(app.staticTexts["mp.preview.index"], equals: "2 / 4"); capture("15-media-preview-next", app)
        app.buttons["关闭预览"].tap()
        wait(app.buttons["mp.media.preview.image1"]); app.buttons["mp.media.preview.image1"].press(forDuration: 1)
        wait(app.buttons["关联检查项"]); capture("16-media-menu", app)
        app.buttons["关联检查项"].tap()
        wait(app.textFields["搜索检查项"]); capture("17-association", app)
    }
    func testIssuesAndSummary() {
        let app = launch("detail", state: "issues")
        wait(app.buttons["manualIssue.one.resolve"]); capture("18-issues", app)
        app.buttons["manualIssue.one.resolve"].tap(); label(app.buttons["manualIssue.one.resolve"], equals: "已解决")
        app.buttons["mp.tab.总结"].tap()
        wait(app.buttons["mp.summary.继续比较"]); capture("19-summary", app)
        app.buttons["mp.summary.考虑租住"].tap()
        XCTAssertTrue(app.buttons["mp.summary.考虑租住"].isSelected)
        app.buttons["mp.tab.问题"].tap()
        label(app.buttons["manualIssue.one.resolve"], equals: "已解决")
    }
    func testIssueEditorValidationAndDiscard() {
        let app = launch("editor")
        wait(app.buttons["mp.issue.save"]); capture("20-issue-editor", app)
        app.buttons["mp.issue.save"].tap()
        wait(app.staticTexts["mp.issue.title-error"]); capture("21-issue-validation", app)
        app.textFields["mp.issue.title"].tap(); app.textFields["mp.issue.title"].typeText("窗户关不严")
        app.buttons["取消"].tap()
        wait(app.buttons["mp.confirm"]); capture("22-issue-discard", app)
        app.buttons["取消"].tap()
        XCTAssertEqual(app.textFields["mp.issue.title"].value as? String, "窗户关不严")
    }
    func testReadOnlyDetailAndEditorMedia() {
        let app = launch("detail", state: "readonly")
        wait(app.buttons["mp.field.choice.seal.是"])
        XCTAssertFalse(app.buttons["mp.field.choice.seal.是"].isEnabled)
        XCTAssertFalse(app.buttons["mp.checklist.capture"].exists); capture("23-readonly-checklist", app)
        app.buttons["mp.tab.影像"].tap()
        wait(app.buttons["mp.media.preview.image1"])
        XCTAssertFalse(app.buttons["mp.media.caption.image1"].exists)
        XCTAssertFalse(app.buttons["mp.media.capture"].exists); capture("24-readonly-media", app)
        app.buttons["mp.tab.问题"].tap(); app.buttons["manualIssue.one.open"].tap()
        wait(app.textFields["mp.issue.title"])
        XCTAssertFalse(app.textFields["mp.issue.title"].isEnabled)
        XCTAssertFalse(app.buttons["mp.issue.save"].exists); capture("25-readonly-editor", app)
    }
    func testComparisonSelectionAndDifferenceFilter() {
        let app = launch("compare")
        wait(app.buttons["mp.compare.start"]); XCTAssertFalse(app.buttons["mp.compare.start"].isEnabled)
        app.buttons["mp.compare.one"].tap(); app.buttons["mp.compare.two"].tap()
        XCTAssertTrue(app.buttons["mp.compare.start"].isEnabled); capture("26-compare-selection", app)
        app.buttons["mp.compare.start"].tap()
        wait(app.buttons["mp.compare.differences"]); capture("27-compare-results", app)
        XCTAssertTrue(app.staticTexts["电梯"].exists)
        app.buttons["mp.compare.differences"].tap()
        XCTAssertFalse(app.staticTexts["电梯"].exists); capture("28-compare-differences", app)
    }
    func testSettingsProfileAndThreeLoginEntrances() {
        let app = launch("settings")
        wait(app.textFields["mp.profile.nickname"]); capture("29-settings-profile", app)
        app.swipeUp(); wait(app.buttons["mp.profile.logout"]); capture("30-settings-footer", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-settings", "--parity-state", "guest", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["login.phone"])
        XCTAssertTrue(app.buttons["login.wechat"].exists); XCTAssertTrue(app.buttons["login.apple"].exists); capture("31-settings-guest", app)
        app.buttons["login.phone"].tap(); wait(app.textFields["phone.number"])
        XCTAssertFalse(app.buttons["phone.submit"].isEnabled); capture("32-phone", app)
    }
    func testTransferRequiresChoiceAndKeepsFixedFooter() {
        let app = launch("transfer")
        wait(app.buttons["mp.transfer.commit"])
        XCTAssertFalse(app.buttons["mp.transfer.commit"].isEnabled); capture("33-import-conflict", app)
        app.buttons["mp.transfer.mode.one.copy"].tap()
        XCTAssertTrue(app.buttons["mp.transfer.commit"].isEnabled); capture("34-import-ready", app)
        app.buttons["mp.transfer.commit"].tap()
        XCTAssertFalse(app.buttons["mp.transfer.commit"].isEnabled); capture("35-import-waiting", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-transfer", "--parity-state", "export", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["mp.transfer.commit"])
        XCTAssertFalse(app.buttons["mp.transfer.mode.one.copy"].exists); capture("36-export", app)
    }
    func testWorkplaceEmptyPermissionAndInlineCommutePicker() {
        let app = launch("workplace")
        wait(app.textViews["mp.workplace.address"])
        XCTAssertTrue(app.staticTexts["搜索地址或点击定位，选择上班位置"].exists); capture("37-workplace", app)
        app.buttons["place.locate"].tap()
        wait(app.buttons["place.retry"]); capture("38-location-denied", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-commute", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["mp.route.confirm"]); capture("39-commute", app)
        app.buttons["mp.route.option.two"].tap(); label(app.buttons["mp.route.confirm"], equals: "确定并填入 32 分钟")
        app.buttons["mp.route.origin"].tap()
        wait(app.buttons["mp.route.picker.cancel"])
        XCTAssertTrue(app.staticTexts["选择后更新这套房源的地址"].exists); capture("40-commute-picker", app)
        app.buttons["mp.route.picker.cancel"].tap()
        wait(app.buttons["mp.route.confirm"]); label(app.buttons["mp.route.confirm"], equals: "确定并填入 32 分钟")
    }
    func testCapacityPurchaseAndPendingStates() {
        let app = launch("capacity")
        wait(app.buttons["mp.capacity.purchase"]); capture("41-capacity", app)
        app.buttons["mp.capacity.purchase"].tap()
        XCTAssertFalse(app.buttons["mp.capacity.purchase"].isEnabled); capture("42-capacity-waiting", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-capacity", "--parity-state", "pending", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["mp.capacity.purchase"])
        XCTAssertFalse(app.buttons["mp.capacity.purchase"].isEnabled)
        XCTAssertTrue(app.buttons["mp.capacity.restore"].isEnabled); capture("43-capacity-pending", app)
    }
}
