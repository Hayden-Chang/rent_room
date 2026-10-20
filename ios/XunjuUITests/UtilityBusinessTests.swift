import XCTest

@MainActor final class UtilityBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--utility-network-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testRealGuidePlaceWorkplaceAndCommutePersistAfterRelaunch() {
        let app = launch()
        app.buttons["home.add"].tap(); let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.tap(); name.typeText("选点与通勤")
        app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        capture("30-business-coach-phase", app)
        for _ in 0..<3 { next.tap() }
        let demo = app.otherElements["coach.demo"]
        XCTAssertTrue(app.descendants(matching: .any)["coach.actions"].waitForExistence(timeout: 3))
        XCTAssertGreaterThan(demo.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        XCTAssertLessThan(demo.frame.maxY, app.buttons["tab.清单"].frame.minY)
        demo.swipeLeft()
        app.buttons["coach.preference"].tap(); capture("31-business-coach-field", app); next.tap()
        XCTAssertFalse(next.exists)
        let checklist = app.textFields["checklist.search"]; checklist.tap(); checklist.typeText("地图")
        app.buttons["checklist.keyboard.done"].tap()
        let place = app.textFields["place.query"]; XCTAssertTrue(place.waitForExistence(timeout: 3))
        place.tap(); place.typeText("阳光\n")
        let houseChoice = app.buttons["place.result.house"]; XCTAssertTrue(houseChoice.waitForExistence(timeout: 4)); houseChoice.tap()
        capture("32-business-house-place", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["tab.我的"].tap()
        app.buttons["settings.workplace"].tap()
        let search = app.textFields["place.query"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("办公楼\n")
        let office = app.buttons["place.result.office"]; XCTAssertTrue(office.waitForExistence(timeout: 4)); office.tap()
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("办公楼"))
        capture("33-business-workplace", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["tab.房源"].tap(); app.buttons["house.选点与通勤"].tap()
        let query = app.textFields["checklist.search"]; query.tap(); query.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap()
        app.buttons["commute.open.21255282-3663-4abe-b7de-d91eeb3825ed"].tap()
        let confirm = app.buttons["route.confirm"]; XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        capture("34-business-route-confirm", app); confirm.tap()
        let answer = app.textFields["input.21255282-3663-4abe-b7de-d91eeb3825ed.value"]
        XCTAssertTrue(answer.waitForExistence(timeout: 3)); XCTAssertEqual(answer.value as? String, "24")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.选点与通勤"].waitForExistence(timeout: 10))
        app.buttons["house.选点与通勤"].tap(); XCTAssertFalse(next.exists)
        let restored = app.textFields["checklist.search"]; restored.tap(); restored.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap(); XCTAssertEqual(answer.value as? String, "24")
        capture("35-business-commute-restored", app)
    }
    func testManualWorkplaceSaveAndClearSurviveRelaunch() {
        let app = launch(); app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        let address = app.textFields["workplace.address"]; XCTAssertTrue(address.waitForExistence(timeout: 3))
        address.tap(); address.typeText("手工地址18号"); app.buttons["完成"].firstMatch.tap()
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        XCTAssertEqual(address.value as? String, "手工地址18号")
        app.buttons["workplace.clear"].tap(); XCTAssertFalse(app.buttons["workplace.clear"].exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        XCTAssertFalse(app.buttons["workplace.clear"].exists)
    }
}
