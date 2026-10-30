import XCTest
import AVFAudio
@testable import Xunju

@MainActor final class ChecklistSoundTests: XCTestCase {
    private func makeStore() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "checklist-sound-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func choose(_ value: String, fieldID: String, query: String, id: String, store: NativeStore) throws -> ChecklistSound? {
        let field = try XCTUnwrap(store.form(id, query: query).flatMap { $0["rows"].array }.first { $0.id == fieldID })
        var state = ChecklistPresentation.state(field)
        if !state.selected.insert(value).inserted { state.selected.remove(value) }
        return try ChecklistPresentation.write(state, from: field, houseID: id, store: store)
    }

    func testPositiveProblemCancellationAndNotApplicableUseCommittedRules() throws {
        let store = try makeStore(), id = try store.add("提示音")
        try store.answer(id, field: "f77_0", property: "note", value: .string("原备注"))
        func select(_ value: String) throws -> ChecklistSound? {
            try choose(value, fieldID: "f77_0", query: "冬季水管", id: id, store: store)
        }
        XCTAssertEqual(try select("是"), .positive)
        XCTAssertNil(try select("是"))
        XCTAssertEqual(try select("否"), .problem)
        XCTAssertTrue(try store.call("issues", ["id": .string(id)])["automatic"].array.contains { $0.id == "f77_0" })
        XCTAssertNil(try select("否"))
        XCTAssertNil(try select("不涉及"))
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(reopened.house(id)["answers"]["f77_0"]["value"].string, "不涉及")
        XCTAssertEqual(reopened.house(id)["answers"]["f77_0"]["note"].string, "原备注")
    }

    func testNonliteralAndInvertedProblemsTakePriorityOverOptionWording() throws {
        let store = try makeStore(), id = try store.add("业务规则")
        for (field, query, value) in [("f21_1", "日照时段", "无"), ("f51_1", "鞋柜", "不够用"),
                                      ("f83_1", "网络类型", "无网络"), ("f1_top", "顶楼", "是")] {
            XCTAssertEqual(try choose(value, fieldID: field, query: query, id: id, store: store), .problem, field)
        }
        XCTAssertEqual(try choose("否", fieldID: "f1_top", query: "顶楼", id: id, store: store), .positive)
        XCTAssertEqual(try choose("够用", fieldID: "f51_1", query: "鞋柜", id: id, store: store), .positive)
        XCTAssertNil(try choose("没有", fieldID: "f51_1", query: "鞋柜", id: id, store: store))
        XCTAssertEqual(try choose("南", fieldID: "f1_5", query: "朝向", id: id, store: store), .positive)
        XCTAssertNil(try ChecklistPresentation.writeGroup("bb080b15-a843-4478-a4c6-5453ec0a2ac6", operation: "result", value: "没有", houseID: id, store: store))
        XCTAssertEqual(try choose("联通", fieldID: "f83_2", query: "运营商", id: id, store: store), .positive)
        XCTAssertEqual(try choose("移动", fieldID: "f83_2", query: "运营商", id: id, store: store), .positive)
        XCTAssertNil(try choose("联通", fieldID: "f83_2", query: "运营商", id: id, store: store))
    }

    func testManualOverrideDoesNotBecomeAutomaticProblemFeedback() throws {
        let store = try makeStore(), id = try store.add("手动标记")
        try store.answer(id, field: "f51_1", property: "issueFlag", value: .bool(false))
        XCTAssertEqual(try choose("不够用", fieldID: "f51_1", query: "鞋柜", id: id, store: store), .positive)
        XCTAssertFalse(try store.call("issues", ["id": .string(id)])["automatic"].array.contains { $0.id == "f51_1" })
        try store.answer(id, field: "f1_5", property: "issueFlag", value: .bool(true))
        XCTAssertEqual(try choose("南", fieldID: "f1_5", query: "朝向", id: id, store: store), .positive)
        XCTAssertTrue(store.house(id)["answers"]["f1_5"]["issueFlag"].bool)
    }

    func testParentBulkChoiceEmitsOneCueAndUndoStaysSilent() throws {
        let store = try makeStore(), id = try store.add("父项")
        func select(_ value: String) throws -> ChecklistSound? {
            try ChecklistPresentation.writeGroup("topic_37", operation: "result", value: value, houseID: id, store: store)
        }
        XCTAssertEqual(try select("否"), .problem)
        XCTAssertEqual(try select("是"), .positive)
        XCTAssertNil(try select("是"), "Bulk undo may restore old problems but is a deselection, not a new answer")
        XCTAssertTrue(try store.call("issues", ["id": .string(id)])["automatic"].array.contains { $0.id == "node:group:topic_37" })
        let before = store.house(id)
        _ = try store.form(id, folds: ["topic_37": false])
        XCTAssertEqual(store.house(id), before)
    }

    func testFailedSaveAndArchivedChoiceNeverReturnSuccessSound() throws {
        let store = try makeStore(), id = try store.add("保存失败")
        try store.archive(id, archived: true)
        XCTAssertThrowsError(try choose("是", fieldID: "f77_0", query: "冬季水管", id: id, store: store))
        try store.archive(id, archived: false)
        let stateURL = store.records.directory.appending(path: "state.json")
        try FileManager.default.removeItem(at: stateURL)
        try FileManager.default.createDirectory(at: stateURL, withIntermediateDirectories: false)
        XCTAssertNil(try choose("是", fieldID: "f77_0", query: "冬季水管", id: id, store: store))
        XCTAssertFalse(store.status.error.isEmpty)
    }

    func testBundledSoundsDecodeAsDistinctShortMonoCues() throws {
        var data: [Data] = []
        for sound in ChecklistSound.allCases {
            let url = try XCTUnwrap(sound.resourceURL)
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertEqual(player.numberOfChannels, 1)
            XCTAssertLessThanOrEqual(player.duration, 0.8)
            XCTAssertEqual(player.duration, sound == .problem ? 0.29 : 0.782770833, accuracy: 0.001)
            XCTAssertLessThan(try Data(contentsOf: url).count, 80_000)
            data.append(try Data(contentsOf: url))
        }
        XCTAssertNotEqual(data[0], data[1])
    }
}
