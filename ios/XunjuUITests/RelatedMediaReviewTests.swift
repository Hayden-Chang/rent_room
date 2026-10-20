import XCTest

@MainActor final class RelatedMediaReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch(_ surface: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", surface, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func close(_ id: String, _ app: XCUIApplication) {
        let button = app.buttons[id]; button.tap()
        let dismissed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: button)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 3), .completed)
    }
    func testManualIssuePhotosVideoResolveOpenAndReadOnly() {
        let app = launch("issue-cards"), photo = app.buttons["manualIssue.mixed.preview.image1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.frame.height, 96, accuracy: 1)
        let second = app.buttons["manualIssue.mixed.preview.image2"], third = app.buttons["manualIssue.mixed.preview.image3"]
        XCTAssertEqual(second.frame.minX - photo.frame.maxX, 8, accuracy: 1)
        XCTAssertEqual(third.frame.minY, photo.frame.minY, accuracy: 1)
        capture("71-manual-issue-card-photos-video", app)
        photo.tap(); XCTAssertTrue(app.images["review.relatedImage"].waitForExistence(timeout: 3)); close("review.previewClose", app)
        let resolve = app.buttons["manualIssue.mixed.resolve"]; resolve.tap(); XCTAssertEqual(resolve.label, "已解决")
        let video = app.descendants(matching: .any)["manualIssue.mixed.video.video"].firstMatch
        XCTAssertEqual(video.frame.height, 190, accuracy: 1)
        let transport = app.buttons["Play/Pause"]
        if transport.isHittable { transport.tap() } else { video.tap() }
        let playing = expectation(for: NSPredicate(format: "label IN %@", ["Pause", "暂停"]), evaluatedWith: transport)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["review.relatedEvent"].label.contains("打开问题回调 0 次"))
        capture("72-manual-issue-native-video", app); transport.tap()
        app.buttons["manualIssue.mixed.details"].tap()
        XCTAssertTrue(app.staticTexts["review.relatedEvent"].label.contains("打开问题回调 1 次"))
        app.buttons["review.readonly"].tap(); XCTAssertFalse(resolve.isEnabled)
        XCTAssertEqual(app.buttons["manualIssue.empty.details"].label, "查看详情 ›")
        capture("73-manual-issue-card-readonly", app)
        photo.tap(); XCTAssertTrue(app.images["review.relatedImage"].waitForExistence(timeout: 3))
    }
    func testRelatedThumbnailsMoreAndAutomaticIssueInlineEditing() {
        let app = launch("field-media"), photo = app.buttons["related.preview.image1"]
        XCTAssertTrue(photo.waitForExistence(timeout: 10))
        XCTAssertEqual(photo.frame.width, 44, accuracy: 0.5); XCTAssertEqual(photo.frame.height, 44, accuracy: 0.5)
        let video = app.buttons["related.preview.video"]
        XCTAssertEqual(video.frame.minX - photo.frame.maxX, 6, accuracy: 1)
        XCTAssertEqual(app.buttons["related.all"].label, "查看全部 4 个关联影像")
        capture("74-automatic-issue-related-thumbnails", app)
        photo.tap(); XCTAssertTrue(app.images["review.relatedImage"].waitForExistence(timeout: 3)); close("review.previewClose", app)
        video.tap(); XCTAssertTrue(app.buttons["review.previewClose"].waitForExistence(timeout: 3)); capture("75-related-video-preview", app); close("review.previewClose", app)
        app.buttons["related.all"].tap(); XCTAssertTrue(app.buttons["review.allClose"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "gallery.preview.")).count, 4)
        capture("76-related-all-media", app); close("review.allClose", app)
        let normal = app.buttons["choice.纱窗正常.正常"]; normal.tap(); XCTAssertTrue(normal.isSelected)
        let fee = app.textFields["input.relatedFee.value"]; fee.tap(); fee.typeText("0"); app.buttons["完成"].tap()
        XCTAssertEqual(fee.value as? String, "1500")
        app.otherElements["review.automaticChoice"].firstMatch.swipeLeft(); app.buttons["备注"].tap()
        let note = app.textViews["note.text"]; XCTAssertTrue(note.waitForExistence(timeout: 3)); note.tap(); note.typeText("；待复查"); app.buttons["保存备注"].tap()
        XCTAssertTrue(app.buttons["review.automaticNote"].waitForExistence(timeout: 3)); XCTAssertTrue(app.buttons["review.automaticNote"].label.contains("待复查"))
        app.buttons["review.readonly"].tap(); XCTAssertFalse(normal.isEnabled); XCTAssertFalse(fee.isEnabled)
        XCTAssertTrue(normal.isSelected); XCTAssertEqual(fee.value as? String, "1500")
        capture("77-automatic-issue-readonly", app)
    }
}
