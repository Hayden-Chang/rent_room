import XCTest

@MainActor final class UtilityReviewTests: XCTestCase {
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

    func testPlaceSearchSelectionAndPermissionFallback() {
        let app = launch("place"), query = app.textFields["place.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 10))
        capture("21-place-nearby", app)
        query.tap(); query.typeText("公寓\n")
        let choice = app.buttons["place.result.two"]
        XCTAssertTrue(choice.isHittable)
        capture("22-place-search", app)
        choice.tap()
        XCTAssertEqual(app.staticTexts["review.placeEvent"].label, "已选择：新城公寓")
        XCTAssertEqual(query.value as? String, "搜索地址，更快填写")
        app.buttons["place.locate"].tap()
        let settings = app.buttons["place.retry"]
        if !settings.isHittable { app.swipeUp() }
        XCTAssertTrue(settings.isHittable)
        capture("23-place-permission", app)
        settings.tap()
        XCTAssertEqual(app.staticTexts["review.placeEvent"].label, "已触发打开系统设置")
    }

    func testRouteSelectionAndExplicitConfirmation() {
        let app = launch("routes"), first = app.buttons["route.option.one"], second = app.buttons["route.option.two"]
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["route.cancel"].isHittable)
        XCTAssertGreaterThan(app.buttons["route.cancel"].frame.width, 100)
        XCTAssertTrue(first.isSelected)
        capture("24-route-map-and-endpoints", app)
        if second.frame.maxY > app.buttons["route.confirm"].frame.minY { first.swipeUp() }
        XCTAssertLessThanOrEqual(second.frame.maxY, app.buttons["route.confirm"].frame.minY)
        second.tap()
        XCTAssertTrue(second.isSelected); XCTAssertFalse(first.isSelected)
        XCTAssertEqual(app.buttons["route.confirm"].label, "确定并填入 32 分钟")
        capture("25-route-selection", app)
        app.buttons["route.confirm"].tap()
        XCTAssertEqual(app.staticTexts["review.routeEvent"].label, "已确认：32分钟")
        app.buttons["route.cancel"].tap()
        XCTAssertEqual(app.staticTexts["review.routeEvent"].label, "已取消，保留原通勤时间")
    }

    func testSpeedCancellationAndSaveRetryRetainReading() {
        let app = launch("speed"), action = app.buttons["speed.action"]
        XCTAssertTrue(action.waitForExistence(timeout: 10)); XCTAssertEqual(action.label, "取消")
        capture("26-speed-testing", app)
        action.tap()
        XCTAssertEqual(app.staticTexts["speed.message"].label, "测速已取消")
        XCTAssertEqual(app.staticTexts["review.speedEvent"].label, "取消后保留原答案")
        action.tap()
        XCTAssertEqual(action.label, "取消")
        app.buttons["评审状态"].tap(); app.buttons["有效结果保存失败"].tap()
        XCTAssertEqual(app.staticTexts["speed.value"].label, "104.86")
        XCTAssertEqual(action.label, "重试保存")
        capture("27-speed-save-error", app)
        action.tap()
        XCTAssertEqual(app.staticTexts["speed.message"].label, "测速结果已保存")
        XCTAssertEqual(app.staticTexts["speed.value"].label, "104.86")
        XCTAssertFalse(action.exists)
    }

    func testCoachLiveAnchorsSwipeDemoAndOptOut() {
        let app = launch("coach"), next = app.buttons["coach.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["coach.title"].label, "房源信息")
        capture("28-coach-phase-anchor", app)
        next.tap(); XCTAssertEqual(app.staticTexts["coach.title"].label, "现场检查")
        next.tap(); XCTAssertEqual(app.staticTexts["coach.title"].label, "询问与签约")
        next.tap(); XCTAssertEqual(app.staticTexts["coach.title"].label, "左滑检查项")
        app.otherElements["coach.demo"].swipeLeft()
        XCTAssertTrue(app.descendants(matching: .any)["coach.actions"].waitForExistence(timeout: 3))
        let preference = app.buttons["coach.preference"]
        preference.tap(); XCTAssertTrue(preference.isSelected)
        XCTAssertEqual(preference.value as? String, "已选中")
        capture("29-coach-swipe-and-preference", app)
        next.tap(); XCTAssertFalse(next.exists)
        XCTAssertEqual(app.staticTexts["review.coachEvent"].label, "引导结束，下次不再自动显示")
    }

    func testSpeedRequiresWifiAndMobileConsentBeforeContinuing() {
        let app = launch("speed-consent")
        let wifi = app.alerts["是否已连接 WiFi"]
        XCTAssertTrue(wifi.waitForExistence(timeout: 5)); capture("36-speed-wifi-consent", app)
        wifi.buttons["是"].tap()
        let mobile = app.alerts["使用当前网络测速？"]
        XCTAssertTrue(mobile.waitForExistence(timeout: 4)); capture("37-speed-mobile-consent", app)
        mobile.buttons["暂不测试"].tap()
        let event = app.staticTexts["review.consentEvent"]
        XCTAssertTrue(event.waitForExistence(timeout: 3)); XCTAssertEqual(event.label, "暂不测试，原答案保持不变")
        app.buttons["重新检查网络"].tap(); XCTAssertTrue(wifi.waitForExistence(timeout: 3)); wifi.buttons["是"].tap()
        XCTAssertTrue(mobile.waitForExistence(timeout: 4)); mobile.buttons["开始测速"].tap()
        let ready = expectation(for: NSPredicate(format: "label == %@", "网络确认完成；评审不会下载数据"), evaluatedWith: event)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 3), .completed)
        app.buttons["重新检查网络"].tap(); XCTAssertTrue(wifi.waitForExistence(timeout: 3)); wifi.buttons["否"].tap()
        XCTAssertEqual(event.label, "暂不测试，原答案保持不变")
    }
}
