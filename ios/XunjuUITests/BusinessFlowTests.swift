import XCTest

@MainActor final class BusinessFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(mediaFixture: Bool = false, twoRooms: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if twoRooms { app.launchArguments.append("--two-room-policy-fixture") }
        if mediaFixture { app.launchArguments.append("--media-import-fixture") }
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); return app
    }
    private func add(_ name: String, _ app: XCUIApplication) {
        app.buttons["home.add"].tap()
        let input = app.textFields["prompt.text"]
        XCTAssertTrue(input.waitForExistence(timeout: 3)); input.replacePromptText(name)
        app.buttons["prompt.confirm"].tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 5))

    }
    private func home(_ app: XCUIApplication) { app.navigationBackButton.tap(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3)) }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; add(a)
    }
    func testCreateAnswerSummaryAndRelaunchPersistence() {
        let app = launch(); add("朝阳路公寓", app)
        let search = app.textFields["mp.checklist.search"]
        search.tap(); search.typeText("租金")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        let rent = app.textFields["mp.field.input.f1_6"]
        XCTAssertTrue(rent.waitForExistence(timeout: 3)); rent.tap(); rent.typeText("2800")
        app.buttons["完成"].firstMatch.tap()
        XCTAssertEqual(rent.value as? String, "2800")
        app.otherElements["mp.field.f1_6"].firstMatch.swipeLeft(); app.buttons["备注"].firstMatch.tap()
        let fieldNote = app.textViews["mp.note.text"]
        XCTAssertTrue(fieldNote.waitForExistence(timeout: 3)); fieldNote.tap(); fieldNote.typeText("含物业费")
        XCTAssertFalse(app.buttons["tab.清单"].isHittable, "The note modal must cover and block detail tabs")
        let saveNote = app.buttons["mp.note.save"]
        XCTAssertLessThanOrEqual(fieldNote.frame.maxY, saveNote.frame.minY)
        XCTAssertLessThanOrEqual(saveNote.frame.maxY, app.keyboards.firstMatch.frame.minY)
        capture("11a-native-field-note", app)
        app.buttons["保存备注"].tap()
        XCTAssertTrue(app.buttons["含物业费"].waitForExistence(timeout: 3))
        app.scrollViews.firstMatch.swipeDown()
        capture("11-native-checklist-saved", app)
        app.buttons["tab.总结"].tap()
        app.buttons["summary.考虑租住"].tap()
        let note = app.textViews["summary.note"]; note.tap(); note.typeText("采光好，入住时间待确认")
        app.dismissKeyboardFromHeader()
        home(app); capture("12-native-home-saved", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.朝阳路公寓"]
        XCTAssertTrue(house.waitForExistence(timeout: 10)); XCTAssertTrue(app.staticTexts["¥ 2800 / 月"].exists)
        house.tap(); XCTAssertTrue(app.buttons["tab.总结"].waitForExistence(timeout: 3)); app.buttons["tab.总结"].tap()
        XCTAssertTrue(app.buttons["summary.考虑租住"].isSelected)
        XCTAssertEqual(app.textViews["summary.note"].value as? String, "采光好，入住时间待确认")
        capture("13-native-summary-restored", app)
        app.buttons["tab.清单"].tap()
        let restoredSearch = app.textFields["mp.checklist.search"]; restoredSearch.tap(); restoredSearch.typeText("租金")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.buttons["含物业费"].exists)
    }
    func testHouseActionMenuRenameAndArchiveCancellation() {
        let app = launch(); add("待改名房源", app); home(app)
        app.buttons["house.待改名房源"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["重命名"].waitForExistence(timeout: 3)); capture("pixel-17-home-actions", app)
        app.buttons["重命名"].tap()
        let name = app.textFields["mp.prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("改名房源")
        capture("pixel-17b-rename", app)
        app.buttons["mp.prompt.save"].tap()
        let house = app.buttons["house.改名房源"]
        XCTAssertTrue(house.waitForExistence(timeout: 3)); house.press(forDuration: 1)
        app.buttons["归档房源"].tap()
        XCTAssertTrue(app.buttons["mp.confirm.cancel"].waitForExistence(timeout: 3)); capture("pixel-17c-archive-confirm", app)
        app.buttons["mp.confirm.cancel"].tap(); XCTAssertTrue(house.waitForExistence(timeout: 3))
        app.terminate(); app.launch(); XCTAssertTrue(house.waitForExistence(timeout: 10))
    }
    func testCompareThenArchiveReadOnlyAndRestore() {
        let app = launch(twoRooms: true); add("第一套", app); app.buttons["tab.总结"].tap(); app.buttons["summary.考虑租住"].tap(); home(app)
        add("第二套", app); home(app)
        app.buttons["tab.对比"].tap()
        let first = app.buttons["compare.select.第一套"]
        XCTAssertTrue(first.waitForExistence(timeout: 3)); first.tap(); app.buttons["compare.select.第二套"].tap()
        XCTAssertTrue(app.buttons["compare.start"].isEnabled)
        XCTAssertEqual(app.buttons["compare.start"].label, "对比这 2 套房源")
        capture("14a-native-comparison-selection", app)
        app.buttons["compare.start"].tap()
        let differences = app.switches["隐藏相同属性"]; XCTAssertTrue(differences.waitForExistence(timeout: 3)); differences.tap()
        XCTAssertTrue(app.staticTexts["当前意向"].exists); XCTAssertTrue(app.staticTexts["待决定"].exists)
        capture("14-native-comparison", app)
        app.buttons["tab.房源"].tap()
        app.buttons["house.第一套"].press(forDuration: 1)
        app.confirmArchiveFromHouseMenu()
        XCTAssertFalse(app.buttons["house.第一套"].exists)
        app.buttons["tab.我的"].tap()
        let archives = app.buttons["settings.archive"]; if !archives.isHittable { app.swipeUp() }; archives.tap()
        let open = app.buttons["archive.open.第一套"]; XCTAssertTrue(open.waitForExistence(timeout: 3)); open.tap()
        XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3))
        app.buttons["tab.总结"].tap(); XCTAssertFalse(app.buttons["summary.考虑租住"].isEnabled)
        capture("15-native-archive-readonly", app)
        app.navigationBackButton.tap()
        app.buttons["archive.open.第一套"].press(forDuration: 1); app.buttons["archive.restore.第一套"].tap(); XCTAssertFalse(app.buttons["archive.open.第一套"].exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.第一套"].waitForExistence(timeout: 10))
    }
    func testManualIssueSaveResolveAndRelaunch() {
        let app = launch(); add("问题检查", app); app.buttons["tab.问题"].tap(); app.buttons["issue.add"].tap()
        let title = app.textFields["issueEditor.title"]; XCTAssertTrue(title.waitForExistence(timeout: 3)); title.tap(); title.typeText("漏水待修")
        let note = app.textViews["issueEditor.note"]; note.tap(); note.typeText("确认修复时间")
        app.buttons["完成"].tap()
        capture("16a-native-issue-editor", app)
        app.buttons["issueEditor.save"].tap(); XCTAssertTrue(app.buttons["待跟进"].waitForExistence(timeout: 3))
        capture("16-native-manual-issue", app)
        app.buttons["待跟进"].tap(); XCTAssertTrue(app.buttons["已解决"].waitForExistence(timeout: 3))
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.问题检查"].waitForExistence(timeout: 10))
        app.buttons["house.问题检查"].tap(); app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.buttons["已解决"].exists); XCTAssertTrue(app.buttons["确认修复时间"].exists)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        // SwiftUI may report clipped content behind the inset tab/footer as
        // hittable. Bring the whole control into the actual content area first.
        let top = app.navigationHeader.frame.maxY + 12
        let bottom = app.buttons["issueEditor.save"].exists ? app.buttons["issueEditor.save"].frame.minY - 12
            : app.buttons["tab.清单"].exists ? app.buttons["tab.清单"].frame.minY - 64 : app.frame.maxY - 96
        for _ in 0..<5 {
            if element.exists {
                let frame = element.frame
                if element.isHittable && frame.minY >= top && frame.maxY <= bottom { return }
                if frame.minY < top { app.scrollViews.firstMatch.swipeDown(); continue }
            }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTFail("Control was not fully visible above the tab/footer: " + element.identifier)
    }
    private func importFixture(_ kind: String, _ app: XCUIApplication) {
        let addMedia = app.buttons["issueEditor.addMedia"]; reveal(addMedia, app); addMedia.tap()
        let source = app.buttons["media.fixture." + kind]; XCTAssertTrue(source.waitForExistence(timeout: 3)); source.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: source)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }
    private func buttons(_ prefix: String, _ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }
    private func closePreview(_ app: XCUIApplication) {
        let close = app.buttons["media.preview.close"]; close.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: close)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
    }
    func testIssueMediaSaveDiscardCaptionAndRelaunch() {
        let app = launch(mediaFixture: true); add("影像业务", app)
        app.buttons["tab.问题"].tap(); app.buttons["issue.add"].tap()
        let title = app.textFields["issueEditor.title"]; XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap(); title.typeText("窗框渗水"); app.buttons["完成"].tap()
        importFixture("image", app); importFixture("video", app)
        XCTAssertEqual(buttons("issueEditor.remove.", app).count, 2)
        let photo = buttons("issueEditor.preview.", app).firstMatch; reveal(photo, app); photo.tap()
        XCTAssertTrue(app.images["issueEditor.previewImage"].waitForExistence(timeout: 3)); app.buttons["关闭"].tap()
        capture("63-business-issue-media-draft", app)
        let video = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "issueEditor.video.")).firstMatch
        reveal(video, app); capture("70-business-issue-video-file", app)
        app.buttons["issueEditor.save"].tap()
        XCTAssertTrue(app.buttons["窗框渗水"].waitForExistence(timeout: 3))
        let cardPhoto = buttons("manualIssue.", app).matching(NSPredicate(format: "identifier CONTAINS %@", ".preview.")).firstMatch
        reveal(cardPhoto, app); cardPhoto.tap()
        XCTAssertTrue(app.images["media.preview.image"].waitForExistence(timeout: 3)); closePreview(app)
        let cardVideo = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'manualIssue.' AND identifier CONTAINS '.video.'")).firstMatch
        reveal(cardVideo, app)
        let play = app.buttons["Play/Pause"]
        if play.isHittable { play.tap() } else { cardVideo.tap() }
        let playing = expectation(for: NSPredicate(format: "label IN %@", ["Pause", "暂停"]), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
        XCTAssertFalse(app.textFields["issueEditor.title"].exists)
        capture("78-business-manual-card-video", app)
        app.buttons["tab.影像"].tap()
        XCTAssertEqual(buttons("gallery.preview.", app).count, 2)
        capture("64-business-three-column-gallery", app)
        buttons("gallery.caption.", app).element(boundBy: 0).tap()
        let caption = app.textViews["note.text"]; XCTAssertTrue(caption.waitForExistence(timeout: 3))
        caption.tap(); caption.typeText("雨后复查窗框"); app.buttons["保存备注"].tap()
        XCTAssertTrue(app.buttons["雨后复查窗框"].waitForExistence(timeout: 3))
        app.buttons["gallery.filter.视频"].tap(); XCTAssertEqual(buttons("gallery.preview.", app).count, 1)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.影像业务"].waitForExistence(timeout: 10)); app.buttons["house.影像业务"].tap()
        app.buttons["tab.影像"].tap(); XCTAssertEqual(buttons("gallery.preview.", app).count, 2)
        XCTAssertTrue(app.buttons["雨后复查窗框"].exists)
        app.buttons["tab.问题"].tap(); app.buttons["窗框渗水"].tap()
        let remove = buttons("issueEditor.remove.", app).element(boundBy: 0); reveal(remove, app); remove.tap()
        app.buttons["issueEditor.cancel"].tap(); app.alerts["放弃修改？"].buttons["放弃"].tap()
        XCTAssertTrue(app.buttons["窗框渗水"].waitForExistence(timeout: 3)); app.buttons["窗框渗水"].tap()
        XCTAssertEqual(buttons("issueEditor.remove.", app).count, 2)
        capture("65-business-issue-media-restored", app)
        app.buttons["issueEditor.cancel"].tap()
        XCTAssertTrue(app.buttons["issue.add"].waitForExistence(timeout: 3)); app.buttons["issue.add"].tap()
        title.tap(); title.typeText("放弃的新问题"); app.buttons["完成"].tap(); importFixture("image", app)
        app.buttons["issueEditor.cancel"].tap(); app.alerts["放弃修改？"].buttons["放弃"].tap()
        XCTAssertTrue(app.buttons["issue.add"].waitForExistence(timeout: 3)); XCTAssertFalse(app.buttons["放弃的新问题"].exists)
        app.buttons["tab.影像"].tap(); XCTAssertEqual(buttons("gallery.preview.", app).count, 2)
        home(app); app.buttons["house.影像业务"].press(forDuration: 1)
        app.confirmArchiveFromHouseMenu()
        app.buttons["tab.我的"].tap(); let archives = app.buttons["settings.archive"]; reveal(archives, app); archives.tap()
        let open = app.buttons["archive.open.影像业务"]; XCTAssertTrue(open.waitForExistence(timeout: 3)); open.tap()
        app.buttons["tab.影像"].tap(); XCTAssertFalse(app.buttons["拍照或录视频"].exists)
        XCTAssertEqual(buttons("gallery.caption.", app).count, 1)
        app.buttons["tab.问题"].tap(); app.buttons["窗框渗水"].tap()
        XCTAssertTrue(app.staticTexts["房源已归档，问题只读"].waitForExistence(timeout: 3))
        XCTAssertFalse(title.isEnabled); XCTAssertFalse(app.buttons["issueEditor.save"].exists)
        XCTAssertEqual(buttons("issueEditor.remove.", app).count, 0)
        capture("69-business-archived-issue-media", app)
    }
    private func importRelated(_ kind: String, row: XCUIElement, _ app: XCUIApplication) {
        reveal(row, app); row.swipeLeft()
        let capture = row.buttons["拍摄"]; XCTAssertTrue(capture.waitForExistence(timeout: 3)); capture.tap()
        let source = app.buttons["media.fixture." + kind]; XCTAssertTrue(source.waitForExistence(timeout: 3)); source.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: source)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
    }
    func testAutomaticIssueInlineEditingRelatedFilesAndRelaunch() {
        let app = launch(mediaFixture: true); add("自动问题影像", app)
        let query = app.textFields["mp.checklist.search"]; query.tap(); query.typeText("纱窗"); app.buttons["checklist.keyboard.done"].tap()
        let row = app.otherElements["mp.field.f38_result"].firstMatch; reveal(row, app)
        app.buttons["mp.field.choice.f38_result.是"].tap()
        row.swipeLeft(); row.buttons["标记问题"].tap()
        row.swipeLeft(); row.buttons["备注"].tap()
        let note = app.textViews["mp.note.text"]; XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap(); note.typeText("雨后再查纱窗")
        app.buttons["保存备注"].tap()
        for kind in ["image", "video", "image", "image"] { importRelated(kind, row: row, app) }
        let strip = app.otherElements["related.f38_result"].firstMatch; reveal(strip, app)
        let firstIDs = strip.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'related.preview.'")).allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(firstIDs.count, 3); XCTAssertTrue(strip.buttons["related.all"].exists)
        capture("79-business-checklist-related-files", app)
        app.buttons["tab.问题"].tap()
        XCTAssertTrue(app.buttons["mp.field.choice.f38_result.是"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["mp.field.choice.f38_result.是"].isSelected)
        XCTAssertTrue(app.buttons["雨后再查纱窗"].exists)
        app.buttons["mp.field.choice.f38_result.否"].tap()
        XCTAssertTrue(app.buttons["mp.field.choice.f38_result.否"].isSelected)
        let autoStrip = app.otherElements["related.f38_result"].firstMatch
        autoStrip.buttons[firstIDs[0]].tap(); XCTAssertTrue(app.images["media.preview.image"].waitForExistence(timeout: 3)); closePreview(app)
        autoStrip.buttons[firstIDs[1]].tap()
        let video = app.descendants(matching: .any)["media.preview.video"].firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 3))
        let play = app.buttons["Play/Pause"]
        if play.isHittable { play.tap() } else { video.tap() }
        let playing = expectation(for: NSPredicate(format: "label IN %@", ["Pause", "暂停"]), evaluatedWith: play)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
        capture("80-business-related-video-preview", app); closePreview(app)
        autoStrip.buttons["related.all"].tap()
        let gallery = buttons("gallery.preview.", app); XCTAssertEqual(gallery.count, 4)
        XCTAssertEqual(gallery.allElementsBoundByIndex.prefix(3).map { $0.identifier.replacingOccurrences(of: "gallery.preview.", with: "") }, firstIDs.map { $0.replacingOccurrences(of: "related.preview.", with: "") })
        gallery.element(boundBy: 3).tap(); XCTAssertTrue(app.images["media.preview.image"].waitForExistence(timeout: 3)); closePreview(app)
        buttons("gallery.caption.", app).element(boundBy: 3).tap()
        let mediaNote = app.textViews["note.text"]
        XCTAssertTrue(mediaNote.waitForExistence(timeout: 3)); mediaNote.tap(); mediaNote.typeText("纱窗第四张")
        app.buttons["保存备注"].tap(); XCTAssertTrue(app.buttons["纱窗第四张"].waitForExistence(timeout: 3))
        capture("81-business-related-all-caption", app)
        app.buttons["gallery.filter.视频"].tap(); XCTAssertEqual(gallery.count, 1); app.buttons["related.gallery.close"].tap()
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.自动问题影像"].waitForExistence(timeout: 10)); app.buttons["house.自动问题影像"].tap()
        app.buttons["tab.问题"].tap(); XCTAssertTrue(app.buttons["mp.field.choice.f38_result.否"].isSelected); XCTAssertTrue(app.buttons["雨后再查纱窗"].exists)
        app.buttons["mp.field.choice.f38_result.是"].tap(); XCTAssertTrue(app.buttons["mp.field.choice.f38_result.是"].isSelected)
        autoStrip.buttons["related.all"].tap(); XCTAssertEqual(gallery.count, 4); XCTAssertTrue(app.buttons["纱窗第四张"].exists)
        app.buttons["related.gallery.close"].tap(); capture("82-business-automatic-issue-restored", app)
    }
    func testAutomaticNumericZeroAndArchiveReadOnly() {
        let app = launch(); add("自动数值问题", app)
        let query = app.textFields["mp.checklist.search"]; query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        let row = app.otherElements["mp.field.f1_6"].firstMatch; reveal(row, app); row.swipeLeft(); row.buttons["标记问题"].tap()
        app.buttons["tab.问题"].tap()
        let rent = app.textFields["mp.field.input.f1_6"]; XCTAssertTrue(rent.waitForExistence(timeout: 3)); rent.tap(); rent.typeText("0")
        app.buttons["issues.keyboard.done"].tap(); XCTAssertEqual(rent.value as? String, "0")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.自动数值问题"].waitForExistence(timeout: 10)); app.buttons["house.自动数值问题"].tap()
        app.buttons["tab.问题"].tap(); XCTAssertEqual(rent.value as? String, "0"); capture("83-business-automatic-numeric-restored", app)
        home(app); app.buttons["house.自动数值问题"].press(forDuration: 1)
        app.confirmArchiveFromHouseMenu()
        app.buttons["tab.我的"].tap(); let archives = app.buttons["settings.archive"]; reveal(archives, app); archives.tap()
        let open = app.buttons["archive.open.自动数值问题"]; XCTAssertTrue(open.waitForExistence(timeout: 3)); open.tap()
        query.tap(); query.typeText("租金"); app.buttons["checklist.keyboard.done"].tap()
        let category = app.staticTexts["mp.field.title.node:category:房源基本信息"]
        XCTAssertEqual(category.value as? String, "已展开")
        category.tap(); XCTAssertEqual(category.value as? String, "已折叠"); XCTAssertFalse(rent.exists)
        capture("readonly-checklist-collapsed", app)
        category.tap(); XCTAssertEqual(rent.value as? String, "0"); XCTAssertFalse(rent.isEnabled)
        capture("readonly-checklist-expanded", app)
        app.buttons["tab.问题"].tap(); XCTAssertEqual(rent.value as? String, "0"); XCTAssertFalse(rent.isEnabled)
        app.otherElements["mp.field.f1_6"].firstMatch.swipeLeft(); XCTAssertFalse(app.buttons["标记问题"].exists)
        capture("84-business-automatic-numeric-readonly", app)
    }
    func testHeadingSwipeNotesAbsenceAndRelaunchPreserveDetails() {
        let app = launch(); add("分组业务", app)
        let query = app.textFields["mp.checklist.search"]; query.tap(); query.typeText("停车"); app.buttons["checklist.keyboard.done"].tap()
        let fee = app.textFields["mp.field.input.f11_1"]; reveal(fee, app); fee.tap(); fee.typeText("150"); app.buttons["checklist.keyboard.done"].tap()
        let groupID = "node:group:topic_11", categoryID = "node:category:周边与小区"
        app.scrollViews.firstMatch.swipeDown()
        let category = app.staticTexts["mp.field.title." + categoryID]; XCTAssertTrue(category.isHittable); category.swipeLeft()
        XCTAssertTrue(app.buttons["mp.field.action." + categoryID + ".备注"].waitForExistence(timeout: 3)); capture("66-business-category-swipe", app)
        let group = app.staticTexts["mp.field.title." + groupID]; reveal(group, app); group.tap()
        XCTAssertEqual(group.value as? String, "已展开")
        group.swipeLeft(); app.buttons["mp.field.action." + groupID + ".标记问题"].tap()
        group.swipeLeft(); app.buttons["mp.field.action." + groupID + ".备注"].tap()
        let note = app.textViews["mp.note.text"]; XCTAssertTrue(note.waitForExistence(timeout: 3))
        capture("66b-business-note-surface", app)
        note.tap(); note.typeText("核实固定"); note.typeText("车位"); XCTAssertEqual(note.value as? String, "核实固定车位")
        capture("66c-business-note-editing", app)
        app.buttons["保存备注"].tap(); XCTAssertTrue(app.buttons["核实固定车位"].waitForExistence(timeout: 3))
        let absence = app.buttons["mp.field.choice." + groupID + ".不涉及"]; reveal(absence, app); absence.tap()
        XCTAssertTrue(absence.isSelected); XCTAssertEqual(fee.value as? String, "150", "停车费用在费用与付款中独立保留"); capture("67-business-group-not-applicable", app)
        absence.tap(); reveal(fee, app); XCTAssertEqual(fee.value as? String, "150")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.分组业务"].waitForExistence(timeout: 10)); app.buttons["house.分组业务"].tap()
        query.tap(); query.typeText("停车"); app.buttons["checklist.keyboard.done"].tap()
        let hidden = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 3), .completed, "Search keyboard must dismiss before inspecting restored fields")
        reveal(fee, app); XCTAssertEqual(fee.value as? String, "150"); XCTAssertTrue(app.buttons["核实固定车位"].exists)
        reveal(group, app); group.swipeLeft(); XCTAssertTrue(app.buttons["mp.field.action." + groupID + ".取消问题"].exists)
        capture("68-business-group-restored", app)
    }
    func testCapacityInterruptionKeepsExistingHouse() {
        let app = launch(); add("容量一", app); home(app)
        app.buttons["home.add"].tap()
        XCTAssertTrue(app.staticTexts["capacity.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["capacity.total"].label, "1 / 1 套")
        XCTAssertFalse(app.buttons["capacity.continue"].isEnabled)
        XCTAssertFalse(app.textFields["prompt.text"].exists)
        capture("20-native-capacity-interruption", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["house.容量一"].waitForExistence(timeout: 3))
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.容量一"].waitForExistence(timeout: 10))
    }
    func testMediaSourceMenuMatchesMiniProgramFromAllEntryPoints() {
        let app = launch(); add("来源菜单检查", app)
        let menu = app.otherElements["media.source"]
        let library = app.buttons["从相册选择照片或视频"]
        let camera = menu.buttons["拍照或录视频"]
        func checkMenu(_ name: String) {
            XCTAssertTrue(library.waitForExistence(timeout: 3))
            capture(name, app)
            XCTAssertFalse(app.navigationBars["添加影像"].exists, "Source selection must be a compact bottom menu, not a separate page")
            XCTAssertGreaterThan(library.frame.minY, app.frame.height * 0.6)
            XCTAssertEqual(camera.frame.midY - library.frame.midY, 54, accuracy: 1)
            XCTAssertEqual(menu.buttons["取消"].frame.midY - camera.frame.midY, 62, accuracy: 1)
            XCTAssertTrue(menu.buttons["取消"].exists)
            XCTAssertFalse(app.staticTexts["单个影像不超过 50 MiB"].exists)
        }
        app.buttons["mp.checklist.capture"].tap(); checkMenu("media-source-checklist")
        menu.buttons["取消"].tap(); XCTAssertTrue(library.waitForNonExistence(timeout: 3))
        app.buttons["tab.影像"].tap(); app.buttons["media.add"].tap(); checkMenu("media-source-gallery")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 3), "Tapping the dimmed area dismisses the menu")
        XCTAssertTrue(app.staticTexts["还没有影像"].exists)
        app.buttons["tab.问题"].tap(); app.buttons["issue.add"].tap()
        let addMedia = app.buttons["issueEditor.addMedia"]; reveal(addMedia, app); addMedia.tap()
        checkMenu("media-source-issue")
        camera.tap()
        let unavailable = app.alerts["无法添加影像"]
        let cameraClose = app.buttons["DismissImagePickerButton"]
        _ = unavailable.waitForExistence(timeout: 2)
        if cameraClose.exists {
            XCTAssertTrue(cameraClose.isHittable)
            capture("media-source-system-camera", app); cameraClose.tap()
            XCTAssertTrue(cameraClose.waitForNonExistence(timeout: 3))
        } else if unavailable.exists {
            XCTAssertTrue(unavailable.staticTexts["当前设备没有可用相机"].exists)
            capture("media-source-camera-unavailable", app); unavailable.buttons["知道了"].tap()
        } else {
            // iOS 18 simulator camera renders the native cancel control but
            // returns an empty remote accessibility tree. Grounded in run-09's
            // screen recording: Cancel is at 8% width / 91% height.
            capture("media-source-system-camera-remote", app)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.91)).tap()
        }
        XCTAssertTrue(library.waitForExistence(timeout: 5))
        XCTAssertTrue(library.isHittable)
        menu.buttons["取消"].tap(); XCTAssertTrue(library.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.textFields["issueEditor.title"].exists)
        XCTAssertEqual(buttons("issueEditor.remove.", app).count, 0)
    }
    func testMediaEmptyStateAndSystemPickerCanCancel() {
        let app = launch(); add("影像检查", app); app.buttons["tab.影像"].tap()
        XCTAssertTrue(app.staticTexts["还没有影像"].exists)
        app.buttons["media.add"].tap()
        let library = app.buttons["从相册选择照片或视频"]
        XCTAssertTrue(library.waitForExistence(timeout: 3)); capture("18-native-media-source", app)
        library.tap()
        let cancel = app.navigationBars["照片"].buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); XCTAssertTrue(cancel.isHittable)
        capture("19-native-system-photo-picker", app); cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 3)); XCTAssertTrue(library.isHittable)
        app.otherElements["media.source"].buttons["取消"].tap()
        XCTAssertTrue(library.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["还没有影像"].waitForExistence(timeout: 3))
    }
    func testExportSelectedHousePreparesRealZIPBeforeShare() {
        let app = launch(); add("原生备份房源", app); home(app); app.buttons["tab.我的"].tap()
        let entry = app.buttons["settings.export"]; reveal(entry, app); entry.tap()
        let select = app.buttons["backup.select.原生备份房源"]; XCTAssertTrue(select.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["backup.share"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["backup.share"].value as? String, "ZIP 已生成，包含 1 套房源及其影像")
        capture("17-native-backup-ready", app)
    }
}
