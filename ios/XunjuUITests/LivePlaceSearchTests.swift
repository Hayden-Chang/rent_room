import XCTest

/// Online integration evidence. Run explicitly; Apple availability is not an offline CI contract.
@MainActor final class LivePlaceSearchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCaliforniaAndStreetSearchReplaceChineseWorkplaceAndPersist() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
                               "--stub-system-review", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 5)); currency.tap()
        XCTAssertTrue(currency.waitForNonExistence(timeout: 5))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        let query = app.textFields["place.query"], address = app.textFields["workplace.address"]
        XCTAssertTrue(query.waitForExistence(timeout: 3))

        func search(_ text: String, latitude: ClosedRange<Double>, longitude: ClosedRange<Double>, capture: String) throws -> XCUIElement {
            query.tap(); XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
            query.typeText(text + "\n")
            let result = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 18), "Apple query \(text): \(app.staticTexts["place.message"].exists ? app.staticTexts["place.message"].label : "no result")")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = capture; attachment.lifetime = .keepAlways; add(attachment)
            // Production result IDs include the returned coordinate, independent of label localization.
            let coordinate = result.identifier.replacingOccurrences(of: "place.result.", with: "").split(separator: ":")[0].split(separator: ",")
            XCTAssertEqual(coordinate.count, 2)
            let lat = try XCTUnwrap(Double(coordinate[0])), lon = try XCTUnwrap(Double(coordinate[1]))
            XCTAssertTrue(latitude.contains(lat), "Unexpected latitude for \(text): \(lat)")
            XCTAssertTrue(longitude.contains(lon), "Unexpected longitude for \(text): \(lon)")
            return result
        }

        try search("上海东方明珠", latitude: 30...32, longitude: 120...123, capture: "live-01-shanghai-results").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        let chineseAddress = address.value as? String ?? ""
        XCTAssertFalse(chineseAddress.isEmpty)
        try search("California", latitude: 32...42.5, longitude: -125 ... -114, capture: "live-02-california-from-shanghai").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        XCTAssertNotEqual(address.value as? String, chineseAddress)

        try search("1 Apple Park Way, Cupertino, CA, United States", latitude: 37...38, longitude: -123 ... -121,
                   capture: "live-03-cupertino-street").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        let saved = try XCTUnwrap(address.value as? String)
        XCTAssertFalse(saved.isEmpty); XCTAssertNotEqual(saved, chineseAddress)
        XCTAssertEqual(app.buttons["place.mapToggle"].label, "展开地图")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 3)); XCTAssertEqual(address.value as? String, saved)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "live-04-us-address-after-relaunch"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
