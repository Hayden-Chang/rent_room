import XCTest
@testable import Xunju

@MainActor final class TopFloorTests: XCTestCase {
    private func store() throws -> NativeStore {
        let directory = FileManager.default.temporaryDirectory.appending(path: "top-floor-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try NativeStore(directory: directory)
    }
    private func field(_ store: NativeStore, _ id: String) throws -> JSONValue {
        try XCTUnwrap(try store.form(id, query: "顶楼").flatMap { $0["rows"].array }.first { $0.id == "f1_top" })
    }
    func testYesFlagsAndPresenterCancellationPersistsWithoutChangingAnswer() throws {
        let store = try store(), id = try store.add("顶楼")
        var row = try field(store, id)
        XCTAssertEqual(ChecklistPresentation.item(row).title, "顶楼")
        var selection = ChecklistPresentation.state(row); selection.selected = ["是"]
        try ChecklistPresentation.write(selection, from: row, houseID: id, store: store)
        row = try field(store, id); XCTAssertTrue(row["problem"].bool)
        try store.answer(id, field: "f1_top", property: "note", value: .string("保留备注"))
        row = try field(store, id)
        var cancelled = ChecklistPresentation.state(row); cancelled.flagged = false
        try ChecklistPresentation.write(cancelled, from: row, houseID: id, store: store)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertFalse(try field(reopened, id)["problem"].bool)
        XCTAssertEqual(reopened.house(id)["answers"]["f1_top"]["value"].string, "是")
        XCTAssertEqual(reopened.house(id)["answers"]["f1_top"]["note"].string, "保留备注")
        XCTAssertEqual(reopened.houses.first?.stats.done, 1)
        try reopened.answer(id, field: "f1_top", value: .string("否"))
        XCTAssertFalse(try field(reopened, id)["problem"].bool)
        try reopened.answer(id, field: "f1_top", value: .string("是"))
        XCTAssertTrue(try field(reopened, id)["problem"].bool)
    }
    func testLegacyNegativeQuestionMigratesOnceOnDiskAndThroughImport() throws {
        let store = try store(), id = try store.add("旧房源")
        let house = store.house(id)
        let topics = house["templateTopics"].array.map { topic in
            topic.setting("fields", to: .array(topic["fields"].array.map { field in
                field.id == "f1_top" ? field.setting("label", to: .string("非顶楼")).removing("badValue") : field
            }))
        }
        let old = house.removing("topFloorRevision").setting("templateTopics", to: .array(topics))
            .setting("answers", to: .object(["f1_top": .object(["value": .string("否"), "note": .string("旧备注"), "issueFlag": .bool(false)])]))
        let raw = store.state.setting("houses", to: .array([old]))
        try store.records.write(String(decoding: JSONEncoder().encode(raw), as: UTF8.self), keepPrevious: false)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(reopened.house(id)["answers"]["f1_top"]["value"].string, "是")
        XCTAssertEqual(try field(reopened, id)["label"].string, "顶楼")
        XCTAssertFalse(try field(reopened, id)["problem"].bool)
        let incoming = try reopened.call("prepareImport", ["value": raw])
        XCTAssertEqual(incoming.array.first?["answers"]["f1_top"]["value"].string, "是")
        try reopened.call("save")
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id), reopened.house(id))
    }
    func testReviewRouteRequiresExplicitComponentArgument() {
        XCTAssertEqual(ReviewSurface.parse(["app", "--component-review", "top-floor"]), .topFloor)
        XCTAssertNil(ReviewSurface.parse(["app", "top-floor"]))
        XCTAssertNil(ReviewSurface.parse(["app", "--component-review", "unknown"]))
    }
}
