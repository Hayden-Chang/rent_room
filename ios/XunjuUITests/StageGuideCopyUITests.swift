import XCTest

@MainActor final class StageGuideCopyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func verifyGuide(english: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", english ? "(en)" : "(zh-Hans)",
                               "-AppleLocale", english ? "en_US" : "zh_CN"]
        app.launch()
        let next = app.buttons["setup.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10)); next.tap()
        let simple = app.buttons["setup.mode.simple"]
        XCTAssertTrue(simple.waitForExistence(timeout: 3)); simple.tap(); next.tap()
        let decline = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(decline.waitForExistence(timeout: 5)); decline.tap()
        XCTAssertTrue(decline.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.homeAddButton.waitForExistence(timeout: 5)); app.homeAddButton.tap()
        let confirm = app.buttons["prompt.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3)); confirm.tap()
        let title = app.staticTexts["coach.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, english ? "Three Stages of Home Viewing" : "看房的三个阶段")
        let message = app.otherElements["xiaoda.message"].firstMatch
        XCTAssertTrue(message.exists); message.tap()
        let finished = expectation(for: NSPredicate(format: "value == %@", english ? "Show Full" : "完整显示"), evaluatedWith: message)
        wait(for: [finished], timeout: 3)
        let keys = ["房源", "现场", "询问签约"]
        let labels = english ? ["Basic Info", "On-site Inspection", "Expenses & Contract"] : ["基本情况", "现场检查", "费用与合同"]
        let lines = message.label.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4)
        for (index, label) in labels.enumerated() {
            XCTAssertEqual(app.buttons["mp.phase." + keys[index]].label, label)
            XCTAssertTrue(lines[index + 1].contains(label))
        }
        let card = app.otherElements["coach.card"]
        XCTAssertGreaterThanOrEqual(card.frame.minX, 0)
        XCTAssertLessThanOrEqual(card.frame.maxX, app.frame.maxX)
        XCTAssertTrue(app.buttons["coach.next"].isHittable)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = english ? "stage-guide-english" : "stage-guide-chinese"
        attachment.lifetime = .keepAlways; add(attachment)
        app.buttons["coach.next"].tap()
        XCTAssertEqual(title.label, english ? "Find what you want to check" : "找到你想看的内容")
    }

    func testEnglishGuideRepeatsItsPhaseTabLabels() { verifyGuide(english: true) }
    func testChineseGuideKeepsMatchingPhaseTabLabels() { verifyGuide(english: false) }
}
