import XCTest

@MainActor final class MediaComponentReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ surface: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", surface, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name
        attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, app: XCUIApplication, up: Bool = true) {
        for _ in 0..<4 {
            if element.isHittable && element.frame.minY >= app.navigationBars.firstMatch.frame.maxY && element.frame.maxY <= app.buttons["issueEditor.cancel"].frame.minY { return }
            if up { app.swipeUp() } else { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }

    func testGalleryThreeColumnsFilterPreviewCaptionAndEmpty() {
        let app = launch("media"), first = app.buttons["gallery.preview.image1"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        let second = app.buttons["gallery.preview.image2"], third = app.buttons["gallery.preview.image3"]
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
        XCTAssertEqual(first.frame.minY, third.frame.minY, accuracy: 1)
        XCTAssertEqual(first.frame.height, 114, accuracy: 1)
        XCTAssertEqual(second.frame.minX - first.frame.maxX, 8, accuracy: 1)
        capture("48-gallery-three-columns", app)
        first.tap()
        let close = app.buttons["review.previewClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 3)); XCTAssertTrue(app.images["review.mediaImage"].exists)
        close.tap()
        let caption = app.buttons["gallery.caption.image2"]
        XCTAssertTrue(caption.waitForExistence(timeout: 3)); caption.tap()
        let text = app.textViews["note.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 3)); text.tap(); text.typeText("确认窗框\n保留备注")
        app.buttons["保存备注"].tap()
        let saved = expectation(for: NSPredicate(format: "label == %@", "确认窗框\n保留备注"), evaluatedWith: caption)
        XCTAssertEqual(XCTWaiter.wait(for: [saved], timeout: 3), .completed)
        app.buttons["gallery.filter.视频"].tap()
        XCTAssertFalse(first.exists); XCTAssertTrue(app.buttons["gallery.preview.video"].exists)
        app.buttons["gallery.filter.照片"].tap()
        XCTAssertTrue(first.exists); XCTAssertFalse(app.buttons["gallery.preview.video"].exists)
        app.buttons["review.mediaEmpty"].tap()
        XCTAssertTrue(app.staticTexts["还没有影像"].exists)
        capture("49-gallery-empty", app)
        app.buttons["review.mediaAdd"].tap()
        XCTAssertEqual(app.staticTexts["review.mediaEvent"].label, "已触发添加影像；评审不会打开相册或相机")
    }

    func testIssueValidationSaveFailureAndDiscardRetainDraft() {
        let app = launch("issue-media"), title = app.textFields["issueEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let cancel = app.buttons["issueEditor.cancel"], save = app.buttons["issueEditor.save"]
        XCTAssertEqual(save.frame.width / cancel.frame.width, 2, accuracy: 0.03)
        save.tap()
        XCTAssertEqual(app.staticTexts["issueEditor.titleError"].label, "请填写问题标题")
        capture("50-issue-title-validation", app)
        title.tap(); title.typeText("卧室窗户关不严")
        let note = app.textViews["issueEditor.note"]
        note.tap(); note.typeText("下雨时检查窗框，联系房东确认维修。")
        app.buttons["完成"].firstMatch.tap()
        save.tap()
        let error = app.staticTexts["issueEditor.error"]
        reveal(error, app: app)
        XCTAssertEqual(error.label, "保存失败，请重试。文字和影像仍保留在本页。")
        XCTAssertEqual(title.value as? String, "卧室窗户关不严")
        XCTAssertEqual(note.value as? String, "下雨时检查窗框，联系房东确认维修。")
        capture("51-issue-save-failure", app)
        cancel.tap()
        let alert = app.alerts["放弃修改？"]
        XCTAssertTrue(alert.waitForExistence(timeout: 3)); capture("52-issue-discard-confirmation", app)
        alert.buttons["继续编辑"].tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 3)); XCTAssertEqual(title.value as? String, "卧室窗户关不严")
        cancel.tap(); XCTAssertTrue(alert.waitForExistence(timeout: 3)); alert.buttons["放弃"].tap()
        let event = app.staticTexts["review.mediaEvent"]
        XCTAssertTrue(event.waitForExistence(timeout: 3)); XCTAssertEqual(event.label, "已放弃未保存的修改")
        XCTAssertEqual(title.value as? String, "例如：卧室窗户关不严")
        let add = app.buttons["issueEditor.addMedia"]
        reveal(add, app: app); add.tap()
        app.swipeUp()
        app.buttons["评审状态"].tap(); app.buttons["保存中"].tap()
        XCTAssertFalse(save.isEnabled); XCTAssertFalse(cancel.isEnabled); XCTAssertFalse(title.isEnabled)
        XCTAssertFalse(app.buttons["issueEditor.remove.image1"].isEnabled)
        capture("60-issue-saving", app)
        app.buttons["评审状态"].tap(); app.buttons["选取中"].tap()
        XCTAssertFalse(app.buttons["issueEditor.addMedia"].isEnabled)
        XCTAssertFalse(save.isEnabled); XCTAssertFalse(cancel.isEnabled)
        app.buttons["评审状态"].tap(); app.buttons["恢复编辑"].tap()
        XCTAssertTrue(save.isEnabled); XCTAssertTrue(cancel.isEnabled)
    }

    func testIssuePhotosInlineVideoRemovalAndReadOnly() {
        let app = launch("issue-media"), add = app.buttons["issueEditor.addMedia"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); reveal(add, app: app); add.tap()
        let photo = app.buttons["issueEditor.preview.image1"]
        reveal(photo, app: app)
        XCTAssertEqual(photo.frame.height, 104, accuracy: 1)
        XCTAssertEqual(photo.frame.minY, app.buttons["issueEditor.preview.image3"].frame.minY, accuracy: 1)
        capture("53-issue-photo-row", app)
        photo.tap()
        let close = app.buttons["review.previewClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 3)); close.tap()
        let video = app.descendants(matching: .any)["issueEditor.video.video"].firstMatch
        reveal(video, app: app)
        XCTAssertEqual(video.frame.height, 190, accuracy: 1)
        video.tap() // Reveal the system player's auto-hiding transport controls.
        let play = app.buttons.matching(NSPredicate(format: "label IN %@", ["Play", "播放"])).firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 5)); play.tap()
        let pause = app.buttons.matching(NSPredicate(format: "label IN %@", ["Pause", "暂停"])).firstMatch
        XCTAssertTrue(pause.waitForExistence(timeout: 3)); pause.tap()
        XCTAssertTrue(app.buttons["Play/Pause"].exists)
        capture("54-issue-inline-video", app)
        let removeVideo = app.buttons["issueEditor.remove.video"]
        reveal(removeVideo, app: app); removeVideo.tap(); XCTAssertFalse(video.exists)
        let removePhoto = app.buttons["issueEditor.remove.image1"]
        reveal(removePhoto, app: app, up: false); removePhoto.tap(); XCTAssertFalse(photo.exists)
        app.buttons["review.readonly"].tap()
        XCTAssertFalse(add.exists); XCTAssertFalse(app.buttons["issueEditor.remove.image2"].exists)
        XCTAssertFalse(app.buttons["issueEditor.save"].exists)
        XCTAssertEqual(app.buttons["issueEditor.cancel"].label, "返回")
        XCTAssertFalse(app.textFields["issueEditor.title"].isEnabled)
        app.swipeDown()
        capture("55-issue-readonly", app)
    }

    func testCategoryGroupSwipeSkipFoldAndReadOnlyPreserveSelection() {
        let app = launch("headings"), category = app.buttons["heading.category.fold"]
        XCTAssertTrue(category.waitForExistence(timeout: 10))
        let choice = app.buttons["heading.group.choice.正常"], skip = app.buttons["heading.group.skip"]
        XCTAssertTrue(choice.isSelected)
        XCTAssertGreaterThanOrEqual(skip.frame.width, 55)
        capture("56-heading-progress-and-choices", app)
        skip.tap(); XCTAssertTrue(skip.isSelected); XCTAssertFalse(choice.exists)
        capture("59-heading-skipped", app)
        XCTAssertFalse(app.buttons["choice.纱窗正常.是"].exists)
        category.tap(); XCTAssertFalse(skip.exists); category.tap()
        XCTAssertTrue(skip.isSelected); skip.tap(); XCTAssertFalse(skip.isSelected)
        XCTAssertTrue(choice.isSelected); XCTAssertTrue(app.buttons["choice.纱窗正常.是"].exists)
        category.swipeLeft()
        let flag = app.buttons["heading.category.标记问题"]
        XCTAssertTrue(flag.waitForExistence(timeout: 3))
        capture("57-heading-swipe-and-flag", app)
        category.tap() // Close the open tray before a later tap can fold.
        XCTAssertTrue(skip.exists); XCTAssertFalse(flag.exists)
        category.swipeLeft(); XCTAssertTrue(flag.waitForExistence(timeout: 3)); flag.tap()
        XCTAssertTrue(skip.exists); XCTAssertFalse(flag.exists)
        XCTAssertEqual(app.staticTexts["heading.category.stats"].label, "1 / 6 · 1 问题")
        app.buttons["heading.group.fold"].swipeLeft()
        let note = app.buttons["heading.group.备注"]
        XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap()
        XCTAssertEqual(app.staticTexts["review.mediaEvent"].label, "已触发分组备注")
        app.buttons["review.readonly"].tap()
        XCTAssertFalse(skip.isEnabled); XCTAssertFalse(choice.isEnabled)
        category.tap(); XCTAssertFalse(choice.exists); category.tap(); XCTAssertTrue(choice.isSelected)
        category.swipeLeft()
        XCTAssertFalse(flag.exists)
        capture("58-heading-readonly", app)
    }
}
