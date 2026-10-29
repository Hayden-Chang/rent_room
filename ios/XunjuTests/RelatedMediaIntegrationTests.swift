import XCTest
@testable import Xunju

@MainActor final class RelatedMediaIntegrationTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "related-business-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func media(_ name: String, field: String, type: String = "image", store: NativeStore) throws -> JSONValue {
        _ = try LocalMediaFiles.directory(in: store.records.directory, create: true)
        let path = "media/" + name + (type == "video" ? ".mp4" : ".jpg")
        try Data([1, 2, 3]).write(to: LocalMediaFiles.file(path, in: store.records.directory))
        return .object(["id": .string(name), "path": .string(path), "type": .string(type), "fieldId": .string(field), "caption": .string("")])
    }
    func testAutomaticAndChecklistShareOrderedFieldMediaNotesAndIndependentFlag() throws {
        let store = try store(), id = try store.add("关联检查"), field = "f38_result"
        try store.answer(id, field: field, value: .string("正常"))
        try store.answer(id, field: field, property: "issueFlag", value: .bool(true))
        try store.answer(id, field: field, property: "note", value: .string("雨后复查"))
        for (name, type) in [("one", "image"), ("two", "video"), ("three", "image"), ("four", "image")] {
            try store.call("addMedia", ["id": .string(id), "value": try media(name, field: field, type: type, store: store)])
        }
        try store.call("addMedia", ["id": .string(id), "value": try media("unrelated", field: "f1_6", store: store)])
        func automatic(_ current: NativeStore) throws -> JSONValue {
            try XCTUnwrap(try current.call("issues", ["id": .string(id)])["automatic"].array.first { $0.id == field })
        }
        let issue = try automatic(store), row = try XCTUnwrap(try store.form(id, query: "纱窗").flatMap { $0["rows"].array }.first { $0.id == field })
        XCTAssertEqual(issue["media"], row["media"]); XCTAssertEqual(issue["media"].array.map(\.id), ["one", "two", "three", "four"])
        XCTAssertEqual(issue["thumbnails"].array.map(\.id), ["one", "two", "three"])
        try store.answer(id, field: field, value: .string("有问题"))
        try store.answer(id, field: field, property: "issueFlag", value: .bool(false))
        XCTAssertTrue(try store.call("issues", ["id": .string(id)])["automatic"].array.isEmpty)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"][field]["value"].string, "有问题")
        XCTAssertEqual(restored.house(id)["answers"][field]["note"].string, "雨后复查")
        XCTAssertEqual(restored.house(id)["media"].array.count, 5)
        try restored.answer(id, field: field, property: "issueFlag", value: .bool(true))
        XCTAssertEqual(try automatic(restored)["media"].array.map(\.id), ["one", "two", "three", "four"])
        XCTAssertTrue(try automatic(restored)["media"].array.allSatisfy { FileManager.default.fileExists(atPath: (try? LocalMediaFiles.file($0["path"].string, in: restored.records.directory).path) ?? "") })
    }
    func testParentAnnotationsKeepMediaAndNeverBecomeEditableChildValues() throws {
        let store = try store(), id = try store.add("父节点"), node = "node:group:topic_11", category = "node:category:周边与小区"
        try store.answer(id, field: "f11_1", value: .string("150"))
        for target in [node, category] {
            try store.answer(id, field: target, property: "issueFlag", value: .bool(true))
            try store.answer(id, field: target, property: "note", value: .string("父级备注"))
            try store.call("addMedia", ["id": .string(id), "value": try media(target == node ? "group" : "category", field: target, store: store)])
            XCTAssertThrowsError(try store.answer(id, field: target, value: .string("不能写入")))
        }
        let issues = try store.call("issues", ["id": .string(id)])["automatic"].array
        XCTAssertEqual(Set(issues.map(\.id)), Set([node, category]))
        XCTAssertTrue(issues.allSatisfy { !$0["heading"].string.isEmpty && $0["value"].string.isEmpty })
        XCTAssertEqual(issues.first { $0.id == node }?["media"].array.map(\.id), ["group"])
        XCTAssertEqual(issues.first { $0.id == category }?["media"].array.map(\.id), ["category"])
        try store.archive(id, archived: true)
        let before = store.state
        XCTAssertThrowsError(try store.answer(id, field: node, property: "note", value: .string("不可写")))
        XCTAssertThrowsError(try store.call("editMedia", ["id": .string(id), "field": .string("group"), "property": .string("caption"), "value": .string("不可写")]))
        XCTAssertEqual(store.state, before)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["answers"]["f11_1"]["value"].string, "150")
        XCTAssertEqual(restored.house(id)["media"].array.count, 2)
    }
    func testRelatedMediaCaptionWriteFailurePreservesOriginalAndRetryDoesNotDuplicate() throws {
        let store = try store(), id = try store.add("失败重试")
        let item = try media("caption", field: "f38_result", store: store)
        try store.call("addMedia", ["id": .string(id), "value": item])
        let previous = store.records.directory.appending(path: "state.previous.json")
        try FileManager.default.removeItem(at: previous)
        try FileManager.default.createDirectory(at: previous, withIntermediateDirectories: false)
        let parameters: [String: JSONValue] = ["id": .string(id), "field": .string(item.id), "property": .string("caption"), "value": .string("复查")]
        XCTAssertThrowsError(try store.call("editMedia", parameters))
        XCTAssertEqual(store.house(id)["media"].array.first?["caption"].string, "")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try LocalMediaFiles.file(item["path"].string, in: store.records.directory).path))
        try FileManager.default.removeItem(at: previous)
        try store.call("editMedia", parameters)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.house(id)["media"].array.count, 1)
        XCTAssertEqual(restored.house(id)["media"].array.first?["caption"].string, "复查")
        XCTAssertEqual(restored.house(id)["media"].array.first?["fieldId"].string, "f38_result")
    }
}
