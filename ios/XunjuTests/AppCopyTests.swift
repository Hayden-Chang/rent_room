import XCTest
@testable import Xunju

@MainActor final class AppCopyTests: XCTestCase {
    func testPackagedEnglishCatalogPermissionsAndMoneyUnits() throws {
        XCTAssertEqual(AppCopy.translations.count, 1322)
        for (source, english) in AppCopy.translations {
            XCTAssertNil(english.range(of: #"[\u3400-\u9fff]"#, options: .regularExpression), source)
        }
        let prior = AppLanguage.shared.value; AppLanguage.shared.value = .english
        defer { AppLanguage.shared.value = prior }
        let electric = AppCopy.moneyLabel("电费（元/度）", currency: "EUR")
        XCTAssertTrue(electric.contains("EUR")); XCTAssertFalse(electric.contains("CNY"))
        XCTAssertEqual(AppCopy.moneyLabel("单元清洁", currency: "GBP", verbatim: true), "单元清洁（GBP）")
        let url = try XCTUnwrap(Bundle.main.url(forResource: "InfoPlist", withExtension: "strings", subdirectory: "en.lproj"))
        let permissions = try XCTUnwrap(try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String]).values.joined(separator: " ")
        XCTAssertTrue(permissions.contains("USD")); XCTAssertFalse(permissions.contains("获取当前位置"))
    }
    func testCanonicalComparisonAndWheelUnitsPreserveCustomValues() throws {
        let prior = AppLanguage.shared.value; AppLanguage.shared.value = .english
        defer { AppLanguage.shared.value = prior }
        XCTAssertNotNil(AppCopy.shareCoverURL)
        XCTAssertEqual(AppCopy.shareCoverURL?.lastPathComponent, "InspectionShareCover-en.png")
        let wheel = try XCTUnwrap(WheelFieldSpec.all["f116_1"])
        XCTAssertEqual(wheel.display("放弃"), "放弃")
        XCTAssertNil(wheel.display("3 天").range(of: #"[\u3400-\u9fff]"#, options: .regularExpression))
        let root = FileManager.default.temporaryDirectory.appending(path: "comparison-copy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NativeStore(directory: root, freeLimit: 2), a = try store.add("放弃"), b = try store.add("不涉及")
        try store.answer(a, field: "f116_1", value: .string("放弃"))
        try store.answer(b, field: "f116_1", value: .string("3 天"))
        try store.answer(a, field: "f88_3", value: .string("其他"))
        try store.answer(a, field: "f88_3", property: "otherText", value: .string("放弃"))
        let rows = try store.call("compare", ["ids": .array([.string(a), .string(b)])]).array
        let legacy = try XCTUnwrap(rows.first { $0.id == "f116_1" })
        XCTAssertEqual(legacy["localized"].array, [.bool(false), .bool(true)])
        XCTAssertEqual(AppCopy.comparisonValue(legacy, index: 0), "放弃")
        XCTAssertNil(AppCopy.comparisonValue(legacy, index: 1).range(of: #"[\u3400-\u9fff]"#, options: .regularExpression))
        let other = try XCTUnwrap(rows.first { $0.id == "f88_3" })
        let display = AppCopy.comparisonValue(other, index: 0)
        XCTAssertTrue(display.contains("放弃")); XCTAssertFalse(display.contains("其他"))
        AppLanguage.shared.value = .chinese
        XCTAssertEqual(AppCopy.comparisonValue(other, index: 0), "其他：放弃")
        XCTAssertEqual(AppCopy.shareCoverURL?.lastPathComponent, "InspectionShareCover.jpg")
    }
    func testEnglishComparisonCostLabelsAreFullyLocalized() throws {
        let prior = AppLanguage.shared.value; AppLanguage.shared.value = .english
        defer { AppLanguage.shared.value = prior }
        let root = FileManager.default.temporaryDirectory.appending(path: "comparison-labels-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NativeStore(directory: root, freeLimit: 2), a = try store.add("A"), b = try store.add("B")
        let rows = try store.call("compare", ["ids": .array([.string(a), .string(b)])]).array.filter { $0["currency"].bool }
        XCTAssertTrue(rows.contains { $0.id == "f1_6" })
        for row in rows {
            XCTAssertNil(AppCopy.fieldLabel(row["label"].string, id: row.id).range(of: #"[\u3400-\u9fff]"#, options: .regularExpression), row["label"].string)
        }
    }
    func testCanonicalTemplateArgumentsTranslateWhileUserNamesStayVerbatim() {
        let canonical = "先看看「房源基本信息」吧。"
        let translated = AppCopy.text(canonical, language: .english, translatingArguments: true)
        XCTAssertNil(translated.range(of: #"[\u3400-\u9fff]"#, options: .regularExpression))
        let userName = "本机已有「放弃」，请选择处理方式"
        let message = AppCopy.text(userName, language: .english)
        XCTAssertTrue(message.contains("放弃")); XCTAssertFalse(message.contains("请选择"))
        XCTAssertEqual(AppCopy.text(canonical, language: .chinese), canonical)
        XCTAssertTrue(AppCopy.text("检查 2 / 10", language: .english).contains("2 / 10"))
    }
    func testEnglishSearchFindsCanonicalRentWithoutMutatingSavedAnswers() throws {
        let prior = AppLanguage.shared.value; AppLanguage.shared.value = .english
        defer { AppLanguage.shared.value = prior }
        let root = FileManager.default.temporaryDirectory.appending(path: "copy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NativeStore(directory: root)
        let id = try store.add("放弃")
        try store.answer(id, field: "f1_6", value: .string("2000"))
        let before = store.state
        let result = try store.form(id, query: "rent")
        XCTAssertTrue(result.flatMap { $0["rows"].array }.contains { $0.id == "f1_6" })
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(store.house(id)["name"].string, "放弃")
        XCTAssertEqual(store.house(id)["answers"]["f1_6"]["value"].string, "2000")
    }
}
