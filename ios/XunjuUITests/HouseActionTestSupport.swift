import XCTest

@MainActor extension XCUIApplication {
    func confirmArchiveFromHouseMenu() {
        let archive = buttons["归档房源"]
        XCTAssertTrue(archive.waitForExistence(timeout: 3)); archive.tap()
        let confirm = buttons["mp.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.tap()
    }
}
