import XCTest
import Vision

@MainActor final class InspectionBusinessUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10)); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        for message in app.descendants(matching: .any).matching(identifier: "xiaoda.message").allElementsBoundByIndex where message.isHittable {
            let typed = expectation(for: NSPredicate(format: "value == %@", "完整显示"), evaluatedWith: message)
            wait(for: [typed], timeout: 5)
        }
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 130 && element.frame.minY > 105 { return }
            if element.exists && element.frame.minY < 105 { app.scrollViews.firstMatch.swipeDown() }
            else { app.scrollViews.firstMatch.swipeUp() }
        }
        XCTFail("Control not visible: " + element.identifier)
    }
    private func finishSetup(_ app: XCUIApplication, mode: String) {
        app.buttons["setup.next"].tap()
        let choice = app.buttons["setup.mode." + mode]; XCTAssertTrue(choice.waitForExistence(timeout: 3))
        reveal(choice, app); choice.tap(); app.buttons["setup.next"].tap()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 5))
    }
    private func addAndLearn(_ app: XCUIApplication, simple: Bool, verifyGuardAndResume: Bool = false, entryBudget: TimeInterval? = nil) {
        app.homeAddButton.tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3))
        XCTAssertEqual(name.value as? String, "第1套")
        let entryStarted = Date(); app.buttons["prompt.confirm"].tap()
        let title = app.staticTexts["coach.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5)); XCTAssertEqual(title.label, "看房的三个阶段")
        if let entryBudget {
            let elapsed = Date().timeIntervalSince(entryStarted)
            print("PERF first-house-entry-seconds=\(elapsed)")
            XCTAssertLessThan(elapsed, entryBudget, "Opening the first checklist must not spin in a layout update loop")
        }
        capture("business-01-three-phases", app); app.buttons["coach.next"].tap()
        XCTAssertEqual(title.label, "找到你想看的内容"); capture("business-02-filter-teaching", app)
        app.buttons["coach.next"].tap(); XCTAssertEqual(title.label, "向左滑，试试看")
        XCTAssertFalse(app.buttons["coach.next"].exists)
        let row = app.otherElements["mp.field." + (simple ? "simple_01" : "f56_1")].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 3)); XCTAssertTrue(target.isHittable)
        if verifyGuardAndResume {
            let before = target.frame
            target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
            target.press(forDuration: 0.7); target.swipeRight(); target.swipeUp()
            XCTAssertEqual(title.label, "向左滑，试试看")
            XCTAssertEqual(target.frame.minY, before.minY, accuracy: 1)
            XCTAssertFalse(app.buttons["mp.field.action.simple_01.备注"].isHittable)
            XCTAssertFalse(app.buttons["mp.field.choice.simple_01.是"].isSelected)
            XCTAssertFalse(app.buttons["mp.field.choice.simple_01.否"].isSelected)
            app.terminate(); app.launch()
            let house = app.buttons["house.第1套"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
            XCTAssertTrue(target.waitForExistence(timeout: 4)); XCTAssertEqual(title.label, "向左滑，试试看")
        }
        capture("business-03-swipe-teaching", app); target.swipeLeft()
        let step4 = expectation(for: NSPredicate(format: "label == %@", "随手记下房屋细节"), evaluatedWith: title)
        wait(for: [step4], timeout: 4)
        if verifyGuardAndResume {
            app.terminate(); app.launch()
            let house = app.buttons["house.第1套"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
            XCTAssertTrue(title.waitForExistence(timeout: 4)); XCTAssertEqual(title.label, "随手记下房屋细节")
            XCTAssertTrue(app.buttons["mp.field.action.simple_01.备注"].waitForExistence(timeout: 3))
        }
        capture("business-04-swipe-actions", app)
        app.buttons["coach.next"].tap()
        XCTAssertTrue(app.buttons["xiaoda.accept"].waitForExistence(timeout: 4))
        capture("business-05-intro-guidance", app); app.buttons["xiaoda.accept"].tap()
    }
    private func search(_ text: String, _ app: XCUIApplication) {
        let top = app.buttons["回到顶部"]; if top.exists { top.tap() }
        let all = app.buttons["mp.phase.全部"]; reveal(all, app); all.tap()
        let field = app.textFields["mp.checklist.search"]; field.tap()
        if let value = field.value as? String, value != "搜索检查项" && !value.isEmpty { field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)) }
        field.typeText(text); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }
    func testDetailedSwipeGuideTracksVisibleRow() {
        verifySwipeGuideGeometry(mode: "detailed", fieldID: "f56_1")
    }
    func testSimpleSwipeGuideTracksVisibleRow() {
        verifySwipeGuideGeometry(mode: "simple", fieldID: "simple_01")
    }
    func testXiaodaCloseMatchesMiniProgramAndDismissesGuidance() {
        let app = launch()
        finishSetup(app, mode: "simple")
        app.homeAddButton.tap()
        XCTAssertTrue(app.buttons["prompt.confirm"].waitForExistence(timeout: 3))
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        capture("xiaoda-close-prerequisite-phases", app)
        next.tap()
        let filterReady = expectation(for: NSPredicate(format: "label == %@", "找到你想看的内容"), evaluatedWith: app.staticTexts["coach.title"])
        wait(for: [filterReady], timeout: 4)
        capture("xiaoda-close-prerequisite-filters", app)
        next.tap()
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 4)); target.swipeLeft()
        XCTAssertTrue(next.waitForExistence(timeout: 4)); next.tap()

        let close = app.buttons["xiaoda.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 4))
        let bubble = app.otherElements["xiaoda.bubble"].firstMatch
        capture("xiaoda-close-position", app)
        print("XIAODA close=\(close.frame) bubble=\(bubble.frame)")
        XCTAssertTrue(close.isHittable)
        XCTAssertEqual(close.frame.width, 44, accuracy: 1)
        XCTAssertEqual(close.frame.height, 44, accuracy: 1)
        // Mini-program: right -10, top -12, 44 pt hit area, 24 pt top padding.
        XCTAssertEqual(close.frame.midX, bubble.frame.maxX - 12, accuracy: 1)
        XCTAssertEqual(close.frame.midY, bubble.frame.minY - 14, accuracy: 1)
        XCTAssertEqual(close.frame.maxY - bubble.frame.minY, 8, accuracy: 1)
        close.tap()
        let dismissHouse = app.buttons["当前房源关闭"]
        XCTAssertTrue(dismissHouse.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["今天关闭"].exists)
        XCTAssertTrue(app.buttons["永久关闭"].exists)
        capture("xiaoda-close-options", app)
        dismissHouse.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 3))
        XCTAssertFalse(app.buttons["xiaoda.accept"].exists)
        capture("xiaoda-closed-house", app)
        app.navigationBackButton.tap()
        let house = app.buttons["house.第1套"]
        XCTAssertTrue(house.waitForExistence(timeout: 4)); house.tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 4))
        XCTAssertFalse(close.exists)
    }
    private func verifySwipeGuideGeometry(mode: String, fieldID: String) {
        let app = launch()
        finishSetup(app, mode: mode)
        app.homeAddButton.tap()
        XCTAssertTrue(app.buttons["prompt.confirm"].waitForExistence(timeout: 3))
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        capture(mode + "-phase-guide", app)
        XCTAssertTrue(app.buttons["mp.phase.全部"].isHittable)
        XCTAssertTrue(app.buttons["mp.phase.询问签约"].isHittable)
        next.tap()
        capture(mode + "-filter-guide", app)
        for option in ["未记录", "已记录", "有问题", "有备注", "有影像"] {
            XCTAssertTrue(app.buttons[option].isHittable, "The guide must leave every filter option uncovered")
        }
        next.tap()
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 4))
        let row = app.otherElements["mp.field." + fieldID].firstMatch
        let header = app.otherElements["navigation.header"]
        let tab = app.buttons["tab.清单"]
        capture(mode + "-swipe-guide", app)
        assertSwipeSpeechUsesBubbleWidth(app)
        XCTAssertEqual(target.frame.minX, row.frame.minX - 4, accuracy: 1, "Highlight must exclude the row's indentation")
        XCTAssertEqual(target.frame.width, row.frame.width + 8, accuracy: 1)
        XCTAssertEqual(target.frame.minY, row.frame.minY - 4, accuracy: 1)
        XCTAssertGreaterThanOrEqual(target.frame.minY, header.frame.maxY + 12, "Leave room above the highlighted row")
        XCTAssertLessThan(target.frame.maxY, tab.frame.minY)
        let card = app.otherElements["coach.card"]
        XCTAssertEqual(card.frame.minX, 12, accuracy: 1)
        XCTAssertEqual(card.frame.minY - target.frame.maxY, 16, accuracy: 1)
        XCTAssertLessThanOrEqual(card.frame.maxY, tab.frame.minY - 12)
        print("GUIDE \(mode) target=\(target.frame) row=\(row.frame) card=\(card.frame) header=\(header.frame) tab=\(tab.frame)")
        target.tap(); target.swipeRight()
        XCTAssertTrue(target.exists, "Only a left swipe completes teaching")
        target.swipeLeft()
        let title = app.staticTexts["coach.title"]
        let advanced = expectation(for: NSPredicate(format: "label == %@", "随手记下房屋细节"), evaluatedWith: title)
        wait(for: [advanced], timeout: 4)
        let note = app.buttons["mp.field.action." + fieldID + ".备注"]
        XCTAssertTrue(note.isHittable, "The revealed actions remain visible above the guide")
        capture(mode + "-swipe-actions", app)
        XCTAssertEqual(card.frame.minY - row.frame.maxY - 4, 16, accuracy: 1)
        XCTAssertLessThanOrEqual(card.frame.maxY, tab.frame.minY - 12)
        XCTAssertEqual(row.value as? String, "操作已展开")
        print("GUIDE \(mode) actions row=\(row.frame) card=\(card.frame) tab=\(tab.frame)")
    }
    private func assertSwipeSpeechUsesBubbleWidth(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let bubble = app.otherElements["xiaoda.bubble"].firstMatch
        do {
            let image = try XCTUnwrap(bubble.screenshot().image.cgImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans"]
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: image).perform([request])
            let lines = (request.results ?? []).sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                .compactMap { $0.topCandidates(1).first?.string.replacingOccurrences(of: " ", with: "") }
            print("SWIPE SPEECH bubble=\(bubble.frame) lines=\(lines)")
            XCTAssertTrue(lines.first?.contains("在检查项上向左滑一下") == true,
                          "The first line must use the available bubble width without splitting 向左滑一下: \(lines)", file: file, line: line)
        } catch {
            XCTFail("Unable to inspect rendered speech: \(error)", file: file, line: line)
        }
    }
    private func returnHomeWithoutFeedback(_ app: XCUIApplication) {
        app.navigationBackButton.tap()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["关闭反馈"].exists)
    }
    func testFirstSetupResumeRealSwipeSimpleAnswerFeedbackAndCapacity() {
        let app = launch()
        capture("business-welcome-connected", app)
        let toggle = app.buttons["setup.toggle.房源基本信息"]; toggle.tap()
        app.terminate(); app.launch()
        XCTAssertTrue(toggle.waitForExistence(timeout: 10)); XCTAssertEqual(toggle.label, "恢复房源基本信息")
        toggle.tap(); app.buttons["setup.next"].tap()
        app.terminate(); app.launch()
        let simple = app.buttons["setup.mode.simple"]
        XCTAssertTrue(simple.waitForExistence(timeout: 10)); XCTAssertTrue(simple.isSelected)
        capture("business-00-setup-resumed", app); app.buttons["setup.next"].tap()
        XCTAssertTrue(app.buttons["home.first"].waitForExistence(timeout: 5))
        addAndLearn(app, simple: true, verifyGuardAndResume: true); search("生活配套", app)
        let description = app.staticTexts["mp.field.description.simple_02"]; reveal(description, app)
        XCTAssertTrue(description.label.contains("菜市场"))
        XCTAssertLessThanOrEqual(description.frame.maxX, app.frame.maxX - 20)
        XCTAssertGreaterThan(description.frame.height, 20, "The 45-character description must wrap within the checklist")
        let no = app.buttons["mp.field.choice.simple_02.否"]; no.tap(); XCTAssertTrue(no.isSelected)
        let title = app.staticTexts["mp.field.title.simple_02"], left = title.frame.minX
        description.swipeLeft()
        app.buttons["mp.field.action.simple_02.备注"].tap()
        let note = app.textViews["mp.note.text"]; XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap(); note.typeText("附近没有菜市场")
        app.buttons["mp.note.save"].tap()
        XCTAssertTrue(app.buttons["附近没有菜市场"].waitForExistence(timeout: 3)); XCTAssertEqual(title.frame.minX, left, accuracy: 1)
        capture("business-06-simple-description-note", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.第1套"]; XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertFalse(app.buttons["coach.next"].exists); search("生活配套", app)
        XCTAssertTrue(no.isSelected); XCTAssertTrue(app.buttons["附近没有菜市场"].exists)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["关闭反馈"].exists)
        app.buttons["tab.我的"].tap()
        let feedback = app.buttons["settings.feedback"]; reveal(feedback, app); feedback.tap()
        let ease = app.buttons["feedback.ease.方便"]; XCTAssertTrue(ease.waitForExistence(timeout: 4)); ease.tap()
        capture("business-07-feedback-draft", app); app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.第1套"].waitForExistence(timeout: 10))
        XCTAssertFalse(ease.exists)
        app.buttons["tab.我的"].tap(); reveal(feedback, app); feedback.tap()
        XCTAssertTrue(ease.waitForExistence(timeout: 4)); XCTAssertTrue(ease.isSelected)
        app.buttons["关闭反馈"].tap(); app.buttons["tab.房源"].tap()
        let add = app.buttons["home.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 4)); add.tap()
        XCTAssertTrue(app.buttons["capacity.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["capacity.continue"].isEnabled)
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "1 / 1 套")
        capture("business-08-capacity-interruption", app)
    }
    func testDetailedNoneTemplateChangesAndArchivedSnapshot() {
        let app = launch(); finishSetup(app, mode: "detailed"); addAndLearn(app, simple: false, entryBudget: 30)
        search("缺少的家具", app)
        let input = app.textFields["mp.field.input.f54_0"]; reveal(input, app)
        XCTAssertTrue(input.isEnabled); input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "缺少的家具输入框应取得键盘焦点")
        input.typeText("需要衣柜")
        app.buttons["checklist.keyboard.done"].tap()
        let none = app.buttons["mp.field.choice.f54_0.无"]; none.tap()
        XCTAssertTrue(none.isSelected); XCTAssertFalse(input.isEnabled); capture("business-09-missing-furniture-none", app)
        none.tap(); XCTAssertEqual(input.value as? String, "需要衣柜")
        search("免租期", app)
        let rentFree = app.textFields["mp.field.input.f5_3"]
        reveal(rentFree, app); XCTAssertFalse(app.buttons["mp.field.wheel.f5_3"].exists)
        rentFree.tap(); XCTAssertTrue(app.keyboards.keys["9"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.keyboards.keys["."].exists)
        rentFree.typeText("90.5")
        XCTAssertEqual(rentFree.value as? String, "90.5")
        let keyboard = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        keyboard.name = "business-rent-free-system-number-pad"; keyboard.lifetime = .keepAlways; add(keyboard)
        XCTAssertFalse(app.buttons["mp.checklist.capture"].exists, "输入期间悬浮拍照按钮不能遮住无选项")
        let noRent = app.buttons["mp.field.choice.f5_3.无"]
        XCTAssertTrue(noRent.isHittable); noRent.tap()
        XCTAssertTrue(noRent.isSelected); XCTAssertFalse(rentFree.isEnabled)
        if app.buttons["checklist.keyboard.done"].isHittable { app.buttons["checklist.keyboard.done"].tap() }
        XCTAssertTrue(app.buttons["mp.checklist.capture"].waitForExistence(timeout: 3))
        noRent.tap(); XCTAssertEqual(rentFree.value as? String, "90.5")
        app.staticTexts["mp.field.title.f5_3"].swipeLeft()
        app.buttons["mp.field.action.f5_3.标记问题"].tap()
        app.staticTexts["mp.field.title.f5_3"].swipeLeft(); app.buttons["mp.field.action.f5_3.备注"].tap()
        let rentNote = app.textViews["mp.note.text"]; XCTAssertTrue(rentNote.waitForExistence(timeout: 3)); rentNote.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        rentNote.typeText("协商90.5天")
        let entered = expectation(for: NSPredicate(format: "value == %@", "协商90.5天"), evaluatedWith: rentNote)
        wait(for: [entered], timeout: 3)
        capture("business-rent-note-before-save", app)
        app.buttons["mp.note.save"].tap()
        XCTAssertTrue(rentNote.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["协商90.5天"].waitForExistence(timeout: 3))
        app.terminate(); app.launch()
        let savedHouse = app.buttons["house.第1套"]; XCTAssertTrue(savedHouse.waitForExistence(timeout: 10)); savedHouse.tap()
        search("免租期", app)
        XCTAssertEqual(rentFree.value as? String, "90.5"); XCTAssertTrue(app.buttons["协商90.5天"].exists)
        app.buttons["tab.问题"].tap()
        XCTAssertEqual(rentFree.value as? String, "90.5"); XCTAssertTrue(app.buttons["协商90.5天"].exists)
        capture("business-rent-free-issue-restored", app)
        app.buttons["tab.清单"].tap()
        returnHomeWithoutFeedback(app)
        app.buttons["tab.我的"].tap(); let templates = app.buttons["settings.templates"]; reveal(templates, app); templates.tap()
        XCTAssertTrue(app.buttons["setup.mode.detailed"].isSelected)
        let simple = app.buttons["setup.mode.simple"]; reveal(simple, app); simple.tap()
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["templates.stay"].waitForExistence(timeout: 3)); app.buttons["templates.stay"].tap()
        XCTAssertTrue(app.buttons["templates.stay"].waitForNonExistence(timeout: 3))
        let edit = app.buttons["templates.edit.simple"]; reveal(edit, app); edit.tap()
        let toggle = app.buttons["setup.toggle.周边与小区"]; XCTAssertTrue(toggle.waitForExistence(timeout: 3)); toggle.tap()
        app.buttons["template.save"].tap(); app.buttons["templates.confirm"].tap()
        app.buttons["tab.房源"].tap(); let old = app.buttons["house.第1套"]; old.press(forDuration: 1)
        app.confirmArchiveFromHouseMenu(); app.homeAddButton.tap()
        XCTAssertTrue(app.textFields["prompt.text"].waitForExistence(timeout: 3)); app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5)); XCTAssertFalse(app.buttons["coach.next"].exists)
        app.buttons["xiaoda.accept"].tap(); search("生活配套", app)
        XCTAssertTrue(app.staticTexts["没有符合条件的检查项"].exists)
        capture("business-10-new-template-disabled-category", app)
        app.navigationBackButton.tap(); app.buttons["tab.我的"].tap()
        let archive = app.buttons["settings.archive"]; reveal(archive, app); archive.tap()
        app.buttons["archive.open.第1套"].tap(); search("缺少的家具", app)
        XCTAssertEqual(input.value as? String, "需要衣柜"); XCTAssertFalse(input.isEnabled)
        capture("business-11-old-detailed-snapshot", app)
        search("免租期", app)
        XCTAssertEqual(rentFree.value as? String, "90.5"); XCTAssertFalse(rentFree.isEnabled)
        XCTAssertTrue(app.buttons["协商90.5天"].exists)
        capture("business-rent-free-archive-retained", app)
    }
    func testTemplateEdgeScrollAndCompletionLaterRestoresReadingPosition() {
        let app = launch(), scroll = app.scrollViews.firstMatch
        let first = app.descendants(matching: .any).matching(identifier: "setup.drag.房源基本信息").firstMatch
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let edge = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.18, dy: 0.98))
        start.press(forDuration: 0.6, thenDragTo: edge, withVelocity: .slow, thenHoldForDuration: 2)
        let moved = app.staticTexts["setup.title.房源基本信息"], last = app.staticTexts["setup.title.身份与合同"]
        XCTAssertTrue(last.isHittable); XCTAssertGreaterThan(moved.frame.minY, last.frame.minY)
        capture("business-12-template-edge-scroll", app)
        finishSetup(app, mode: "simple"); addAndLearn(app, simple: true)
        search("室内环境", app)
        for id in ["simple_11", "simple_12", "simple_13"] {
            let yes = app.buttons["mp.field.choice." + id + ".是"]; reveal(yes, app); yes.tap()
        }
        let lastYes = app.buttons["mp.field.choice.simple_49.是"]; reveal(lastYes, app)
        let label = app.staticTexts["mp.field.title.simple_49"], before = label.frame.minY
        lastYes.tap()
        let later = app.buttons["xiaoda.later"]; XCTAssertTrue(later.waitForExistence(timeout: 5))
        capture("business-13-completion-guidance", app); later.tap()
        XCTAssertTrue(later.waitForNonExistence(timeout: 3))
        let position = expectation(for: NSPredicate { _, _ in abs(label.frame.minY - before) < 2 }, evaluatedWith: label)
        wait(for: [position], timeout: 3)
        capture("business-14-later-keeps-position", app)
        lastYes.tap(); lastYes.tap()
        XCTAssertFalse(app.buttons["xiaoda.later"].exists)
    }

}
