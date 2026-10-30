import XCTest
@testable import Xunju

@MainActor final class ChoicePerformanceTests: XCTestCase {
    private func fixture(count: Int) throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("choice-perf-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let seed = try NativeStore(directory: root, freeLimit: 30)
        try seed.call("settings", ["property": .string("onboarding"), "value": .bool(false)])
        let id = try seed.add("选项响应")
        let houses = (0..<count).map { seed.house(id).setting("id", to: .string("choice-\($0)")) }
        try seed.records.write(String(decoding: JSONEncoder().encode(seed.state.setting("houses", to: .array(houses))), as: UTF8.self), keepPrevious: false)
        return try NativeStore(directory: root, freeLimit: 30)
    }

    func testInactiveTeachingDoesNotBuildAnExpandedChecklistTarget() throws {
        let store = try fixture(count: 1)
        let guide = try store.call("inspectionGuide", ["id": .string("choice-0")])
        XCTAssertEqual(guide["tutorial"].int, 0)
        XCTAssertEqual(guide["target"], .null, "Ordinary choices must not prepare the full teaching checklist")
        XCTAssertFalse(guide["progress"].array.isEmpty)
    }

    func testOneHouseChoiceSaveAndRefreshBenchmark() throws { try benchmark(count: 1) }
    func testThirtyHouseChoiceSaveAndRefreshBenchmark() throws { try benchmark(count: 30) }

    private func benchmark(count: Int) throws {
        let store = try fixture(count: count), id = "choice-0"
        let folds = ["房源基本信息": true]
        var rows = try store.form(id, folds: folds)
        var samples: [[String: Double]] = []
        for index in 0..<10 {
            let field = try XCTUnwrap(rows.flatMap { $0["rows"].array }.first { $0.id == "f1_top" })
            var state = ChecklistPresentation.state(field)
            let value = index.isMultiple(of: 2) ? "是" : "否"
            state.selected = [value]
            let start = CFAbsoluteTimeGetCurrent()
            try ChecklistPresentation.write(state, from: field, houseID: id, store: store)
            let saved = CFAbsoluteTimeGetCurrent()
            rows = try store.form(id, folds: folds)
            let formed = CFAbsoluteTimeGetCurrent()
            _ = try store.call("inspectionGuide", ["id": .string(id)])
            let finished = CFAbsoluteTimeGetCurrent()
            samples.append(["save": (saved-start)*1000, "form": (formed-saved)*1000,
                            "guide": (finished-formed)*1000, "total": (finished-start)*1000])
            let selected = try XCTUnwrap(rows.flatMap { $0["rows"].array }.first { $0.id == "f1_top" })
            XCTAssertEqual(ChecklistPresentation.state(selected).selected, [value])
            XCTAssertTrue(store.status.error.isEmpty)
        }
        let reopened = try NativeStore(directory: store.records.directory, freeLimit: 30)
        XCTAssertEqual(reopened.house(id)["answers"]["f1_top"]["value"].string, "否")
        XCTAssertEqual(reopened.houses.count, count)
        let encoded = String(decoding: try JSONEncoder().encode(samples), as: UTF8.self)
        print("CHOICE_PERF houses=\(count) samples_ms=\(encoded)")
    }
}
