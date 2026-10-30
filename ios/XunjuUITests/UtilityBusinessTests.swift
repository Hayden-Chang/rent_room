import XCTest
import CoreLocation

@MainActor final class UtilityBusinessTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString, "--utility-network-fixture", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func focus(_ field: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(field.waitForExistence(timeout: 3)); field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 1) { field.tap() }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    }
    private func assertCandidatesStayDismissed(_ app: XCUIApplication) {
        let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch
        XCTAssertTrue(result.waitForNonExistence(timeout: 4), "Using a place must dismiss all candidates")
        let reappeared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true"), object: result)
        reappeared.isInverted = true
        XCTAssertEqual(XCTWaiter.wait(for: [reappeared], timeout: 2), .completed, "Candidates must remain dismissed across debounce and camera callbacks")
        XCTAssertEqual(app.textFields["place.query"].value as? String, "搜索地址，更快填写")
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists, "Using a place must collapse the real page map")
        XCTAssertEqual(app.buttons["place.mapToggle"].label, "展开地图")
    }
    func testPlaceWorkplaceAndCommutePersistAfterRelaunch() {
        let app = launch()
        app.buttons["home.add"].tap(); let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("选点与通勤")
        app.buttons["prompt.confirm"].tap()

        let checklist = app.textFields["mp.checklist.search"]; focus(checklist, in: app); checklist.typeText("地图")
        app.buttons["checklist.keyboard.done"].tap()
        let place = app.textFields["place.query"]; XCTAssertTrue(place.waitForExistence(timeout: 3))
        place.tap(); place.typeText("阳光\n")
        let houseChoice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '阳光小区'")).firstMatch
        XCTAssertTrue(houseChoice.waitForExistence(timeout: 4)); houseChoice.tap()
        assertCandidatesStayDismissed(app)
        capture("32-business-house-place", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3))
        app.buttons["tab.我的"].tap()
        app.buttons["local-settings.workplace"].tap()
        let search = app.textFields["place.query"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("办公楼\n")
        let office = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '办公楼'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 4)); office.tap()
        assertCandidatesStayDismissed(app)
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("办公楼"))
        capture("33-business-workplace", app)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap(); app.buttons["house.选点与通勤"].tap()
        let query = app.textFields["mp.checklist.search"]; query.tap(); query.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap()
        app.buttons["measurement.21255282-3663-4abe-b7de-d91eeb3825ed"].tap()
        let confirm = app.buttons["route.confirm"]; XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        capture("34-business-route-confirm", app); confirm.tap()
        let answer = app.textFields["mp.field.input.21255282-3663-4abe-b7de-d91eeb3825ed"]
        XCTAssertTrue(answer.waitForExistence(timeout: 3)); XCTAssertEqual(answer.value as? String, "24")
        XCTAssertGreaterThanOrEqual(answer.frame.width, 76)
        XCTAssertLessThan(answer.frame.maxX, app.buttons["measurement.21255282-3663-4abe-b7de-d91eeb3825ed"].frame.minX)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.选点与通勤"].waitForExistence(timeout: 10))
        app.buttons["house.选点与通勤"].tap(); XCTAssertFalse(app.buttons["coach.next"].exists)
        let restored = app.textFields["mp.checklist.search"]; restored.tap(); restored.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap(); XCTAssertEqual(answer.value as? String, "24")
        capture("35-business-commute-restored", app)
        app.navigationBackButton.tap()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tab.清单"].waitForNonExistence(timeout: 3))
        app.buttons["house.选点与通勤"].press(forDuration: 1)
        app.confirmArchiveFromHouseMenu()
        app.buttons["tab.我的"].tap()
        let archives = app.buttons["local-settings.archive"]; if !archives.isHittable { app.swipeUp() }; archives.tap()
        let archived = app.buttons["archive.open.选点与通勤"]; XCTAssertTrue(archived.waitForExistence(timeout: 3)); archived.tap()
        XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3))
        let archivedQuery = app.textFields["mp.checklist.search"]; archivedQuery.tap(); archivedQuery.typeText("地图")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["place.map"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["place.query"].exists); XCTAssertFalse(app.buttons["place.locate"].exists)
        XCTAssertFalse(app.buttons["place.result.center"].exists)
        capture("45-business-archived-map", app)
    }
    func testHouseMapReentryFocusAndAddressPersistAfterRelaunch() {
        let app = launch()
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.replacePromptText("地图状态回归"); app.buttons["prompt.confirm"].tap()

        let basic = app.staticTexts["mp.field.title.node:category:房源基本信息"]
        XCTAssertTrue(basic.waitForExistence(timeout: 3)); basic.tap()
        let query = app.textFields["place.query"], address = app.textFields["mp.field.input.f1_1"]
        let map = app.descendants(matching: .any)["place.map"], toggle = app.buttons["place.mapToggle"]
        XCTAssertTrue(query.waitForExistence(timeout: 3)); query.tap(); query.typeText("阳光\n")
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '阳光小区'")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 4)); choice.tap(); assertCandidatesStayDismissed(app)
        let savedAddress = address.value as? String ?? ""; XCTAssertTrue(savedAddress.contains("阳光小区"))
        app.navigationBackButton.tap(); app.buttons["house.地图状态回归"].tap()
        XCTAssertTrue(basic.waitForExistence(timeout: 3)); basic.tap()
        XCTAssertTrue(address.waitForExistence(timeout: 3)); XCTAssertEqual(address.value as? String, savedAddress)
        XCTAssertEqual(toggle.label, "展开地图"); XCTAssertFalse(map.exists)
        capture("house-map-01-reentered-collapsed", app)
        query.tap(); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(query.value as? String, "搜索地址，更快填写")
        XCTAssertTrue(map.waitForExistence(timeout: 3), "Focusing the empty search must expand the saved house map")
        capture("house-map-02-focus-without-typing", app)
        query.typeText("\n")
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.85)).press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
        XCTAssertTrue(address.isHittable); address.tap(); address.typeText("改址")
        app.buttons["checklist.keyboard.done"].tap()
        let editedAddress = address.value as? String ?? ""
        XCTAssertNotEqual(editedAddress, savedAddress)
        XCTAssertEqual(editedAddress.replacingOccurrences(of: "改址", with: ""), savedAddress)
        XCTAssertEqual(toggle.label, "展开地图"); XCTAssertFalse(map.exists)
        capture("house-map-03-manual-address-collapsed", app)
        toggle.tap(); XCTAssertTrue(map.waitForExistence(timeout: 3), "The saved map must survive invalidated house coordinates")
        capture("house-map-04-retained-camera", app)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["house.地图状态回归"].waitForExistence(timeout: 10)); app.buttons["house.地图状态回归"].tap()
        XCTAssertTrue(basic.waitForExistence(timeout: 3)); basic.tap()
        XCTAssertTrue(address.waitForExistence(timeout: 3)); XCTAssertEqual(address.value as? String, editedAddress)
        XCTAssertEqual(toggle.label, "展开地图"); XCTAssertFalse(map.exists)
        capture("house-map-05-relaunched-collapsed", app)
        query.tap(); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.label, "收起地图"); XCTAssertEqual(query.value as? String, editedAddress)
        capture("house-map-06-text-address-focus", app)
    }
    func testManualWorkplaceSaveAndClearSurviveRelaunch() {
        let app = launch(); app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        let address = app.textFields["workplace.address"], query = app.textFields["place.query"]
        let map = app.descendants(matching: .any)["place.map"], toggle = app.buttons["place.mapToggle"]
        XCTAssertTrue(address.waitForExistence(timeout: 3))
        query.tap(); query.typeText("办公楼\n")
        let office = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '办公楼'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 4)); office.tap(); assertCandidatesStayDismissed(app)
        let selectedAddress = address.value as? String ?? ""
        XCTAssertTrue(selectedAddress.contains("办公楼"))
        toggle.tap(); XCTAssertTrue(map.waitForExistence(timeout: 3)); XCTAssertEqual(toggle.label, "收起地图")
        address.tap(); address.typeText("改址"); app.buttons["完成"].firstMatch.tap()
        let editedAddress = address.value as? String ?? ""
        XCTAssertNotEqual(editedAddress, selectedAddress)
        XCTAssertEqual(editedAddress.replacingOccurrences(of: "改址", with: ""), selectedAddress)
        XCTAssertEqual(toggle.label, "展开地图", "Coordinate invalidation must collapse the map, not merely replace it with an empty placeholder")
        XCTAssertFalse(map.exists, "Manual workplace edits must collapse the map even when saved coordinates become invalid")
        capture("workplace-map-01-manual-collapsed", app)
        toggle.tap(); XCTAssertTrue(map.waitForExistence(timeout: 3), "The prior camera must survive the address invalidating its coordinates")
        capture("workplace-map-02-retained-camera", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertEqual(address.value as? String, editedAddress)
        XCTAssertFalse(map.exists, "A saved text-only workplace must reopen collapsed")
        capture("workplace-map-03-relaunched-collapsed", app)
        query.tap(); XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(toggle.label, "收起地图", "Search focus must expand a saved text-only workplace without typing")
        XCTAssertTrue(app.buttons["place.locate"].exists)
        XCTAssertEqual(query.value as? String, editedAddress, "Focusing must preserve the saved query")
        capture("workplace-map-04-focus-without-typing", app)
        query.typeText("\n")
        app.buttons["workplace.clear"].tap(); XCTAssertFalse(app.buttons["workplace.clear"].exists)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertFalse(app.buttons["workplace.clear"].exists)
    }

    func testSystemLocationWithSimulatedPointCanSelectWorkplace() {
        let prior = XCUIDevice.shared.location
        addTeardownBlock { @MainActor in XCUIDevice.shared.location = prior }
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 31.2304, longitude: 121.4737))
        let app = launch(); app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        let locate = app.buttons["place.locate"]; XCTAssertTrue(locate.waitForExistence(timeout: 3)); locate.tap()
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard"), alert = system.alerts.firstMatch
        if alert.waitForExistence(timeout: 2) {
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "40-native-location-permission"; attachment.lifetime = .keepAlways; add(attachment)
            let names = ["允许一次", "Allow Once", "使用App时允许", "使用 App 时允许", "Allow While Using App"]
            guard let button = names.map({ alert.buttons[$0] }).first(where: \.exists) else { return XCTFail("Location permission action missing") }
            button.tap()
        }
        let center = app.buttons["place.result.center"]
        XCTAssertTrue(center.waitForExistence(timeout: 10)); capture("41-simulated-location-nearby", app); center.tap()
        assertCandidatesStayDismissed(app)
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("阳光小区"))
        capture("42-simulated-location-selected", app)
        app.buttons["place.mapToggle"].tap()
        locate.tap(); XCTAssertTrue(center.waitForExistence(timeout: 10), "Locating again must reopen candidates")
        center.tap(); assertCandidatesStayDismissed(app)
        capture("43-simulated-location-selected-again", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("阳光小区"))
    }

    // Supplementary live integration: UUID records, public landmarks, no
    // network fixtures or physical/user location; not an offline CI gate.
    func testLiveSystemPlaceSearchSelectionAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        let query = app.textFields["place.query"]; focus(query, in: app)
        query.typeText("上海东方明珠广播电视塔\n")
        let office = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '东方明珠'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 20), "Real Tianditu search must return the public landmark")
        capture("live-map-01-search-results", app); office.tap(); assertCandidatesStayDismissed(app)
        let address = app.textFields["workplace.address"], saved = address.value as? String ?? ""
        XCTAssertTrue(saved.contains("东方明珠")); capture("live-map-02-selected-collapsed", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertEqual(address.value as? String, saved)
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists)
        app.navigationBackButton.tap(); app.buttons["tab.房源"].tap(); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3)); focus(name, in: app)
        name.replacePromptText("在线通勤回归"); app.buttons["prompt.confirm"].tap()

        let basic = app.staticTexts["mp.field.title.node:category:房源基本信息"]
        XCTAssertTrue(basic.waitForExistence(timeout: 3)); basic.tap(); focus(query, in: app)
        query.typeText("上海人民广场\n")
        let house = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '人民广场'")).firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 20)); house.tap(); assertCandidatesStayDismissed(app)
        capture("live-map-03-house-selected", app)
        let checklist = app.textFields["mp.checklist.search"]
        var savedMinutes: [String: String] = [:]
        for (filter, field, mode) in [("公交地铁", "21255282-3663-4abe-b7de-d91eeb3825ed", "transit"), ("开车", "3c70cda2-7c6c-4fa6-b2db-b647af24ba72", "driving")] {
            focus(checklist, in: app)
            let prior = checklist.value as? String ?? ""
            if prior != "搜索检查项、结果或备注" { checklist.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count)) }
            checklist.typeText(filter); XCTAssertEqual(checklist.value as? String, filter); app.buttons["checklist.keyboard.done"].tap()
            let measurement = app.buttons["measurement." + field]; XCTAssertTrue(measurement.waitForExistence(timeout: 3)); measurement.tap()
            let confirm = app.buttons["route.confirm"]; XCTAssertTrue(confirm.waitForExistence(timeout: 3))
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: confirm)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed, "Real " + mode + " route did not complete")
            let minutes = confirm.label.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init).first ?? 0
            XCTAssertGreaterThan(minutes, 0)
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'route.option.'")).firstMatch.exists)
            capture("live-map-04-" + mode + "-route", app)
            let detail = XCTAttachment(string: "provider=Tianditu; fixture=false; public origin=上海人民广场; public destination=上海东方明珠广播电视塔; mode=\(mode); minutes=\(minutes)")
            detail.name = "live-" + mode + "-result"; detail.lifetime = .keepAlways; add(detail)
            confirm.tap()
            let answer = app.textFields["mp.field.input." + field]
            XCTAssertTrue(answer.waitForExistence(timeout: 3)); XCTAssertEqual(answer.value as? String, String(minutes))
            savedMinutes[field] = String(minutes)
        }
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.在线通勤回归"].waitForExistence(timeout: 10)); app.buttons["house.在线通勤回归"].tap()
        for (filter, field) in [("公交地铁", "21255282-3663-4abe-b7de-d91eeb3825ed"), ("开车", "3c70cda2-7c6c-4fa6-b2db-b647af24ba72")] {
            focus(checklist, in: app)
            let prior = checklist.value as? String ?? ""
            if prior != "搜索检查项、结果或备注" { checklist.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: prior.count)) }
            checklist.typeText(filter); XCTAssertEqual(checklist.value as? String, filter); app.buttons["checklist.keyboard.done"].tap()
            XCTAssertEqual(app.textFields["mp.field.input." + field].value as? String, savedMinutes[field])
        }
        capture("live-map-05-both-commutes-persisted", app)
    }
}
