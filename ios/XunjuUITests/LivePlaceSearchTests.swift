import XCTest

/// Online integration evidence. Run explicitly; Apple availability is not an offline CI contract.
@MainActor final class LivePlaceSearchTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testCaliforniaAndStreetSearchReplaceChineseWorkplaceAndPersist() throws {
        try verifyAddressFlow(language: "zh-Hans", locale: "zh_CN", firstQuery: "上海东方明珠",
                              latitude: 30...32, longitude: 120...123, prefix: "live", queryLabel: "搜索地址", expandLabel: "展开地图")
    }

    func testEnglishUSAddressSearchAcrossStatesAndPersist() throws {
        try verifyAddressFlow(language: "en-US", locale: "en_US", firstQuery: "350 Fifth Avenue, New York, NY, United States",
                              latitude: 40...41, longitude: -75 ... -73, prefix: "us-english",
                              queryLabel: "Search address", expandLabel: "Expand Map")
    }

    private func verifyAddressFlow(language: String, locale: String, firstQuery: String,
                                   latitude: ClosedRange<Double>, longitude: ClosedRange<Double>,
                                   prefix: String, queryLabel: String, expandLabel: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
                               "--stub-system-review", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 5)); currency.tap()
        XCTAssertTrue(currency.waitForNonExistence(timeout: 5))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        let query = app.textFields["place.query"], address = app.textFields["workplace.address"]
        XCTAssertTrue(query.waitForExistence(timeout: 3))
        XCTAssertEqual(query.label, queryLabel, "Verify the actual app language before querying")

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

        try search(firstQuery, latitude: latitude, longitude: longitude, capture: "\(prefix)-01-origin-results").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        let originalAddress = address.value as? String ?? ""
        XCTAssertFalse(originalAddress.isEmpty)
        try search("California", latitude: 32...42.5, longitude: -125 ... -114, capture: "\(prefix)-02-california-results").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        XCTAssertNotEqual(address.value as? String, originalAddress)

        try search("1 Apple Park Way, Cupertino, CA, United States", latitude: 37...38, longitude: -123 ... -121,
                   capture: "\(prefix)-03-cupertino-street").tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'place.result.'")).firstMatch.waitForNonExistence(timeout: 4))
        let saved = try XCTUnwrap(address.value as? String)
        XCTAssertFalse(saved.isEmpty); XCTAssertNotEqual(saved, originalAddress)
        XCTAssertEqual(app.buttons["place.mapToggle"].label, expandLabel)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10))
        app.buttons["tab.我的"].tap(); app.buttons["local-settings.workplace"].tap()
        XCTAssertTrue(address.waitForExistence(timeout: 3)); XCTAssertEqual(address.value as? String, saved)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "\(prefix)-04-us-address-after-relaunch"; attachment.lifetime = .keepAlways; add(attachment)
    }
}
