import XCTest
@testable import Xunju

final class NativeStoreTests: XCTestCase {
    @MainActor
    private func makeStore() throws -> NativeStore {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return try NativeStore(directory: directory)
    }

    @MainActor
    func testCanonicalCatalogAndRoundTripRetainAnswersAndZero() throws {
        let store = try makeStore()
        let catalog = try store.call("catalog")
        XCTAssertEqual(catalog["count"].int, 302)
        XCTAssertEqual(catalog["categories"].array.count, 13)
        let id = try store.add("原生房源")
        XCTAssertEqual(store.houses.first?.stats.total, 204)
        try store.answer(id, field: "f1_6", value: .string("0"))
        try store.answer(id, field: "f1_6", property: "note", value: .string("免租期"))
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"]["f1_6"]["value"].string, "0")
        XCTAssertEqual(restored.house(id)["answers"]["f1_6"]["note"].string, "免租期")
        XCTAssertEqual(restored.houses.first?.stats.done, 1)
        XCTAssertThrowsError(try store.answer(id, field: "f1_6", value: .string("-1")))
        XCTAssertEqual(store.house(id)["answers"]["f1_6"]["value"].string, "0")
    }

    @MainActor
    func testCapacityArchiveReadOnlyRestoreAndDeleteProtection() throws {
        let store = try makeStore()
        let first = try store.add("第一套")
        _ = try store.add("第二套")
        XCTAssertThrowsError(try store.add("第三套"))
        XCTAssertThrowsError(try store.call("remove", ["id": .string(first)]))
        try store.archive(first, archived: true)
        XCTAssertEqual(store.capacity.used, 1)
        XCTAssertThrowsError(try store.answer(first, field: "f1_6", value: .string("100")))
        _ = try store.add("第三套")
        XCTAssertThrowsError(try store.archive(first, archived: false))
        XCTAssertTrue(store.house(first)["archived"].bool)
        try store.call("remove", ["id": .string(first)])
        XCTAssertEqual(store.houses.count, 2)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).houses.count, 2)
    }

    @MainActor
    func testConditionalGroupKeepsHiddenAnswersNotesAndProblemFlag() throws {
        let store = try makeStore()
        let id = try store.add("空调检查")
        let fields = try store.call("catalog")["fields"].array
        let ac = try XCTUnwrap(fields.first { $0.id == "f55_1" })
        let target = ac.id
        try store.answer(id, field: target, value: .string("否"))
        try store.answer(id, field: target, property: "note", value: .string("噪音较大"))
        try store.answer(id, field: target, property: "issueFlag", value: .bool(true))
        let topics = store.house(id)["templateTopics"].array
        let topic = try XCTUnwrap(topics.first { $0["fields"].array.contains { $0.id == target } })
        let group = try XCTUnwrap(topic["path"].array.last { $0["presence"].bool })
        try store.call("group", ["id": .string(id), "group": .string(group.id), "property": .string("result"), "value": .string("正常")])
        let before = store.house(id)["answers"][target]
        try store.call("group", ["id": .string(id), "group": .string(group.id), "property": .string("result"), "value": .string("没有")])
        XCTAssertEqual(store.house(id)["answers"][target], before)
        XCTAssertEqual(store.houses.first?.stats.issues, 0)
        XCTAssertLessThan(store.houses.first?.stats.total ?? 999, 214)
        try store.call("group", ["id": .string(id), "group": .string(group.id), "property": .string("result"), "value": .string("有问题")])
        XCTAssertTrue(store.house(id)["answers"][target]["issueFlag"].bool)
    }

    @MainActor
    func testIndependentIssueFlagFilteringAndCollapsedFormDoNotMutate() throws {
        let store = try makeStore()
        let id = try store.add("筛选检查")
        let fields = try store.call("catalog")["fields"].array
        let field = try XCTUnwrap(fields.first { $0.id == "f38_result" })
        try store.answer(id, field: field.id, value: .string("正常"))
        try store.answer(id, field: field.id, property: "issueFlag", value: .bool(true))
        let before = store.state
        let collapsed = try store.form(id)
        XCTAssertTrue(collapsed.allSatisfy { !$0["expanded"].bool })
        let filtered = try store.form(id, query: "纱窗", filters: ["已记录", "有备注"])
        let row = try XCTUnwrap(filtered.flatMap { $0["rows"].array }.first { $0.id == field.id })
        XCTAssertEqual(row["options"].array.map { $0["label"].string }, ["是", "否", "没有"])
        XCTAssertTrue(row["problem"].bool)
        XCTAssertEqual(store.state, before)
        try store.answer(id, field: field.id, property: "issueFlag", value: .bool(false))
        XCTAssertEqual(store.house(id)["answers"][field.id]["value"].string, "正常")
    }

    @MainActor
    func testManualIssueAndSummaryComparisonPersist() throws {
        let store = try makeStore()
        let id = try store.add("A")
        let second = try store.add("B")
        let draft: JSONValue = .object(["title": .string("漏水"), "note": .string("确认修复时间"), "media": .array([])])
        try store.call("writeIssue", ["id": .string(id), "issueId": .string("issue1"), "isNew": .bool(true), "draft": draft])
        XCTAssertEqual(store.houses.first?.stats.issues, 1)
        try store.call("resolveIssue", ["id": .string(id), "issueId": .string("issue1")])
        XCTAssertEqual(store.houses.first?.stats.issues, 0)
        try store.call("summary", ["id": .string(id), "property": .string("decision"), "value": .string("考虑租住")])
        try store.call("summary", ["id": .string(id), "property": .string("summary"), "value": .string("采光好")])
        let rows = try store.call("compare", ["ids": .array([.string(id), .string(second)]), "differences": .bool(true)]).array
        XCTAssertEqual(rows.first { $0.id == "decision" }?["values"].array.map(\.string), ["考虑租住", "待决定"])
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["summary"].string, "采光好")
        XCTAssertTrue(restored.house(id)["issues"].array[0]["resolved"].bool)
        XCTAssertThrowsError(try store.call("compare", ["ids": .array([.string(id), .string(id)])]))
    }

    @MainActor
    func testImportIsAtomicAndPreservesGlobalSettings() throws {
        let store = try makeStore()
        let id = try store.add("原有")
        try store.call("settings", ["property": .string("workplace"), "value": .string("原有公司")])
        let original = store.state
        let incoming = try store.call("prepareImport", ["value": store.state]).array
        XCTAssertThrowsError(try store.call("import", ["houses": .array(incoming), "replaceIds": .array([])]))
        XCTAssertEqual(store.state, original)
        try store.call("import", ["houses": .array(incoming), "replaceIds": .array([.string(id)])])
        XCTAssertEqual(store.state["settings"]["workplace"].string, "原有公司")
        XCTAssertEqual(store.houses.count, 1)
        XCTAssertThrowsError(try store.call("import", ["houses": .array(incoming), "replaceIds": .array([.string("missing")])]))
        XCTAssertEqual(store.houses.count, 1)
    }

    @MainActor
    func testCorruptFileBlocksWritesAndRecoveryPreservesOriginal() throws {
        let store = try makeStore()
        let id = try store.add("保留记录")
        try store.answer(id, field: "f1_6", value: .string("2000"))
        let url = store.records.directory.appendingPathComponent("state.json")
        try Data("broken-json".utf8).write(to: url)
        let blocked = try NativeStore(directory: store.records.directory)
        XCTAssertTrue(blocked.status.blocked)
        XCTAssertThrowsError(try blocked.add("不得覆盖"))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "broken-json")
        try blocked.call("recover")
        XCTAssertFalse(blocked.status.blocked)
        XCTAssertEqual(blocked.houses.first?.name, "保留记录")
        let files = try FileManager.default.contentsOfDirectory(atPath: store.records.directory.path)
        XCTAssertEqual(files.filter { $0.hasPrefix("state.corrupt.") }.count, 1)
    }

    @MainActor
    func testFailedDurableAddRollsBackWhileOrdinaryAnswerStaysInSession() throws {
        let store = try makeStore()
        let id = try store.add("原有房源")
        let current = store.records.directory.appendingPathComponent("state.json")
        try FileManager.default.removeItem(at: current)
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: false)
        XCTAssertThrowsError(try store.add("未保存房源"))
        XCTAssertEqual(store.houses.count, 1)
        try store.answer(id, field: "f1_6", value: .string("2800"))
        XCTAssertFalse(store.status.error.isEmpty)
        XCTAssertEqual(store.house(id)["answers"]["f1_6"]["value"].string, "2800")
        XCTAssertThrowsError(try store.archive(id, archived: true))
        XCTAssertFalse(store.house(id)["archived"].bool)
        try FileManager.default.removeItem(at: current)
        try store.call("save")
        XCTAssertTrue(store.status.error.isEmpty)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).houses.first?.rent, "2800")
    }
}
