import XCTest
@testable import Xunju

@MainActor final class AutomaticChoiceIssueTests: XCTestCase {
    private let cases = [
        ("f51_1", "鞋柜", "不够用", "够用"),
        ("f51_2", "厨房收纳", "不够用", "没有"),
        ("f120_0", "可配合办理居住证", "否", "不涉及"),
        ("f21_1", "日照时段", "无", "上午"),
        ("f62_1", "出热水速度", "大于 1 分钟", "1分钟内"),
        ("f83_1", "网络类型", "无网络", "独立宽带")
    ]
    private func makeStore() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "automatic-choice-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func field(_ store: NativeStore, _ id: String, _ fieldID: String, _ query: String) throws -> JSONValue {
        try XCTUnwrap(store.form(id, query: query).flatMap { $0["rows"].array }.first { $0.id == fieldID })
    }
    private func choose(_ value: String, _ store: NativeStore, _ id: String, _ fieldID: String, _ query: String) throws {
        let row = try field(store, id, fieldID, query); var state = ChecklistPresentation.state(row)
        state.selected = value.isEmpty ? [] : [value]
        try ChecklistPresentation.write(state, from: row, houseID: id, store: store)
    }
    func testAllSixChoicesCreateIssuesAndKeepManualPriorityAcrossReload() throws {
        let store = try makeStore(), id = try store.add("自动异常")
        for (fieldID, label, bad, _) in cases {
            try choose(bad, store, id, fieldID, label)
            XCTAssertTrue(try field(store, id, fieldID, label)["problem"].bool, label)
        }
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(reopened.houses.first?.stats.issues, 6)
        XCTAssertEqual(Set(try reopened.call("issues", ["id": .string(id)])["automatic"].array.map(\.id)), Set(cases.map { $0.0 }))
        for (fieldID, label, bad, good) in cases {
            try choose(good, reopened, id, fieldID, label)
            XCTAssertFalse(try field(reopened, id, fieldID, label)["problem"].bool, label)
            try choose("", reopened, id, fieldID, label)
            XCTAssertFalse(try field(reopened, id, fieldID, label)["problem"].bool, label)
            for flag in [true, false] {
                let row = try field(reopened, id, fieldID, label); var state = ChecklistPresentation.state(row); state.flagged = flag
                try ChecklistPresentation.write(state, from: row, houseID: id, store: reopened)
                for value in [bad, good, ""] {
                    try choose(value, reopened, id, fieldID, label)
                    XCTAssertEqual(try field(reopened, id, fieldID, label)["problem"].bool, flag, label)
                }
            }
        }
        XCTAssertEqual(reopened.houses.first?.stats.issues, 0)
    }
    func testExistingAnswersAndNotesAreRecognizedWithoutRewritingTheSnapshot() throws {
        let store = try makeStore(), id = try store.add("旧异常记录")
        for (fieldID, label, bad, _) in cases {
            try store.answer(id, field: fieldID, value: .string(bad))
            try store.answer(id, field: fieldID, property: "note", value: .string("保留" + label + "备注"))
        }
        let before = store.house(id), reopened = try NativeStore(directory: store.records.directory)
        for (fieldID, label, _, _) in cases {
            let row = try field(reopened, id, fieldID, label)
            XCTAssertTrue(row["problem"].bool, label)
            XCTAssertEqual(row["note"].string, "保留" + label + "备注")
        }
        XCTAssertEqual(reopened.house(id), before)
    }
}
