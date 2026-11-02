import XCTest

@MainActor final class EnglishChecklistCopyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "--filling-guide-fixture", mode,
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10)); currency.tap()
        XCTAssertTrue(currency.waitForNonExistence(timeout: 3))
        let house = app.buttons["house.首次填写"].firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 5)); house.tap()
        let start = app.scrollViews["mp.checklist.scroll"].buttons["xiaoda.accept"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5)); start.tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 3))
        return app
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        let scroll = app.scrollViews["mp.checklist.scroll"]
        for _ in 0..<10 {
            if element.exists && element.isHittable && element.frame.minY > app.navigationHeader.frame.maxY + 8
                && element.frame.maxY < scroll.frame.maxY - 110 { return }
            if element.exists && element.frame.minY < app.navigationHeader.frame.maxY + 8 { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTFail("Row is not fully visible: \(element.identifier)")
    }

    private func search(_ text: String, _ app: XCUIApplication) {
        app.buttons["Back to Top"].tap()
        let all = app.buttons["mp.phase.全部"]
        let ready = expectation(for: NSPredicate(format: "hittable == true"), evaluatedWith: all)
        wait(for: [ready], timeout: 3); all.tap()
        let input = app.textFields["mp.checklist.search"]
        input.tap()
        let old = input.value as? String ?? ""
        if old != input.placeholderValue && !old.isEmpty {
            input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
        }
        input.typeText(text); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }

    private func checkRow(_ id: String, _ app: XCUIApplication) {
        let title = app.staticTexts["mp.field.title." + id].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 3)); reveal(title, app)
        let yes = app.buttons["mp.field.choice.\(id).是"].firstMatch
        XCTAssertTrue(yes.isHittable, id)
        XCTAssertLessThanOrEqual(title.frame.maxX, yes.frame.minX, "English text must not overlap choices: \(id)")
        XCTAssertGreaterThanOrEqual(yes.frame.width, 44, id)
        XCTAssertGreaterThanOrEqual(yes.frame.height, 44, id)
        XCTAssertNil(title.label.range(of: "[\u{3400}-\u{9fff}]", options: .regularExpression), id)
    }

    private func capture(_ name: String, _ app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "english-checklist-" + name; shot.lifetime = .keepAlways; add(shot)
    }

    func testSimpleEnglishRowsKeepChoicesAccessibleAndAnswersPersist() {
        let app = launch("simple")
        search("Furniture", app)
        checkRow("simple_32", app); capture("simple-furniture-top", app)
        checkRow("simple_41", app)
        XCTAssertEqual(app.staticTexts["mp.field.title.simple_40"].firstMatch.label, "Shoe storage is sufficient")
        XCTAssertEqual(app.staticTexts["mp.field.title.simple_41"].firstMatch.label, "Kitchen storage is sufficient")
        capture("simple-furniture-storage", app)
        app.buttons["mp.field.choice.simple_40.是"].tap()
        XCTAssertTrue(app.buttons["mp.field.choice.simple_40.是"].isSelected)
        search("Appliances", app)
        checkRow("simple_44", app); capture("simple-appliances", app)
        search("Hot and cold", app)
        checkRow("simple_26", app); capture("simple-bathroom", app)
        app.terminate(); app.launch()
        let house = app.buttons["house.首次填写"].firstMatch
        XCTAssertTrue(house.waitForExistence(timeout: 10)); house.tap()
        XCTAssertTrue(app.buttons["tab.清单"].waitForExistence(timeout: 3))
        search("storage", app)
        checkRow("simple_40", app)
        XCTAssertTrue(app.buttons["mp.field.choice.simple_40.是"].isSelected)
        capture("simple-storage-restored", app)
    }

    func testDetailedEnglishSearchFindsParallelChecksWithReadableChoices() {
        let app = launch("detailed")
        search("well-ventilated", app)
        for id in ["f23_0", "f23_1", "f23_2", "f23_3", "f23_4"] { checkRow(id, app) }
        capture("detailed-ventilation", app)
        search("water pressure", app)
        checkRow("885af4ce-e10e-4937-b745-95272deb90b7", app)
        capture("detailed-water-pressure", app)
        search("sufficient", app)
        checkRow("f51_0", app); capture("detailed-storage", app)
        search("Phone calls", app)
        for id in ["f85_0", "f85_1", "f85_2"] { checkRow(id, app) }
        capture("detailed-cellular-calls", app)
    }
}
