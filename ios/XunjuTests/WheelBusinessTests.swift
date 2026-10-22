import XCTest
@testable import Xunju

@MainActor final class WheelBusinessTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "wheel-business-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func field(_ id: String, house: String, store: NativeStore) throws -> JSONValue {
        let catalog = try store.call("catalog")["fields"].array
        let label = try XCTUnwrap(catalog.first { $0.id == id })["label"].string
        return try XCTUnwrap(try store.form(house, query: label).flatMap { $0["rows"].array }.first { $0.id == id })
    }
    func testRealFormRoutesAllSeventeenWheelsAndKeepsMoneyManual() throws {
        let store = try store(), id = try store.add("实际表单")
        for key in WheelFieldSpec.all.keys {
            let row = try field(key, house: id, store: store)
            XCTAssertEqual(ChecklistPresentation.item(row).kind, .wheel, key)
            XCTAssertTrue(row["inline"].bool)
        }
        XCTAssertEqual(ChecklistPresentation.item(try field("f1_6", house: id, store: store)).kind, .number)
    }
    func testConfirmedAnswersReloadKeepAnnotationsOtherAndEmptyZero() throws {
        let store = try store(), id = try store.add("保存验证"), presenter = WheelInputPresentation()
        let floor = "fc76beec-52e3-4fe9-a937-dec254d4cc4f"
        try store.answer(id, field: floor, property: "note", value: .string("保留备注"))
        try store.answer(id, field: floor, property: "issueFlag", value: .bool(true))
        presenter.open(houseID: id, field: try field(floor, house: id, store: store), store: store)
        XCTAssertEqual(store.house(id)["answers"][floor]["value"].string, "")
        try presenter.save("-1", store: store)
        for value in ["0", ""] {
            presenter.open(houseID: id, field: try field(floor, house: id, store: store), store: store)
            try presenter.save(value, store: store)
            let reopened = try NativeStore(directory: store.records.directory)
            XCTAssertEqual(reopened.house(id)["answers"][floor]["value"].string, value)
            XCTAssertEqual(reopened.house(id)["answers"][floor]["note"].string, "保留备注")
            XCTAssertTrue(reopened.house(id)["answers"][floor]["issueFlag"].bool)
        }
        for value in ["其他", "南", "", "其他"] {
            presenter.open(houseID: id, field: try field("f1_5", house: id, store: store), store: store)
            try presenter.save(value, store: store)
            if value == "其他" { try store.answer(id, field: "f1_5", property: "otherText", value: .string("东偏南")) }
        }
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(try field("f1_5", house: id, store: reopened)["otherText"].string, "东偏南")
        XCTAssertTrue(try field("f1_5", house: id, store: reopened)["other"].bool)
        presenter.open(houseID: id, field: try field("f105_0", house: id, store: store), store: store)
        try presenter.save("21", store: store)
        XCTAssertTrue(try store.form(id, query: "续租", filters: ["已记录"]).flatMap { $0["rows"].array }.contains { $0.id == "f105_0" })
    }
    func testCancelUntouchedLegacyAndReadonlyIdentityGuards() throws {
        let store = try store(), id = try store.add("边界"), presenter = WheelInputPresentation()
        try store.answer(id, field: "f1_3", value: .string("220"))
        let row = try field("f1_3", house: id, store: store), before = store.state
        presenter.open(houseID: id, field: row, store: store); presenter.target = nil
        XCTAssertEqual(store.state, before)
        presenter.open(houseID: id, field: row, store: store); try presenter.save("220", store: store)
        XCTAssertEqual(store.state, before)
        presenter.open(houseID: id, field: row, store: store)
        XCTAssertThrowsError(try presenter.save("20", store: self.store()))
        try store.archive(id, archived: true)
        XCTAssertThrowsError(try presenter.save("20", store: store))
        presenter.target = nil; presenter.open(houseID: id, field: row, store: store)
        XCTAssertNil(presenter.target)
    }
}
