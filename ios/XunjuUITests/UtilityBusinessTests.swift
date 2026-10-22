import XCTest
import CoreLocation

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
        let checklist = app.textFields["mp.checklist.search"]; checklist.tap(); checklist.typeText("地址")
        app.buttons["checklist.keyboard.done"].tap()
        let place = app.textFields["place.query"]; XCTAssertTrue(place.waitForExistence(timeout: 3))
        place.tap(); place.typeText("阳光\n")
        let houseChoice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '阳光小区'")).firstMatch
        XCTAssertTrue(houseChoice.waitForExistence(timeout: 4)); houseChoice.tap()
        assertCandidatesStayDismissed(app)
        let address = app.textFields["mp.field.input.f1_1"]
        let savedHouseAddress = address.value as? String ?? ""
        XCTAssertTrue(savedHouseAddress.contains("阳光小区"))
        capture("32-business-house-place", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["house.选点与通勤"].tap()
        let reopenedFilter = app.textFields["mp.checklist.search"]
        reopenedFilter.tap(); reopenedFilter.typeText("地址"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(place.waitForExistence(timeout: 3))
        XCTAssertEqual(address.value as? String, savedHouseAddress)
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists, "Reentering the saved house must keep the map collapsed")
        capture("house-map-01-reentered-collapsed", app)
        place.tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(place.value as? String, "搜索地址，更快填写")
        XCTAssertTrue(app.descendants(matching: .any)["place.map"].exists, "Search focus must immediately expand the house map")
        capture("house-map-02-focus-without-typing", app)
        place.typeText("\n")
        // Bring the external field below the map above the footer without panning MapKit.
        let scroll = app.scrollViews.firstMatch
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.85)).press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.3)))
        XCTAssertTrue(address.isHittable); address.tap(); address.typeText(" ")
        app.buttons["checklist.keyboard.done"].tap()
        let editedHouseAddress = address.value as? String ?? ""
        XCTAssertNotEqual(editedHouseAddress, savedHouseAddress)
        XCTAssertEqual(editedHouseAddress.replacingOccurrences(of: " ", with: ""), savedHouseAddress.replacingOccurrences(of: " ", with: ""))
        XCTAssertEqual(app.buttons["place.mapToggle"].label, "展开地图")
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists, "Editing the real house address must collapse the map")
        capture("house-map-03-manual-address-collapsed", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["tab.我的"].tap()
        app.buttons["settings.workplace"].tap()
        let search = app.textFields["place.query"]; XCTAssertTrue(search.waitForExistence(timeout: 3)); search.tap(); search.typeText("办公楼\n")
        let office = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '办公楼'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 4)); office.tap()
        assertCandidatesStayDismissed(app)
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("办公楼"))
        capture("33-business-workplace", app)
        app.navigationBars.buttons.firstMatch.tap(); app.buttons["tab.房源"].tap(); app.buttons["house.选点与通勤"].tap()
        let query = app.textFields["mp.checklist.search"]; query.tap(); query.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap()
        app.buttons["measurement.21255282-3663-4abe-b7de-d91eeb3825ed"].tap()
        let confirm = app.buttons["route.confirm"]; XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        let ready = expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 4), .completed)
        capture("34-business-route-confirm", app); confirm.tap()
        let answer = app.textFields["mp.field.input.21255282-3663-4abe-b7de-d91eeb3825ed"]
        XCTAssertTrue(answer.waitForExistence(timeout: 3)); XCTAssertEqual(answer.value as? String, "24")
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["house.选点与通勤"].waitForExistence(timeout: 10))
        app.buttons["house.选点与通勤"].tap(); XCTAssertFalse(next.exists)
        let persistedFilter = app.textFields["mp.checklist.search"]
        persistedFilter.tap(); persistedFilter.typeText("地址"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 3))
        XCTAssertEqual(address.value as? String, editedHouseAddress)
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists)
        capture("house-map-04-relaunched-collapsed", app)
        persistedFilter.tap(); persistedFilter.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2))
        let restored = app.textFields["mp.checklist.search"]; restored.tap(); restored.typeText("公交地铁")
        app.buttons["checklist.keyboard.done"].tap(); XCTAssertEqual(answer.value as? String, "24")
        capture("35-business-commute-restored", app)
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["house.选点与通勤"].press(forDuration: 1)
        XCTAssertTrue(app.buttons["归档"].waitForExistence(timeout: 3)); app.buttons["归档"].tap()
        app.buttons["tab.我的"].tap()
        let archives = app.buttons["settings.archive"]; if !archives.isHittable { app.swipeUp() }; archives.tap()
        let archived = app.buttons["archive.open.选点与通勤"]; XCTAssertTrue(archived.waitForExistence(timeout: 3)); archived.tap()
        XCTAssertTrue(app.staticTexts["house.readonly"].waitForExistence(timeout: 3))
        let archivedQuery = app.textFields["mp.checklist.search"]; archivedQuery.tap(); archivedQuery.typeText("地图")
        app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["place.map"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.textFields["place.query"].exists); XCTAssertFalse(app.buttons["place.locate"].exists)
        XCTAssertFalse(app.buttons["place.result.center"].exists)
        capture("45-business-archived-map", app)
    }
    func testManualWorkplaceSaveAndClearSurviveRelaunch() {
        let app = launch(); app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        let address = app.textFields["workplace.address"], query = app.textFields["place.query"]
        let map = app.descendants(matching: .any)["place.map"], toggle = app.buttons["place.mapToggle"]
        XCTAssertTrue(address.waitForExistence(timeout: 3))
        query.tap(); query.typeText("办公楼\n")
        let office = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '办公楼'")).firstMatch
        XCTAssertTrue(office.waitForExistence(timeout: 4)); office.tap(); assertCandidatesStayDismissed(app)
        let selectedAddress = address.value as? String ?? ""
        XCTAssertTrue(selectedAddress.contains("办公楼"))
        toggle.tap(); XCTAssertTrue(map.exists)
        address.tap(); address.typeText("改址"); app.buttons["完成"].firstMatch.tap()
        let editedAddress = address.value as? String ?? ""
        XCTAssertNotEqual(editedAddress, selectedAddress)
        XCTAssertEqual(editedAddress.replacingOccurrences(of: "改址", with: ""), selectedAddress)
        XCTAssertEqual(toggle.label, "展开地图", "Coordinate invalidation must collapse the map, not merely replace it with an empty placeholder")
        XCTAssertFalse(map.exists, "Manual workplace edits must collapse the map even when saved coordinates become invalid")
        capture("workplace-map-01-manual-collapsed", app)
        toggle.tap(); XCTAssertTrue(map.exists, "The prior camera must survive the address invalidating its coordinates")
        capture("workplace-map-02-retained-camera", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
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
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        XCTAssertFalse(app.buttons["workplace.clear"].exists)
    }

    func testSystemLocationWithSimulatedPointCanSelectWorkplace() {
        let prior = XCUIDevice.shared.location
        addTeardownBlock { @MainActor in XCUIDevice.shared.location = prior }
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: 31.2304, longitude: 121.4737))
        let app = launch(); app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
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
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        XCTAssertTrue((app.textFields["workplace.address"].value as? String ?? "").contains("阳光小区"))
    }

    // Supplementary live SDK integration: isolated records, public landmark,
    // no network fixture and no physical/user location. Not an offline CI gate.
    func testLiveSystemPlaceSearchSelectionAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        let query = app.textFields["place.query"]; XCTAssertTrue(query.waitForExistence(timeout: 3))
        query.tap(); query.typeText("上海东方明珠广播电视塔\n")
        let choice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.' AND label CONTAINS '东方明珠'")).firstMatch
        XCTAssertTrue(choice.waitForExistence(timeout: 20), "Real system search did not return the public landmark")
        capture("system-places-live-search", app); choice.tap()
        let address = app.textFields["workplace.address"]
        let saved = address.value as? String ?? ""
        XCTAssertTrue(saved.contains("东方明珠"))
        assertCandidatesStayDismissed(app)
        capture("system-places-live-selected", app)
        app.terminate(); app.launch(); XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["settings.workplace"].tap()
        XCTAssertEqual(address.value as? String, saved)
        XCTAssertFalse(app.descendants(matching: .any)["place.map"].exists)
        app.buttons["place.mapToggle"].tap()
        XCTAssertTrue(app.buttons["place.result.center"].waitForExistence(timeout: 20))
        capture("system-places-live-restored", app)
    }
}
