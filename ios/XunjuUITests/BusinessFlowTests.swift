import XCTest

@MainActor final class BusinessFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); return app
    }
    private func add(_ name: String, _ app: XCUIApplication) {
        app.buttons["home.add"].tap()
        let input = app.textFields["prompt.text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3)); input.tap(); input.typeText(name)
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))
    }
    private func home(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3)) }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testCreateAnswerSummaryAndRelaunchPersistence() {
        let app = launch(); add("朝阳路公寓", app)
        let search = app.textFields["checklist.search"]
        search.tap(); search.typeText("租金")
        let rent = app.textFields["input.f1_6.value"]
        XCTAssertTrue(rent.waitForExistence(timeout: 3)); rent.tap(); rent.typeText("2800")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertEqual(rent.value as? String, "2800")
        capture("11-native-checklist-saved", app)
        app.buttons["tab.总结"].tap()
        app.buttons["summary.考虑租住"].tap()
        let note = app.textViews["summary.note"]; note.tap(); note.typeText("采光好，入住时间待确认")
        app.navigationBars.firstMatch.tap()
        home(app); capture("12-native-home-saved", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.朝阳路公寓"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts["¥ 2800 / 月"].exists)
        house.tap(); XCTAssertTrue(app.buttons["tab.总结"].waitForExistence(timeout: 3)); app.buttons["tab.总结"].tap()
        XCTAssertTrue(app.buttons["summary.考虑租住"].isSelected)
        XCTAssertEqual(app.textViews["summary.note"].value as? String, "采光好，入住时间待确认")
        capture("13-native-summary-restored", app)
    }
    func testCompareThenArchiveReadOnlyAndRestore() {
        let app = launch(); add("第一套", app); app.buttons["tab.总结"].tap(); app.buttons["summary.考虑租住"].tap(); home(app)
        add("第二套", app); home(app)
        app.buttons["tab.对比"].tap()
        let first = app.buttons["compare.select.第一套"]
        XCTAssertTrue(first.waitForExistence(timeout: 3)); first.tap(); app.buttons["compare.select.第二套"].tap()
        app.buttons["compare.start"].tap()
        let differences = app.switches["隐藏相同属性"]; XCTAssertTrue(differences.waitForExistence(timeout: 3)); differences.tap()
        XCTAssertTrue(app.staticTexts["当前意向"].exists); XCTAssertTrue(app.staticTexts["待决定"].exists)
        capture("14-native-comparison", app)
        app.buttons["tab.房源"].tap()
        app.buttons["house.第一套"].press(forDuration: 1)
        let archive = app.buttons["归档"]; XCTAssertTrue(archive.waitForExistence(timeout: 3)); archive.tap()
        XCTAssertFalse(app.buttons["house.第一套"].exists)
        app.buttons["tab.我的"].tap()
        let archives = app.buttons["settings.archive"]; if !archives.isHittable { app.swipeUp() }; archives.tap()
        let open = app.buttons["archive.open.第一套"]; XCTAssertTrue(open.waitForExistence(timeout: 3)); open.tap()
        XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3))
        app.buttons["tab.总结"].tap(); XCTAssertFalse(app.buttons["summary.考虑租住"].isEnabled)
        capture("15-native-archive-readonly", app)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["archive.restore.第一套"].tap(); XCTAssertFalse(app.buttons["archive.open.第一套"].exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.第一套"].waitForExistence(timeout: 10))
    }
    func testManualIssueSaveResolveAndRelaunch() {
        let app = launch(); add("问题检查", app); app.buttons["tab.问题"].tap(); app.buttons["issue.add"].tap()
        let title = app.textFields["issue.title"]; XCTAssertTrue(title.waitForExistence(timeout: 3)); title.tap(); title.typeText("漏水待修")
        let note = app.textViews["issue.note"]; note.tap(); note.typeText("确认修复时间")
        app.buttons["保存"].tap(); XCTAssertTrue(app.buttons["待跟进"].waitForExistence(timeout: 3))
        capture("16-native-manual-issue", app)
        app.buttons["待跟进"].tap(); XCTAssertTrue(app.buttons["已解决"].waitForExistence(timeout: 3))
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.问题检查"].waitForExistence(timeout: 10))
        app.buttons["house.问题检查"].tap(); app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.buttons["已解决"].exists); XCTAssertTrue(app.staticTexts["确认修复时间"].exists)
    }
    func testExportSelectedHousePreparesRealZIPBeforeShare() {
        let app = launch(); add("原生备份房源", app); home(app); app.buttons["tab.我的"].tap()
        let entry = app.buttons["settings.export"]; if !entry.isHittable { app.swipeUp() }; entry.tap()
        let select = app.switches["backup.select.原生备份房源"]; XCTAssertTrue(select.waitForExistence(timeout: 3))
        app.buttons["backup.commit"].tap()
        XCTAssertTrue(app.buttons["backup.share"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["backup.result"].label, "ZIP 已生成，包含 1 套房源及其影像")
        capture("17-native-backup-ready", app)
    }
}
