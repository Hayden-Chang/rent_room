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
        XCTAssertEqual(app.otherElements["mp.field.seal"].value as? String, "操作已展开")
        XCTAssertTrue(app.buttons["mp.field.action.seal.标记问题"].isHittable)
        capture("09-field-swipe", app)
        app.buttons["mp.field.action.seal.标记问题"].tap()
        XCTAssertTrue(app.buttons["mp.field.choice.seal.是"].isSelected)
        app.buttons["mp.field.choice.seal.是"].swipeLeft()
        wait(app.buttons["mp.field.action.seal.备注"])
        XCTAssertTrue(app.buttons["mp.field.action.seal.取消问题"].exists)
        XCTAssertTrue(app.buttons["mp.field.action.seal.备注"].isHittable)
        app.buttons["mp.field.action.seal.备注"].tap()
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
        let photo = app.scrollViews["mp.preview.image.image1"]
        XCTAssertEqual(photo.value as? String, "100%")
        photo.pinch(withScale: 2, velocity: 1)
        XCTAssertNotNil(photo.value as? String)
        XCTAssertNotEqual(photo.value as? String, "100%"); capture("44-media-zoom", app)
        photo.pinch(withScale: 0.25, velocity: -1)
        let unzoomed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "100%"), object: photo)
        XCTAssertEqual(XCTWaiter.wait(for: [unzoomed], timeout: 5), .completed)
        app.collectionViews["mp.preview.pages"].swipeLeft()
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
        app.buttons["mp.issue.cancel"].tap()
        wait(app.buttons["mp.confirm"]); capture("22-issue-discard", app)
        app.buttons["mp.confirm.cancel"].tap()
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
        label(app.buttons["mp.compare.start"], equals: "对比这 2 套房源")
        XCTAssertTrue(app.buttons["mp.compare.one"].isSelected)
        XCTAssertTrue(app.buttons["mp.compare.two"].isSelected)
        XCTAssertTrue(app.buttons["mp.compare.start"].isEnabled); capture("26-compare-selection", app)
        app.buttons["mp.compare.start"].tap()
        wait(app.buttons["mp.compare.differences"]); capture("27-compare-results", app)
        XCTAssertTrue(app.staticTexts["电梯"].exists)
        app.buttons["mp.compare.differences"].tap()
        XCTAssertFalse(app.staticTexts["电梯"].exists); capture("28-compare-differences", app)
    }
    func testSettingsProfileAndAppleOnlyLogin() {
        let app = launch("settings")
        wait(app.textFields["mp.profile.nickname"]); capture("29-settings-profile", app)
        app.swipeUp(); wait(app.buttons["mp.profile.logout"]); capture("30-settings-footer", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-settings", "--parity-state", "guest", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["login.apple"])
        XCTAssertFalse(app.buttons["login.wechat"].exists)
        XCTAssertFalse(app.buttons["login.phone"].exists)
        capture("31-settings-apple-only", app)
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
        wait(app.textFields["mp.workplace.address"])
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
        label(app.buttons["mp.capacity.purchase"], equals: "正在确认购买…")
        XCTAssertFalse(app.buttons["mp.capacity.purchase"].isEnabled); capture("42-capacity-waiting", app)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-capacity", "--parity-state", "pending", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.buttons["mp.capacity.purchase"])
        XCTAssertFalse(app.buttons["mp.capacity.purchase"].isEnabled)
        XCTAssertTrue(app.buttons["mp.capacity.restore"].isEnabled); capture("43-capacity-pending", app)
    }
    func testGuideCoversPageAndSpeedFeedback() {
        let app = launch("guide")
        wait(app.buttons["coach.next"])
        for step in 1...4 {
            if step == 4 {
                wait(app.otherElements["coach.actions"])
                app.buttons["coach.preference"].tap()
                XCTAssertEqual(app.buttons["coach.preference"].value as? String, "已选中")
            }
            capture("45-guide-\(step)", app)
            app.buttons["coach.next"].tap()
        }
        XCTAssertFalse(app.buttons["coach.next"].exists)
        app.terminate()
        app.launchArguments = ["--component-review", "parity-speed", "--parity-state", "done", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.staticTexts["speed.message"])
        XCTAssertEqual(app.staticTexts["speed.message"].label, "测速结果已回填")
        capture("46-speed-done", app)
    }
    func testCapacityUnavailableGuestAndOverLimit() {
        let app = XCUIApplication()
        for state in ["guest", "loading", "unavailable", "over", "error"] {
            app.launchArguments = ["--component-review", "parity-capacity", "--parity-state", state, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
            app.launch(); wait(app.buttons["mp.capacity.purchase"])
            if state == "guest" { XCTAssertEqual(app.buttons["mp.capacity.purchase"].label, "登录后购买") }
            if state == "unavailable" || state == "loading" { XCTAssertFalse(app.buttons["mp.capacity.purchase"].isEnabled) }
            if state == "over" { XCTAssertEqual(app.staticTexts["mp.capacity.total"].label, "12 / 2 套") }
            if state == "error" {
                capture("47-capacity-error", app)
                app.buttons["mp.capacity.restore"].tap()
                label(app.buttons["mp.capacity.restore"], equals: "正在恢复容量…")
                XCTAssertFalse(app.buttons["mp.capacity.restore"].isEnabled)
            }
            capture("47-capacity-\(state == "error" ? "restoring" : state)", app); app.terminate()
        }
    }
    func testChecklistVerticalScrollAndCostButton() {
        let app = launch("detail")
        let answer = app.buttons["mp.field.choice.seal.是"]
        wait(answer)
        let before = app.textFields["mp.field.input.address"].frame.minY
        answer.swipeUp()
        XCTAssertLessThan(app.textFields["mp.field.input.address"].frame.minY, before - 20)
        XCTAssertTrue(app.buttons["mp.cost.add"].isHittable)
        app.buttons["mp.cost.add"].tap()
        wait(app.staticTexts["其他费用 1"]); capture("48-add-cost", app)
        app.buttons["回到顶部"].tap()
        wait(answer)
        answer.swipeLeft()
        wait(app.buttons["mp.field.action.seal.备注"])
        app.staticTexts["mp.field.title.screen"].swipeUp()
        XCTAssertFalse(app.buttons["mp.field.action.seal.备注"].exists)
    }
    func testSettingsRecoveryAndAccountWaiting() {
        let app = launch("settings", state: "recovery")
        wait(app.buttons["mp.profile.recover"]); capture("49-record-recovery", app)
        app.buttons["mp.profile.recover"].tap()
        wait(app.staticTexts["mp.toast"])
        XCTAssertEqual(app.staticTexts["mp.toast"].label, "正在尝试恢复本机记录…")
        app.terminate()
        app.launchArguments = ["--component-review", "parity-settings", "--parity-state", "waiting", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); wait(app.staticTexts["mp.account.waiting"])
        XCTAssertFalse(app.buttons["login.wechat"].exists); capture("50-account-waiting", app)
    }
    func testGestureDiagnostics() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "parity-detail", "--parity-trace"]
        app.launch()
        wait(app.buttons["mp.field.choice.seal.是"])
        app.buttons["mp.field.choice.seal.是"].swipeLeft()
        let short = XCTAttachment(string: app.otherElements["mp.field.seal"].value as? String ?? "missing")
        short.name = "short-swipe-trace"; short.lifetime = .keepAlways; add(short)
        app.otherElements["mp.field.seal"].swipeLeft()
        let row = XCTAttachment(string: app.otherElements["mp.field.seal"].value as? String ?? "missing")
        row.name = "row-swipe-trace"; row.lifetime = .keepAlways; add(row)
        app.buttons["mp.tab.影像"].tap()
        app.buttons["mp.media.preview.image1"].tap()
        wait(app.scrollViews["mp.preview.image.image1"])
        let photo = app.scrollViews["mp.preview.image.image1"]
        photo.pinch(withScale: 2, velocity: 1)
        photo.pinch(withScale: 0.25, velocity: -1)
        let zoom = XCTAttachment(string: photo.value as? String ?? "missing")
        zoom.name = "zoom-trace"; zoom.lifetime = .keepAlways; add(zoom)
        capture("diagnostic-zoom", app)
    }
}
