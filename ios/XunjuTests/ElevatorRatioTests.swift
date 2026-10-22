import XCTest
@testable import Xunju

@MainActor final class ElevatorRatioTests: XCTestCase {
    private let fieldID = "f16_0", options = ["≤ 1:3", "1:4", "≥ 1:5"]
    private func makeStore() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "elevator-ratio-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func field(_ store: NativeStore, _ id: String) throws -> JSONValue {
        try XCTUnwrap(store.form(id, query: "电梯住户比").flatMap { $0["rows"].array }.first { $0.id == fieldID })
    }
    private func choose(_ value: String, _ store: NativeStore, _ id: String) throws {
        let row = try field(store, id); var state = ChecklistPresentation.state(row)
        state.selected = value.isEmpty ? [] : [value]
        try ChecklistPresentation.write(state, from: row, houseID: id, store: store)
    }
    func testNativeChoicesFlagHighestRatioAndKeepManualPriorityAcrossReload() throws {
        let store = try makeStore(), id = try store.add("电梯阈值")
        try store.call("group", ["id": .string(id), "group": .string("topic_16"), "property": .string("result"), "value": .string("是")])
        XCTAssertEqual(try field(store, id)["options"].array.map { $0["value"].string }, options)
        for value in options + [""] {
            try choose(value, store, id)
            XCTAssertEqual(try field(store, id)["problem"].bool, value == "≥ 1:5")
            XCTAssertEqual(store.houses.first?.stats.issues, value == "≥ 1:5" ? 1 : 0)
        }
        try choose("≥ 1:5", store, id)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertTrue(try field(reopened, id)["problem"].bool)
        XCTAssertEqual(try reopened.call("issues", ["id": .string(id)])["automatic"].array.map(\.id), [fieldID])
        var row = try field(reopened, id), state = ChecklistPresentation.state(row); state.flagged = false
        try ChecklistPresentation.write(state, from: row, houseID: id, store: reopened)
        try choose("1:4", reopened, id); try choose("≥ 1:5", reopened, id)
        XCTAssertFalse(try field(reopened, id)["problem"].bool)
        row = try field(reopened, id); state = ChecklistPresentation.state(row); state.flagged = true
        try ChecklistPresentation.write(state, from: row, houseID: id, store: reopened)
        try choose("≤ 1:3", reopened, id)
        XCTAssertTrue(try field(reopened, id)["problem"].bool)
    }
    func testLegacyTemplateAndAnswerDisplayNewChoiceWithoutErasingOriginalData() throws {
        let store = try makeStore(), id = try store.add("旧电梯记录")
        try store.call("group", ["id": .string(id), "group": .string("topic_16"), "property": .string("result"), "value": .string("是")])
        try store.answer(id, field: fieldID, value: .string(">1:5（拥挤）"))
        try store.answer(id, field: fieldID, property: "note", value: .string("保留原备注"))
        var house = store.house(id)
        let oldOptions: JSONValue = .array(["<1:3（优质）", "1:4（高峰等待）", ">1:5（拥挤）"].map(JSONValue.string))
        house = house.setting("templateTopics", to: .array(house["templateTopics"].array.map { topic in
            topic.setting("fields", to: .array(topic["fields"].array.map { field in field.id == fieldID ? field.setting("options", to: oldOptions) : field }))
        }))
        let snapshot = store.state.setting("houses", to: .array([house]))
        try store.records.write(String(decoding: JSONEncoder().encode(snapshot), as: UTF8.self), keepPrevious: false)
        let reopened = try NativeStore(directory: store.records.directory), before = reopened.house(id), row = try field(reopened, id)
        XCTAssertEqual(row["value"].string, "≥ 1:5")
        XCTAssertEqual(row["options"].array.map { $0["value"].string }, options)
        XCTAssertTrue(row["problem"].bool); XCTAssertEqual(row["note"].string, "保留原备注")
        XCTAssertEqual(reopened.house(id), before)
        try choose("", reopened, id)
        XCTAssertFalse(try field(reopened, id)["problem"].bool)
    }
}
