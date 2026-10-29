import XCTest

@MainActor extension XCUIApplication {
    private func frontmost(_ query: XCUIElementQuery) -> XCUIElement? {
        query.allElementsBoundByIndex.last(where: { $0.isHittable })
    }
    var homeAddButton: XCUIElement {
        buttons["home.add"].exists ? buttons["home.add"] : buttons["home.first"]
    }
    var navigationBackButton: XCUIElement {
        frontmost(buttons.matching(identifier: "navigation.back")) ?? navigationBars.buttons.firstMatch
    }
    func dismissKeyboardFromHeader() {
        navigationHeader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(keyboards.firstMatch.waitForNonExistence(timeout: 3))
    }
    var navigationHeader: XCUIElement {
        frontmost(otherElements.matching(identifier: "navigation.header")) ?? navigationBars.firstMatch
    }
}
