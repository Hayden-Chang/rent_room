import XCTest
@testable import Xunju

@MainActor final class IssueDraftTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "issue-draft-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func file(_ id: String, _ store: NativeStore) throws -> JSONValue {
        _ = try LocalMediaFiles.directory(in: store.records.directory, create: true)
        let path = "media/\(id).jpg"
        try Data([1, 2, 3]).write(to: LocalMediaFiles.file(path, in: store.records.directory))
        return .object(["id": .string(id), "path": .string(path), "type": .string("image"), "caption": .string("")])
    }
    private func exists(_ item: JSONValue, _ store: NativeStore) throws -> Bool {
        FileManager.default.fileExists(atPath: try LocalMediaFiles.file(item["path"].string, in: store.records.directory).path)
    }
    func testSaveCommitsTextAndOrderedMediaOnceAndRelaunches() throws {
        let store = try store(), id = try store.add("问题影像")
        let draft = IssueDraft(store: store, houseID: id, issueID: "issue1", isNew: true, isCurrent: { true })
        let first = try file("first", store), second = try file("second", store)
        draft.title = " 漏水 "; draft.note = " 确认修复时间 "
        try draft.addImported(first); try draft.addImported(second)
        XCTAssertTrue(store.house(id)["issues"].array.isEmpty); XCTAssertTrue(store.house(id)["media"].array.isEmpty)
        XCTAssertTrue(draft.save()); XCTAssertFalse(draft.save())
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["issues"].array.first?["title"].string, "漏水")
        XCTAssertEqual(restored.house(id)["issues"].array.first?["note"].string, "确认修复时间")
        XCTAssertEqual(restored.house(id)["media"].array.map(\.id), ["first", "second"])
        XCTAssertTrue(restored.house(id)["media"].array.allSatisfy { $0["issueId"].string == "issue1" && $0["fieldId"].string.isEmpty })
        XCTAssertTrue(try exists(first, store)); XCTAssertTrue(try exists(second, store))
    }
    func testDiscardAndRemovalCleanOnlyNewDraftFiles() throws {
        let store = try store(), id = try store.add("放弃草稿"), saved = try file("saved", store)
        try store.call("writeIssue", ["id": .string(id), "issueId": .string("issue1"), "isNew": .bool(true),
            "draft": .object(["title": .string("原问题"), "note": .string("原备注"), "media": .array([saved])])])
        let draft = IssueDraft(store: store, houseID: id, issueID: "issue1", isNew: false, isCurrent: { true })
        let staged = try file("staged", store); try draft.addImported(staged)
        draft.remove(saved); draft.title = "修改后"
        XCTAssertTrue(try exists(saved, store)); XCTAssertTrue(draft.dirty)
        draft.discard(); draft.discard()
        XCTAssertFalse(try exists(staged, store)); XCTAssertTrue(try exists(saved, store))
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["issues"].array[0]["title"].string, "原问题")
        XCTAssertEqual(store.house(id)["media"].array.map(\.id), ["saved"])
    }
    func testSaveFailureRetainsDraftFilesAndCanRetryWithoutDuplication() throws {
        let store = try store(), id = try store.add("失败重试"), item = try file("retry", store)
        let draft = IssueDraft(store: store, houseID: id, issueID: "issue1", isNew: true, isCurrent: { true })
        draft.title = "待修"; draft.note = "保留文字"; try draft.addImported(item)
        let previous = store.records.directory.appending(path: "state.previous.json")
        try? FileManager.default.removeItem(at: previous)
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: false)
        XCTAssertFalse(draft.save()); XCTAssertFalse(draft.error.isEmpty); XCTAssertTrue(draft.dirty)
        XCTAssertEqual(draft.note, "保留文字"); XCTAssertTrue(try exists(item, store))
        XCTAssertTrue(store.house(id)["issues"].array.isEmpty); XCTAssertTrue(store.house(id)["media"].array.isEmpty)
        try FileManager.default.removeItem(at: previous)
        XCTAssertTrue(draft.save()); XCTAssertEqual(store.house(id)["media"].array.count, 1)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["issues"].array.count, 1)
    }
    func testValidationMissingFileAndDuplicateNeverPartiallySave() throws {
        let store = try store(), id = try store.add("影像校验"), item = try file("missing", store)
        let draft = IssueDraft(store: store, houseID: id, issueID: "issue1", isNew: true, isCurrent: { true })
        XCTAssertFalse(draft.save()); XCTAssertEqual(draft.titleError, "请填写问题标题")
        try draft.addImported(item); XCTAssertThrowsError(try draft.addImported(item))
        draft.title = "文件丢失"
        try FileManager.default.removeItem(at: LocalMediaFiles.file(item["path"].string, in: store.records.directory))
        XCTAssertFalse(draft.save()); XCTAssertFalse(draft.error.isEmpty); XCTAssertFalse(draft.closed)
        XCTAssertTrue(store.house(id)["issues"].array.isEmpty)
        draft.remove(item); XCTAssertTrue(draft.save())
    }
    func testArchiveOrAccountChangeRejectsDraftWriteAndImport() throws {
        let store = try store(), id = try store.add("只读保护"), item = try file("scope", store)
        var current = true
        let draft = IssueDraft(store: store, houseID: id, issueID: "issue1", isNew: true, isCurrent: { current })
        draft.title = "保留草稿"; try draft.addImported(item)
        try store.archive(id, archived: true)
        XCTAssertTrue(draft.readonly); XCTAssertFalse(draft.save()); XCTAssertThrowsError(try draft.addImported(try file("archive", store)))
        try store.archive(id, archived: false); current = false
        XCTAssertFalse(draft.save()); XCTAssertThrowsError(try draft.addImported(try file("other", store)))
        draft.discard(); XCTAssertFalse(try exists(item, store)); XCTAssertTrue(store.house(id)["issues"].array.isEmpty)
    }
    func testCleanupPreservesCurrentAndPreviousReferencesAndFailsClosed() throws {
        let store = try store(), id = try store.add("恢复保护"), item = try file("recovery", store), orphan = try file("orphan", store)
        try store.call("addMedia", ["id": .string(id), "value": item])
        LocalMediaReferences.discard([item["path"].string, orphan["path"].string], in: store)
        XCTAssertTrue(try exists(item, store)); XCTAssertFalse(try exists(orphan, store))
        try store.call("removeMedia", ["id": .string(id), "field": .string(item.id)])
        XCTAssertTrue(try LocalMediaReferences.paths(in: store).contains(item["path"].string))
        LocalMediaReferences.discard([item["path"].string], in: store); XCTAssertTrue(try exists(item, store))
        let unreadable = try file("unreadable", store)
        try Data("broken".utf8).write(to: store.records.directory.appending(path: "state.previous.json"))
        LocalMediaReferences.discard([unreadable["path"].string], in: store); XCTAssertTrue(try exists(unreadable, store))
    }
    func testGroupSkipRestorePreservesChildAnswerHeadingNotesFlagsAndMedia() throws {
        let store = try store(), id = try store.add("分组保留"), media = try file("group", store)
        let topic = try XCTUnwrap(store.house(id)["templateTopics"].array.first { $0["fields"].array.contains { $0.id == "f55_1" } })
        let group = try XCTUnwrap(topic["path"].array.last { $0["presence"].bool }), node = "node:group:" + group.id
        // Historic/custom snapshots can still contain a skippable group. Current
        // parking groups use the canonical absence choice instead.
        let house = store.house(id).setting("templateTopics", to: .array(store.house(id)["templateTopics"].array.map { topic in
            topic.setting("path", to: .array(topic["path"].array.map { $0.id == group.id ? $0.setting("skippable", to: .bool(true)) : $0 }))
        }))
        try store.call("import", ["houses": .array([house]), "replaceIds": .array([.string(id)])])
        try store.answer(id, field: "f55_1", value: .string("否"))
        try store.answer(id, field: "f55_1", property: "note", value: .string("噪音"))
        try store.answer(id, field: node, property: "note", value: .string("整组备注"))
        try store.answer(id, field: node, property: "issueFlag", value: .bool(true))
        try store.call("addMedia", ["id": .string(id), "value": media.setting("fieldId", to: .string(node))])
        let answers = store.house(id)["answers"], files = store.house(id)["media"]
        try store.call("group", ["id": .string(id), "group": .string(group.id), "property": .string("skip")])
        XCTAssertTrue(store.house(id)["groups"][group.id]["notApplicable"].bool)
        try store.call("group", ["id": .string(id), "group": .string(group.id), "property": .string("skip")])
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"], answers); XCTAssertEqual(restored.house(id)["media"], files)
        let row = try XCTUnwrap(try restored.form(id, query: "空调").flatMap { $0["rows"].array }.first { $0.id == group.id })
        XCTAssertFalse(row["skipped"].bool); XCTAssertEqual(row["swipe"]["note"].string, "整组备注"); XCTAssertTrue(row["swipe"]["problem"].bool)
    }
}
