import XCTest

@MainActor final class ChecklistFormatTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--business-test", UUID().uuidString, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        XCTAssertTrue(app.buttons["home.add"].waitForExistence(timeout: 10)); app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]; XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap(); name.typeText("展开折叠格式"); app.buttons["prompt.confirm"].tap()
        let next = app.buttons["coach.next"]; XCTAssertTrue(next.waitForExistence(timeout: 5))
        for _ in 0..<3 { next.tap() }
        app.buttons["coach.preference"].tap(); next.tap()
        XCTAssertTrue(app.textFields["mp.checklist.search"].waitForExistence(timeout: 3))
        return app
    }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        let scroll = app.scrollViews["mp.checklist.scroll"]
        for _ in 0..<30 {
            if element.isHittable && element.frame.minY >= scroll.frame.minY && element.frame.maxY <= scroll.frame.maxY - 110 { return }
            let down = element.exists && element.frame.minY < scroll.frame.minY
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: down ? 0.3 : 0.75))
                .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: down ? 0.75 : 0.3)))
        }
        XCTFail("无法滚动到 \(element.identifier)")
    }
    private func search(_ text: String, _ app: XCUIApplication) {
        app.buttons["回到顶部"].tap()
        let input = app.textFields["mp.checklist.search"]
        XCTAssertTrue(input.isHittable); input.tap()
        let old = input.value as? String ?? ""
        if old != "搜索检查项、结果或备注" { input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count)) }
        input.typeText(text); app.buttons["checklist.keyboard.done"].tap()
    }
    private func checkCategories(_ names: [String], _ app: XCUIApplication) {
        for name in names {
            search(name, app)
            let category = app.staticTexts["mp.field.title.node:category:\(name)"]
            XCTAssertTrue(category.waitForExistence(timeout: 3)); reveal(category, app)
            XCTAssertEqual(category.value as? String, "已展开")
            category.tap(); XCTAssertEqual(category.value as? String, "已折叠")
            capture("fold-category-\(name)", app)
            category.tap(); XCTAssertEqual(category.value as? String, "已展开")
            capture("expand-category-\(name)", app)
            let groupIDs = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mp.field.title.node:group:"))
                .allElementsBoundByIndex.map(\.identifier)
            for groupID in groupIDs {
                let group = app.staticTexts[groupID]
                reveal(group, app)
                XCTAssertGreaterThan(group.frame.width, 12, groupID)
                XCTAssertGreaterThanOrEqual(group.frame.minX, 31, groupID)
                XCTAssertLessThanOrEqual(group.frame.maxX, app.frame.width - 31, groupID)
                XCTAssertEqual(group.value as? String, "已展开", groupID)
                group.tap(); XCTAssertEqual(group.value as? String, "已折叠", groupID)
                capture("fold-\(groupID)", app)
                group.tap(); XCTAssertEqual(group.value as? String, "已展开", groupID)
                let choicePrefix = groupID.replacingOccurrences(of: "mp.field.title.", with: "mp.field.choice.") + "."
                for button in app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", choicePrefix)).allElementsBoundByIndex {
                    XCTAssertGreaterThanOrEqual(button.frame.minX, group.frame.maxX, button.identifier)
                    XCTAssertLessThanOrEqual(button.frame.maxX, app.frame.width - 31, button.identifier)
                }
                capture("expand-\(groupID)", app)
            }
            app.buttons["回到顶部"].tap()
            reveal(category, app); category.tap()
            XCTAssertEqual(category.value as? String, "已折叠")
        }
    }
    func testBasicSurroundingsLightAndNoiseFormats() {
        checkCategories(["房源基本信息", "周边与小区", "通风与采光", "隔音与噪音"], launch())
    }
    func testWallsBathroomKitchenAndFurnitureFormats() {
        checkCategories(["墙面地面与门窗", "卫生间", "厨房与水路", "卧室与家具收纳"], launch())
    }
    func testAppliancesPestsNetworkCostsAndContractFormats() {
        checkCategories(["家电", "虫害鼠害", "电路网络与隐私", "费用与付款", "身份与合同"], launch())
    }
    func testConditionalAbsenceAndRetainedFoldDoNotClearAnswers() {
        let app = launch()
        search("空调", app)
        let group = "node:group:topic_55"
        let normal = app.buttons["mp.field.choice.\(group).是"]
        reveal(normal, app); normal.tap()
        let answer = app.buttons["mp.field.choice.f55_1.否"]; reveal(answer, app); answer.tap()
        XCTAssertTrue(answer.isSelected)
        reveal(app.staticTexts["mp.field.title.\(group)"], app)
        app.buttons["mp.field.choice.\(group).没有"].tap()
        XCTAssertFalse(answer.exists)
        capture("conditional-aircon-absent", app)
        app.buttons["mp.field.choice.\(group).否"].tap()
        reveal(answer, app); XCTAssertTrue(answer.isSelected)
        reveal(app.staticTexts["mp.field.title.\(group)"], app)
        let title = app.staticTexts["mp.field.title.\(group)"]; reveal(title, app); title.tap()
        app.buttons["tab.总结"].tap(); app.buttons["tab.清单"].tap()
        XCTAssertEqual(app.textFields["mp.checklist.search"].value as? String, "空调")
        XCTAssertEqual(title.value as? String, "已折叠"); XCTAssertFalse(answer.exists)
        app.buttons["回到顶部"].tap()
        app.buttons["mp.phase.现场"].tap()
        XCTAssertEqual(title.value as? String, "已展开")
        app.buttons["mp.phase.全部"].tap()
        XCTAssertEqual(title.value as? String, "已折叠")
        reveal(title, app)
        title.tap(); reveal(answer, app); XCTAssertTrue(answer.isSelected)
        capture("conditional-aircon-restored", app)
    }
    func testWrappedChoicesOtherAndDynamicCostFormats() {
        let app = launch()
        search("朝向", app)
        let direction = app.buttons["mp.field.wheel.f1_5"]
        reveal(direction, app); direction.tap()
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForExistence(timeout: 3))
        let picker = app.pickerWheels.firstMatch; picker.adjust(toPickerWheelValue: "其他")
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "其他"), object: picker)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 3), .completed)
        app.buttons["wheel.confirm"].tap()
        XCTAssertTrue(app.otherElements["wheel.dialog"].waitForNonExistence(timeout: 3))
        let detail = app.textFields["mp.field.other.f1_5"]
        reveal(detail, app); detail.tap(); detail.typeText("南北双面采光"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(detail.value as? String, "南北双面采光")
        XCTAssertEqual(direction.value as? String, "其他")
        XCTAssertGreaterThan(detail.frame.minY, direction.frame.maxY)
        capture("wheel-direction-other", app)
        search("宽带", app)
        let absent = app.buttons["mp.field.choice.node:group:bb080b15-a843-4478-a4c6-5453ec0a2ac6.没有"]
        reveal(absent, app); absent.tap()
        search("运营商", app)
        let mobile = app.buttons["mp.field.choice.f83_2.移动"], unicom = app.buttons["mp.field.choice.f83_2.联通"]
        reveal(mobile, app); mobile.tap(); unicom.tap()
        XCTAssertTrue(mobile.isSelected); XCTAssertTrue(unicom.isSelected)
        capture("conditional-provider-multiple", app)
        search("周期费用", app)
        let cost = app.buttons["checklist.cost.019886c9-e108-45b4-a0c5-c20d594379e5"]
        reveal(cost, app); cost.tap()
        let input = app.textFields["mp.prompt.text"]; XCTAssertTrue(input.waitForExistence(timeout: 3))
        input.tap(); input.typeText("车位管理费"); app.buttons["mp.prompt.save"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "车位管理费")).firstMatch.waitForExistence(timeout: 3))
        XCTAssertEqual(app.textFields["mp.checklist.search"].value as? String, "搜索检查项、结果或备注")
        let added = app.textFields.matching(NSPredicate(format: "identifier BEGINSWITH %@", "mp.field.input.cost_")).firstMatch
        reveal(added, app); added.tap(); added.typeText("200"); app.buttons["checklist.keyboard.done"].tap()
        XCTAssertEqual(added.value as? String, "200")
        capture("dynamic-cost-expanded-and-saved", app)
    }
    func testConditionalProviderAndContractGroupsFoldWithoutLosingAnswers() {
        let app = launch()
        func fold(_ id: String, choice: XCUIElement) {
            let title = app.staticTexts["mp.field.title.node:group:" + id]
            reveal(title, app); XCTAssertEqual(title.value as? String, "已展开")
            title.tap(); XCTAssertEqual(title.value as? String, "已折叠"); XCTAssertFalse(choice.exists)
            capture("fold-mp.field.title.node:group:" + id, app)
            title.tap(); XCTAssertEqual(title.value as? String, "已展开"); XCTAssertTrue(choice.isSelected)
            capture("expand-mp.field.title.node:group:" + id, app)
        }
        search("宽带", app)
        let absent = app.buttons["mp.field.choice.node:group:bb080b15-a843-4478-a4c6-5453ec0a2ac6.没有"]
        reveal(absent, app); absent.tap()
        search("运营商", app)
        let mobile = app.buttons["mp.field.choice.f83_2.移动"]
        reveal(mobile, app); mobile.tap(); fold("topic_83", choice: mobile)
        for (party, group, field) in [("二房东", "topic_99", "f99_0"), ("中介", "topic_100", "f100_0")] {
            search("签约方身份", app)
            let choice = app.buttons["mp.field.choice.f98_3." + party]
            reveal(choice, app); choice.tap()
            search(party == "二房东" ? "二房东出租权限" : "中介委托与主体", app)
            let recorded = app.buttons["mp.field.choice." + field + ".是"]
            reveal(recorded, app); recorded.tap(); fold(group, choice: recorded)
        }
        search("签约方身份", app)
        let party = app.buttons["mp.field.choice.f98_3.二房东"]; reveal(party, app); party.tap()
        search("二房东出租权限", app)
        XCTAssertTrue(app.buttons["mp.field.choice.f99_0.是"].isSelected)
        capture("conditional-contract-answer-restored", app)
    }
}
