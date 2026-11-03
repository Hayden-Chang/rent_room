import XCTest

@MainActor
final class AppIconReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHomeScreenIconOpensInstalledApp() {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 10))

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icon = springboard.icons.matching(NSPredicate(format: "label IN %@", ["看房搭子", "RentVisit"])).firstMatch
        for _ in 0..<5 {
            if icon.exists && icon.isHittable { break }
            springboard.swipeLeft()
        }
        XCTAssertTrue(icon.exists && icon.isHittable, "The installed app must be visible on the Home Screen")
        let attachment = XCTAttachment(screenshot: springboard.screenshot())
        attachment.name = "home-screen-app-icon-correct-brand"
        attachment.lifetime = .keepAlways
        add(attachment)

        icon.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.buttons["setup.next"].waitForExistence(timeout: 5))
    }
}
