import XCTest
@testable import Xunju

@MainActor final class ChecklistPresentationTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "checklist-format-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }

    func testEveryCategoryAndGroupFoldsOnlyItsDescendantsWithoutWritingAnswers() throws {
        let store = try store(), id = try store.add("逐项展开")
        let topics = store.house(id)["templateTopics"].array
        let categories = Set(topics.map { $0["category"].string })
        let groupIDs = Set(topics.flatMap { $0["path"].array.map(\.id) })
        var folds = Dictionary(uniqueKeysWithValues: (categories.union(groupIDs)).map { ($0, true) })
        let before = store.state
        let expanded = try store.form(id, folds: folds)
        XCTAssertEqual(expanded.count, 13)
        var groups = 0, deepRows = 0
        for section in expanded {
            let title = section["title"].string, rows = section["rows"].array
            XCTAssertEqual(ChecklistPresentation.item(section["header"]).kind, .category)
            folds[title] = false
            XCTAssertEqual(try store.form(id, folds: folds).first { $0["title"].string == title }?["rows"].array.count, 0)
            folds[title] = true
            for (index, row) in rows.enumerated() {
                XCTAssertLessThanOrEqual(ChecklistPresentation.indent(row), 24)
                if row["depth"].int >= 1 { deepRows += 1 }
                if row["kind"].string != "group" { continue }
                groups += 1
                XCTAssertEqual(ChecklistPresentation.item(row["swipe"]).kind, .group)
                let subtreeEnd = rows[(index + 1)...].firstIndex { $0["depth"].int <= row["depth"].int } ?? rows.endIndex
                let removed = Set(rows[(index + 1)..<subtreeEnd].map(\.rowKey))
                folds[row.id] = false
                let closed = try XCTUnwrap(try store.form(id, folds: folds).first { $0["title"].string == title })
                XCTAssertEqual(closed["rows"].array.map(\.rowKey), rows.filter { !removed.contains($0.rowKey) }.map(\.rowKey), row["title"].string)
                folds[row.id] = true
            }
        }
        XCTAssertGreaterThan(groups, 50)
        XCTAssertGreaterThan(deepRows, 0)
        // Imported/custom templates may be deeper than today's canonical tree.
        XCTAssertEqual(ChecklistPresentation.indent(.object(["depth": .number(4)])), 24)
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).state, before)
    }

    func testSharedChoiceAdapterPreservesMultipleOtherAndFlagAcrossRelaunch() throws {
        let store = try store(), id = try store.add("真实输入")
        func row(_ field: String) throws -> JSONValue {
            try XCTUnwrap(try store.call("catalog")["fields"].array.first { $0.id == field })
        }
        func rendered(_ field: String, query: String) throws -> JSONValue {
            try XCTUnwrap(try store.form(id, query: query).flatMap { $0["rows"].array }.first { $0.id == field })
        }
        _ = try row("f83_2")
        try store.call("group", ["id": .string(id), "group": .string("bb080b15-a843-4478-a4c6-5453ec0a2ac6"), "property": .string("result"), "value": .string("没有")])
        var field = try rendered("f83_2", query: "运营商")
        var value = ChecklistPresentation.state(field); value.selected = ["联通", "移动"]
        try ChecklistPresentation.write(value, from: field, houseID: id, store: store)
        field = try rendered("f83_2", query: "运营商")
        value = ChecklistPresentation.state(field); value.selected.remove("联通")
        try ChecklistPresentation.write(value, from: field, houseID: id, store: store)
        field = try rendered("f1_5", query: "朝向"); value = ChecklistPresentation.state(field); value.selected = ["其他"]
        try ChecklistPresentation.write(value, from: field, houseID: id, store: store)
        field = try rendered("f1_5", query: "朝向"); value = ChecklistPresentation.state(field); value.otherText = "双面采光"; value.flagged = true
        try ChecklistPresentation.write(value, from: field, houseID: id, store: store)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(reopened.house(id)["answers"]["f83_2"]["value"].array.map(\.string), ["移动"])
        XCTAssertEqual(reopened.house(id)["answers"]["f1_5"]["otherText"].string, "双面采光")
        XCTAssertTrue(reopened.house(id)["answers"]["f1_5"]["issueFlag"].bool)
    }

    func testDividersAndFieldTypesMatchRealFormIncludingDynamicCosts() throws {
        let store = try store(), id = try store.add("布局规则")
        let rows = try store.form(id, query: "费用").flatMap { $0["rows"].array }
        for (index, row) in rows.enumerated() where row["kind"].string == "field" {
            let item = ChecklistPresentation.item(row, hideDivider: ChecklistPresentation.hidesDivider(at: index, rows: rows))
            XCTAssertEqual(item.hideDivider, rows.indices.contains(index + 1) && rows[index + 1]["kind"].string == "group")
            XCTAssertEqual(item.options, row["options"].array.map { $0["value"].string })
        }
        let group = "019886c9-e108-45b4-a0c5-c20d594379e5"
        try store.call("addCost", ["id": .string(id), "group": .string(group), "value": .string("车位管理费")])
        let added = try XCTUnwrap(try store.form(id, query: "车位管理费").flatMap { $0["rows"].array }.first { $0["label"].string.contains("车位管理费") })
        XCTAssertEqual(ChecklistPresentation.item(added).kind, .number)
        XCTAssertGreaterThan(ChecklistPresentation.indent(added), 0)
    }
}
