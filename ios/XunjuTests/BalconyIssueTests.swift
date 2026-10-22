import XCTest
@testable import Xunju

@MainActor final class BalconyIssueTests: XCTestCase {
    private let fieldID = "f1_balcony"
    private func makeStore() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "balcony-issue-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func field(_ store: NativeStore, _ id: String) throws -> JSONValue {
        try XCTUnwrap(store.form(id, query: "有阳台").flatMap { $0["rows"].array }.first { $0.id == fieldID })
    }
    private func choose(_ value: String, _ store: NativeStore, _ id: String) throws {
        let row = try field(store, id)
        var state = ChecklistPresentation.state(row)
        state.selected = value.isEmpty ? [] : [value]
        try ChecklistPresentation.write(state, from: row, houseID: id, store: store)
    }
    func testChoiceAdapterAutomaticallyFlagsNoAndClearsYesOrUnansweredAcrossReload() throws {
        let store = try makeStore(), id = try store.add("阳台异常")
        XCTAssertFalse(try field(store, id)["problem"].bool)
        try choose("否", store, id)
        XCTAssertTrue(try field(store, id)["problem"].bool)
        XCTAssertEqual(try store.call("issues", ["id": .string(id)])["automatic"].array.map(\.id), [fieldID])
        XCTAssertEqual(store.houses.first?.stats.issues, 1)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertTrue(try field(reopened, id)["problem"].bool)
        for value in ["是", ""] {
            try choose(value, reopened, id)
            XCTAssertFalse(try field(reopened, id)["problem"].bool)
            XCTAssertEqual(reopened.houses.first?.stats.issues, 0)
        }
    }
    func testLegacySnapshotAndManualOverridesPreserveOriginalAnswerAndNote() throws {
        let store = try makeStore(), id = try store.add("旧阳台记录")
        try store.answer(id, field: fieldID, value: .string("否"))
        try store.answer(id, field: fieldID, property: "note", value: .string("保留原备注"))
        var house = store.house(id)
        let topics = house["templateTopics"].array.map { topic in
            topic.setting("fields", to: .array(topic["fields"].array.map { field in
                field.id == fieldID ? field.setting("fact", to: .bool(true)).removing("badValue") : field
            }))
        }
        house = house.setting("templateTopics", to: .array(topics))
        let state = store.state.setting("houses", to: .array([house]))
        try store.records.write(String(decoding: JSONEncoder().encode(state), as: UTF8.self), keepPrevious: false)
        let reopened = try NativeStore(directory: store.records.directory)
        let before = reopened.house(id)
        XCTAssertTrue(try field(reopened, id)["problem"].bool)
        XCTAssertEqual(reopened.house(id), before)
        for flagged in [false, true] {
            let row = try field(reopened, id)
            var presentation = ChecklistPresentation.state(row); presentation.flagged = flagged
            try ChecklistPresentation.write(presentation, from: row, houseID: id, store: reopened)
            for value in ["否", "是", ""] {
                try choose(value, reopened, id)
                XCTAssertEqual(try field(reopened, id)["problem"].bool, flagged)
            }
        }
        XCTAssertEqual(reopened.house(id)["answers"][fieldID]["note"].string, "保留原备注")
        XCTAssertEqual(reopened.house(id)["templateTopics"], house["templateTopics"])
    }
}
