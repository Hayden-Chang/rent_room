import XCTest

@MainActor final class PixelParityAuditTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(fixture: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if fixture { app.launchArguments.append("--pixel-parity-fixture") }
        app.launch()
        XCTAssertTrue(app.buttons["tab.我的"].waitForExistence(timeout: 10))
        return app
    }
    private func shot(_ name: String, _ app: XCUIApplication) {
        let ids = ["home.add", "house.阳光小区", "house.新城公寓", "tab.房源", "tab.对比", "tab.我的", "tab.清单", "tab.影像", "tab.问题", "tab.总结", "local-settings.capacity", "local-settings.archive", "local-settings.templates", "local-settings.workplace", "local-settings.export", "capacity.total", "capacity.title", "capacity.purchase", "templates.confirm", "template.save", "prompt.text", "prompt.confirm", "backup.commit", "backup.share", "issueEditor.title", "issueEditor.save", "xiaoda.message"]
        var geometry: [[String: Any]] = []
        func collect(_ element: XCUIElementSnapshot) {
            if ids.contains(element.identifier) {
                let frame = element.frame
                geometry.append(["id": element.identifier, "label": element.label, "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height])
            }
            element.children.forEach(collect)
        }
        if let snapshot = try? app.snapshot() { collect(snapshot) }
        if let data = try? JSONSerialization.data(withJSONObject: geometry, options: [.prettyPrinted, .sortedKeys]) {
            let bounds = XCTAttachment(data: data, uniformTypeIdentifier: "public.json"); bounds.name = "pixel-" + name + "-geometry"; bounds.lifetime = .keepAlways; add(bounds)
        }
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "pixel-" + name; shot.lifetime = .keepAlways; add(shot)
    }

    private func tap(_ id: String, _ app: XCUIApplication) {
        let b = app.buttons[id]
        for _ in 0..<5 { if b.exists && b.isHittable { b.tap(); return }; app.swipeUp() }
        XCTFail("Missing visible button: " + id)
    }
    private func back(_ app: XCUIApplication) { app.navigationBackButton.tap() }
    func testReferencePagesAndArchivedState() {
        let app = launch()
        XCTAssertTrue(app.buttons["house.阳光小区"].exists); shot("01-home", app)
        app.buttons["house.阳光小区"].tap(); XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 3)); shot("11-fixture-detail", app)
        let category = app.otherElements["mp.field.node:category:房源基本信息"].firstMatch
        XCTAssertEqual(category.frame.height, 60, accuracy: 0.5, "Match the rendered mini-program category row, including the inline padding override")
        back(app)
        app.buttons["tab.对比"].tap(); shot("02-compare", app)
        app.buttons["compare.select.阳光小区"].tap(); app.buttons["compare.select.新城公寓"].tap()
        app.buttons["compare.start"].tap(); XCTAssertTrue(app.switches["隐藏相同属性"].waitForExistence(timeout: 3)); shot("02b-compare-results", app)
        app.buttons["tab.我的"].tap(); shot("03-settings", app)
        tap("local-settings.archive", app); XCTAssertTrue(app.buttons["archive.open.已归档房源"].waitForExistence(timeout: 3)); shot("04-archive", app)
        app.buttons["archive.open.已归档房源"].tap(); XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3)); shot("04b-archive-readonly", app); back(app); back(app)
        tap("local-settings.templates", app); XCTAssertTrue(app.buttons["templates.confirm"].waitForExistence(timeout: 3)); shot("05-templates", app)
        app.buttons["templates.edit.simple"].tap(); XCTAssertTrue(app.buttons["template.save"].waitForExistence(timeout: 3)); shot("06-template-simple", app); back(app)
        app.buttons["templates.edit.detailed"].tap(); XCTAssertTrue(app.buttons["template.save"].waitForExistence(timeout: 3)); shot("07-template-detailed", app); back(app); back(app)
        tap("local-settings.workplace", app); XCTAssertTrue(app.textFields["workplace.address"].waitForExistence(timeout: 3)); shot("10-workplace", app); back(app)
        tap("local-settings.export", app); XCTAssertTrue(app.buttons["backup.share"].waitForExistence(timeout: 10)); shot("14-export", app); back(app)
        tap("local-settings.importFile", app)
        dismissImportPicker(app)
        XCTAssertTrue(app.buttons["选择 ZIP 文件"].waitForExistence(timeout: 3)); shot("15-import-empty", app); back(app)
        tap("local-settings.feedback", app)
        XCTAssertTrue(app.buttons["feedback.ease.方便"].waitForExistence(timeout: 3)); shot("16-feedback", app)
        app.buttons["关闭反馈"].tap()
        for _ in 0..<3 { app.swipeDown() }
        tap("local-settings.capacity", app); XCTAssertTrue(app.buttons["capacity.purchase"].waitForExistence(timeout: 3))
        let message = app.staticTexts["xiaoda.message"]
        if message.exists { let complete = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message); wait(for: [complete], timeout: 5) }
        shot("09-capacity", app)
    }
    private func dismissImportPicker(_ app: XCUIApplication) {
        let bar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        bar.buttons["取消"].tap()
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5))
        let back = app.buttons["navigation.back"].firstMatch
        let ready = expectation(for: NSPredicate(format: "exists == true AND hittable == true"), evaluatedWith: back)
        wait(for: [ready], timeout: 5)
    }
    func testImportPickerCancellationReturnsToSettings() {
        let app = launch()
        app.buttons["tab.我的"].tap(); tap("local-settings.importFile", app)
        dismissImportPicker(app)
        XCTAssertTrue(app.buttons["选择 ZIP 文件"].exists)
        shot("15-import-empty", app)
        app.buttons["选择 ZIP 文件"].tap()
        dismissImportPicker(app)
        app.buttons["navigation.back"].tap()
        XCTAssertTrue(app.buttons["local-settings.importFile"].waitForExistence(timeout: 3))
    }
    func testNamingAndDetailTabGeometry() {
        let app = launch(fixture: false)
        app.buttons["home.add"].tap(); XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3))
        let message = app.staticTexts["xiaoda.message"]
        if message.exists { let complete = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message); wait(for: [complete], timeout: 5) }
        XCTAssertEqual(app.buttons["prompt.confirm"].label, "创建房源"); shot("08-new-house", app)
        app.textFields["prompt.text"].replacePromptText("阳光小区"); app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.影像"].waitForExistence(timeout: 5)); XCTAssertEqual(app.buttons["tab.影像"].label, "影像 0")
        shot("11-detail", app)
        app.buttons["tab.影像"].tap(); shot("11b-media-empty", app)
        let capture = app.buttons["media.add"]
        XCTAssertEqual(capture.frame.width, 52, accuracy: 0.5)
        XCTAssertEqual(capture.frame.height, 52, accuracy: 0.5)
        capture.tap()
        XCTAssertTrue(app.buttons["从相册选择照片或视频"].waitForExistence(timeout: 3))
        app.buttons["取消"].tap()
        XCTAssertTrue(app.buttons["从相册选择照片或视频"].waitForNonExistence(timeout: 3))
        shot("11b-media-after-source", app)
        app.buttons["tab.问题"].tap(); shot("11c-issues-empty", app)
        app.buttons["issue.add"].tap(); XCTAssertTrue(app.textFields["issueEditor.title"].waitForExistence(timeout: 3)); shot("12-issue", app)
        app.buttons["issueEditor.cancel"].tap(); app.buttons["tab.总结"].tap(); shot("11d-summary", app)
    }
}
