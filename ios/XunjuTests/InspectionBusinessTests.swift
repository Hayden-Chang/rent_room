import XCTest
@testable import Xunju

@MainActor final class InspectionBusinessTests: XCTestCase {
    private func makeStore(free: Int = 1) throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "inspection-business-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root, freeLimit: free)
    }
    private func finishTutorial(_ store: NativeStore, _ id: String) throws {
        for value in ["next", "next", "swiped", "next"] { try store.call("tutorialAdvance", ["id": .string(id), "value": .string(value)]) }
    }
    func testReturningFixtureRequiresExplicitFlagAndValidIsolatedDirectory() {
        XCTAssertFalse(ReturningBusinessFixture.enabled([]))
        XCTAssertFalse(ReturningBusinessFixture.enabled(["--returning-business-fixture"]))
        XCTAssertFalse(ReturningBusinessFixture.enabled(["--returning-business-fixture", "--business-test", "invalid"]))
        XCTAssertTrue(ReturningBusinessFixture.enabled(["--returning-business-fixture", "--business-test", UUID().uuidString]))
    }
    func testFillingFixtureRequiresExplicitModeAndIsolatedDirectory() {
        let isolated = ["--business-test", UUID().uuidString]
        XCTAssertNil(FillingGuideFixture.mode([]))
        XCTAssertNil(FillingGuideFixture.mode(isolated))
        XCTAssertNil(FillingGuideFixture.mode(["--filling-guide-fixture", "simple"]))
        XCTAssertNil(FillingGuideFixture.mode(["--business-test", "invalid", "--filling-guide-fixture", "simple"]))
        XCTAssertNil(FillingGuideFixture.mode(isolated + ["--filling-guide-fixture"]))
        XCTAssertNil(FillingGuideFixture.mode(isolated + ["--filling-guide-fixture", "unknown"]))
        for mode in ["simple", "detailed"] {
            XCTAssertEqual(FillingGuideFixture.mode(isolated + ["--filling-guide-fixture", mode]), mode)
        }
    }
    func testFillingFixtureKeepsAnswersEmptyAndFirstGuidePending() throws {
        for mode in ["simple", "detailed"] {
            let store = try makeStore()
            try FillingGuideFixture.prepare(store, mode: mode)
            let id = try XCTUnwrap(store.houses.first?.id), before = store.state
            XCTAssertEqual(store.house(id)["checklistMode"].string, mode)
            XCTAssertEqual(store.house(id)["answers"], .object([:]))
            XCTAssertEqual(store.state["xiaoda"]["tutorialStep"].int, 0)
            let guide = try store.call("inspectionGuide", ["id": .string(id)])
            XCTAssertEqual(guide["prompt"]["kind"].string, "intro")
            XCTAssertEqual(guide["prompt"]["target"].string, "房源基本信息")
            try FillingGuideFixture.prepare(store, mode: mode)
            XCTAssertEqual(store.state, before)
        }
    }
    func testSetupDraftStepAndSelectionSurviveRelaunch() throws {
        let store = try makeStore()
        var draft = InspectionTemplateDraft(try store.call("setupState")["config"])
        draft.move("周边与小区", to: "房源基本信息"); XCTAssertNil(draft.toggle("家电"))
        try store.call("setupDraft", ["value": draft.json])
        try store.call("setupStep", ["value": .string("mode")])
        try store.call("setupMode", ["value": .string("detailed")])
        let reopened = try NativeStore(directory: store.records.directory)
        let setup = try reopened.call("setupState")
        XCTAssertEqual(setup["step"].string, "mode"); XCTAssertEqual(setup["mode"].string, "detailed")
        XCTAssertEqual(InspectionTemplateDraft(setup["config"]), draft)
        try reopened.call("setupFinish", ["value": .string("detailed")])
        let id = try reopened.add("第一套")
        XCTAssertEqual(reopened.house(id)["checklistOrder"].array.first?.string, "周边与小区")
        XCTAssertFalse(reopened.house(id)["templateTopics"].array.contains { $0["category"].string == "家电" })
        XCTAssertEqual(reopened.state["xiaoda"]["setup"].string, "done")
        XCTAssertEqual(reopened.state["xiaoda"]["draft"], .null)
    }
    func testTemplateChangesApplyOnlyToNewHouseSnapshots() throws {
        let store = try makeStore(free: 3)
        try store.call("setupFinish", ["value": .string("detailed")])
        let old = try store.add("原有详细房源")
        try store.answer(old, field: "f1_6", value: .string("2800"))
        try store.answer(old, field: "f1_6", property: "note", value: .string("保留备注"))
        try store.call("addMedia", ["id": .string(old), "value": .object(["id": .string("media-old"), "type": .string("image"), "path": .string("media/old.jpg"), "fieldId": .string("f1_6")])])
        let snapshot = store.house(old)
        let modes = try store.call("templates")["modes"].array
        var config = InspectionTemplateDraft(try XCTUnwrap(modes.first { $0.id == "simple" })["config"])
        XCTAssertNil(config.toggle("家电")); config.move("室内环境", to: "房源基本信息")
        try store.call("templateSave", ["value": .object(["mode": .string("simple"), "config": config.json])])
        try store.call("templateSelect", ["value": .string("simple")])
        let fresh = try store.add("新的精简房源")
        XCTAssertEqual(store.house(old), snapshot)
        XCTAssertEqual(store.house(fresh)["checklistMode"].string, "simple")
        XCTAssertEqual(store.house(fresh)["checklistOrder"].array.first?.string, "室内环境")
        XCTAssertFalse(store.house(fresh)["templateTopics"].array.contains { $0["category"].string == "家电" })
        XCTAssertTrue(store.house(fresh)["templateTopics"].array.flatMap { $0["fields"].array }.contains { $0.id == "simple_49" })
        XCTAssertEqual(try NativeStore(directory: store.records.directory, freeLimit: 3).house(old), snapshot)
    }
    func testLegacySaveSkipsSetupAndRetainsDetailedSnapshot() throws {
        let store = try makeStore(), id = try store.add("旧房源")
        let old = store.state.removing("xiaoda")
        try store.records.write(String(decoding: JSONEncoder().encode(old), as: UTF8.self), keepPrevious: false)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.state["xiaoda"]["setup"].string, "done")
        XCTAssertTrue(restored.state["xiaoda"]["legacy"].bool)
        XCTAssertEqual(restored.state["xiaoda"]["tutorialStep"].int, 0)
        XCTAssertEqual(restored.house(id)["templateTopics"], old["houses"].array[0]["templateTopics"])
    }
    func testSimpleDescriptionResultsAndNotesCountOnce() throws {
        let store = try makeStore()
        try store.call("setupFinish", ["value": .string("simple")]); let id = try store.add("精简")
        try finishTutorial(store,id)
        let total = store.houses[0].stats.total
        try store.answer(id, field: "simple_02", property: "note", value: .string("附近没有菜市场"))
        XCTAssertEqual(store.houses[0].stats.done, 0); XCTAssertEqual(store.houses[0].stats.issues, 0)
        try store.call("choose", ["id": .string(id), "field": .string("simple_02"), "value": .string("否")])
        XCTAssertEqual(store.houses[0].stats.done, 1); XCTAssertEqual(store.houses[0].stats.issues, 1)
        let row = try XCTUnwrap(store.form(id, query: "生活配套").flatMap { $0["rows"].array }.first { $0.id == "simple_02" })
        XCTAssertFalse(row["description"].string.isEmpty); XCTAssertEqual(row["note"].string, "附近没有菜市场")
        XCTAssertEqual(store.houses[0].stats.total, total)
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(reopened.houses[0].stats.done, 1); XCTAssertEqual(reopened.houses[0].stats.issues, 1)
    }
    func testTutorialRequiresActualSwipeAndResumesStoredStep() throws {
        let store = try makeStore(); try store.call("setupFinish", ["value": .string("simple")])
        let id = try store.add("引导")
        try store.call("tutorialAdvance", ["id": .string(id), "value": .string("next")])
        try store.call("tutorialAdvance", ["id": .string(id), "value": .string("next")])
        try store.call("tutorialAdvance", ["id": .string(id), "value": .string("next")])
        XCTAssertEqual(store.state["xiaoda"]["tutorialStep"].int, 3)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(try restored.call("inspectionGuide", ["id": .string(id)])["tutorial"].int, 3)
        try restored.call("tutorialAdvance", ["id": .string(id), "value": .string("swiped")])
        try restored.call("tutorialAdvance", ["id": .string(id), "value": .string("next")])
        let guide = try restored.call("inspectionGuide", ["id": .string(id)])
        XCTAssertEqual(guide["tutorial"].int, 0); XCTAssertEqual(guide["prompt"]["kind"].string, "intro")
    }
    private func withBlockedWrites(_ store: NativeStore, _ work: () throws -> Void) throws {
        // Only this test's UUID directory is moved; no production failure switch.
        let root = store.records.directory, parked = root.appendingPathExtension("parked")
        let files = FileManager.default
        try files.moveItem(at: root, to: parked)
        defer { try? files.removeItem(at: root); try? files.moveItem(at: parked, to: root) }
        try Data("write barrier".utf8).write(to: root)
        try work()
    }
    func testSetupFailureKeepsDraftAndCanRetry() throws {
        let store = try makeStore()
        let before = store.state, saved = try store.records.read()
        try withBlockedWrites(store) {
            XCTAssertThrowsError(try store.call("setupFinish", ["value": .string("simple")]))
            XCTAssertEqual(store.state, before)
            XCTAssertFalse(store.status.error.isEmpty)
        }
        XCTAssertEqual(try store.records.read(), saved)
        try store.call("setupFinish", ["value": .string("simple")])
        XCTAssertTrue(store.status.error.isEmpty)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).state["xiaoda"]["setup"].string, "done")
    }
    func testTutorialSaveFailureRollsBackAndDuplicateSwipeCannotSkipStepFour() throws {
        let store = try makeStore(); try store.call("setupFinish", ["value": .string("simple")])
        let id = try store.add("左滑保存失败")
        for _ in 0..<2 { try store.call("tutorialAdvance", ["id": .string(id), "value": .string("next")]) }
        let before = store.state, saved = try store.records.read()
        try withBlockedWrites(store) {
            XCTAssertThrowsError(try store.call("tutorialAdvance", ["id": .string(id), "value": .string("swiped")]))
            XCTAssertEqual(store.state, before)
        }
        XCTAssertEqual(try store.records.read(), saved)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).state["xiaoda"]["tutorialStep"].int, 3)
        try store.call("tutorialAdvance", ["id": .string(id), "value": .string("swiped")])
        XCTAssertTrue(store.status.error.isEmpty)
        let restored = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(restored.state["xiaoda"]["tutorialStep"].int, 4)
        try restored.call("tutorialAdvance", ["id": .string(id), "value": .string("swiped")])
        XCTAssertEqual(restored.state["xiaoda"]["tutorialStep"].int, 4)
        let entry = try restored.call("inspectionGuide", ["id": .string(id)])["steps"].array[3]
        XCTAssertEqual(XiaodaSpeech.iconMap(entry["icons"]), ["❗":"issue", "🖊":"note", "📷":"camera"])
        try restored.call("tutorialAdvance", ["id": .string(id), "value": .string("next")])
        XCTAssertEqual(try NativeStore(directory: store.records.directory).state["xiaoda"]["tutorialStep"].int, 0)
        XCTAssertEqual(store.house(id)["answers"], before["houses"].array[0]["answers"])
    }
    func testRentFreeNumberPreservesHistoricalValuesMetadataAndArchive() throws {
        for mode in ["simple", "detailed"] {
            let store = try makeStore(); try store.call("setupFinish", ["value": .string(mode)])
            let id = try store.add("免租期")
            try store.answer(id, field: "f5_3", value: .string("90"))
            try store.answer(id, field: "f5_3", property: "note", value: .string("原有协商备注"))
            try store.answer(id, field: "f5_3", property: "issueFlag", value: .bool(true))
            try store.call("addMedia", ["id": .string(id), "value": .object(["id": .string("rent-photo"), "type": .string("image"), "path": .string("media/rent.jpg"), "fieldId": .string("f5_3")])])
            let before = store.house(id), restored = try NativeStore(directory: store.records.directory)
            XCTAssertEqual(restored.house(id), before)
            let row = try XCTUnwrap(restored.form(id, query: "免租期").flatMap { $0["rows"].array }.first { $0.id == "f5_3" })
            XCTAssertEqual(ChecklistPresentation.item(row).kind, .number)
            XCTAssertFalse(ChecklistPresentation.item(row).numberPad)
            XCTAssertEqual(row["inputType"].string, "digit")
            XCTAssertEqual(row["value"].string, "90")
            try restored.answer(id, field: "f5_3", property: "none", value: .bool(true))
            let absent = try NativeStore(directory: store.records.directory)
            let absentRow = try XCTUnwrap(absent.form(id, query: "免租期").flatMap { $0["rows"].array }.first { $0.id == "f5_3" })
            XCTAssertTrue(absentRow["noneSelected"].bool); XCTAssertEqual(absentRow["value"].string, "")
            XCTAssertEqual(absent.house(id)["answers"]["f5_3"]["value"].string, "90")
            try restored.answer(id, field: "f5_3", property: "none", value: .bool(false))
            for value in ["7.5", "0", "", "120"] {
                try restored.answer(id, field: "f5_3", value: .string(value))
                let reopened = try NativeStore(directory: store.records.directory)
                XCTAssertEqual(reopened.house(id)["answers"]["f5_3"]["value"].string, value)
                XCTAssertEqual(reopened.house(id)["answers"]["f5_3"]["note"], before["answers"]["f5_3"]["note"])
                XCTAssertEqual(reopened.house(id)["answers"]["f5_3"]["issueFlag"], .bool(true))
                XCTAssertEqual(reopened.house(id)["media"], before["media"])
                XCTAssertEqual(reopened.house(id)["templateTopics"], before["templateTopics"])
            }
            XCTAssertThrowsError(try restored.answer(id, field: "f5_3", value: .string("-1")))
            try restored.archive(id, archived: true)
            XCTAssertThrowsError(try restored.answer(id, field: "f5_3", value: .string("20")))
            XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["answers"]["f5_3"]["value"].string, "120")
        }
    }
    func testSamePhaseCompletionStaysQuietAfterClearingAndReopening() throws {
        let store = try makeStore(); try store.call("setupFinish", ["value": .string("simple")])
        let id = try store.add("前进引导"); try finishTutorial(store,id)
        try store.call("guideAction", ["id": .string(id), "value": .string("accept")])
        let fields = store.house(id)["templateTopics"].array.filter { $0["category"].string == "室内环境" }.flatMap { $0["fields"].array }
        for field in fields { try store.answer(id, field: field.id, value: .string("是")) }
        let prompt = try store.call("inspectionGuide", ["id": .string(id)])["prompt"]
        XCTAssertEqual(prompt, .null)
        let saved = store.house(id), stale = saved["xiaoda"]["prompt"]
        XCTAssertEqual(stale["target"].string, "墙面地面与门窗")
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(try reopened.call("inspectionGuide", ["id": .string(id)])["prompt"], .null)
        XCTAssertEqual(try reopened.call("guideAction", ["id": .string(id), "value": .string("accept"), "property": stale["id"]]), .null)
        XCTAssertEqual(reopened.house(id), saved)
        XCTAssertFalse(store.house(id)["xiaoda"]["seenCompleted"].array.contains(.string("房源基本信息")))
        try store.answer(id, field: fields[0].id, value: .string("")); try store.answer(id, field: fields[0].id, value: .string("是"))
        XCTAssertEqual(try store.call("inspectionGuide", ["id": .string(id)])["prompt"], .null)
    }
    func testOtherHousesShowsReturnGuideBeforeLeavingAndStaleActionsDoNotDismissIt() throws {
        let store = try makeStore(); try store.call("setupFinish", ["value": .string("simple")])
        let modes = try store.call("templates")["modes"].array
        var config = InspectionTemplateDraft(try XCTUnwrap(modes.first { $0.id == "simple" })["config"])
        config.disabled = Set(config.order.filter { !["室内环境", "费用与付款"].contains($0) })
        try store.call("templateSave", ["value": .object(["mode": .string("simple"), "config": config.json])])
        let id = try store.add("阶段切换"); try finishTutorial(store, id)
        try store.call("guideAction", ["id": .string(id), "value": .string("accept")])
        for field in ["simple_11", "simple_12", "simple_13", "simple_49"] { try store.answer(id, field: field, value: .string("是")) }
        let phase = try store.call("inspectionGuide", ["id": .string(id)])["prompt"]
        XCTAssertEqual(phase["kind"].string, "phase")
        XCTAssertEqual(try store.call("guideAction", ["id": .string(id), "value": .string("other"), "property": phase["id"]]), .null)
        let pending = try store.call("inspectionGuide", ["id": .string(id)])["prompt"]
        XCTAssertEqual(pending["kind"].string, "return"); XCTAssertFalse(store.state["xiaoda"]["returnGuide"].bool)
        try store.call("guideAction", ["id": .string(id), "value": .string("later"), "property": phase["id"]])
        XCTAssertEqual(try store.call("inspectionGuide", ["id": .string(id)])["prompt"], pending)
        XCTAssertTrue(try store.call("guideAction", ["id": .string(id), "value": .string("accept"), "property": pending["id"]])["back"].bool)
        XCTAssertTrue(store.state["xiaoda"]["returnGuide"].bool)
    }
    func testGuideCloseScopesAndFeedbackRequestAreDurable() throws {
        let store = try makeStore(); try store.call("setupFinish", ["value": .string("simple")])
        let id = try store.add("关闭范围"); try finishTutorial(store,id)
        try store.call("guideAction", ["id": .string(id), "value": .string("house")])
        XCTAssertFalse(try store.call("inspectionGuide", ["id": .string(id)])["enabled"].bool)
        XCTAssertTrue(store.state["xiaoda"]["enabled"].bool)
        try store.call("leaveInspection", ["id": .string(id)])
        XCTAssertTrue(try store.call("homeGuide")["feedback"].bool)
        XCTAssertThrowsError(try store.call("feedbackRequest"))
        try store.call("feedbackDraft", ["value": .object(["ease": .string("方便")])])
        let request = try store.call("feedbackRequest")
        let reopened = try NativeStore(directory: store.records.directory)
        XCTAssertEqual(try reopened.call("feedbackRequest"), request)
        XCTAssertThrowsError(try reopened.call("feedbackFinish", ["value": .string("wrong-receipt")]))
        try reopened.call("feedbackFinish", ["value": request["requestId"]])
        XCTAssertFalse(try reopened.call("homeGuide")["feedback"].bool)
    }
    func testNonePreservesHiddenValueAndCountsAsRecorded() throws {
        let store = try makeStore(), id = try store.add("缺失配置")
        try store.answer(id, field: "f54_0", value: .string("需要衣柜"))
        try store.answer(id, field: "f54_0", property: "none", value: .bool(true))
        let row = try XCTUnwrap(store.form(id, query: "缺少的家具").flatMap { $0["rows"].array }.first { $0.id == "f54_0" })
        XCTAssertTrue(row["noneSelected"].bool); XCTAssertFalse(row["problem"].bool); XCTAssertEqual(row["value"].string, "")
        XCTAssertEqual(store.house(id)["answers"]["f54_0"]["value"].string, "需要衣柜")
        try store.answer(id, field: "f54_0", property: "none", value: .bool(false))
        XCTAssertEqual(store.house(id)["answers"]["f54_0"]["value"].string, "需要衣柜")
    }
    func testZeroCreditsAllowImportAndRestoreButRejectNewCreation() throws {
        let store = try makeStore(free: 2), id = try store.add("老房源"), second = try store.add("待还原")
        try store.archive(second, archived: true)
        try store.call("setFreeLimit", ["value": .number(0)])
        try store.answer(id, field: "f1_6", value: .string("1800"))
        XCTAssertThrowsError(try store.add("超额新增"))
        let copy = store.house(id).setting("id", to: .string("new-copy"))
        try store.call("import", ["houses": .array([copy]), "replaceIds": .array([])])
        try store.call("import", ["houses": .array([store.house(id)]), "replaceIds": .array([.string(id)])])
        XCTAssertEqual(store.house(id)["answers"]["f1_6"]["value"].string, "1800")
        try store.call("beginHouseAction", ["id": .string(second), "value": .string("restore")])
        XCTAssertEqual(store.capacity.remaining, 0)
        XCTAssertEqual(try store.call("finishHouseAction")["id"].string, second)
        XCTAssertFalse(store.house(second)["archived"].bool)
    }
    func testCreateIntentRetainsEnteredNameAcrossCapacityChangeAndRelaunch() throws {
        let store = try makeStore()
        try store.call("beginHouseAction", ["value": .string("create")])
        try store.call("setFreeLimit", ["value": .number(0)])
        XCTAssertThrowsError(try store.add("名字已经填好了"))
        try store.call("beginHouseAction", ["value": .string("create"), "name": .string("名字已经填好了")])
        let reopened = try NativeStore(directory: store.records.directory, freeLimit: 1)
        XCTAssertEqual(reopened.state["xiaoda"]["intent"]["name"].string, "名字已经填好了")
        XCTAssertEqual(try reopened.call("finishHouseAction")["kind"].string, "create")
        _ = try reopened.add(reopened.state["xiaoda"]["intent"]["name"].string)
        XCTAssertEqual(reopened.houses.first?.name, "名字已经填好了")
        XCTAssertEqual(reopened.state["xiaoda"]["intent"], .null)
    }
    func testNineMediaBatchPreservesOrderAndRejectsPartialWrites() throws {
        let store = try makeStore(), id = try store.add("多选影像")
        let items: [JSONValue] = (0..<9).map { index in .object(["id": .string("m\(index)"), "type": .string(index % 2 == 0 ? "image" : "video"), "path": .string("media/\(index).jpg")]) }
        try store.call("addMediaBatch", ["id": .string(id), "value": .array(items)])
        let before = store.state
        XCTAssertThrowsError(try store.call("addMediaBatch", ["id": .string(id), "value": .array(items + [items[0]])]))
        XCTAssertThrowsError(try store.call("addMediaBatch", ["id": .string(id), "value": .array([items[0].setting("id", to: .string("new")), items[1]])]))
        XCTAssertEqual(store.state, before)
        XCTAssertEqual(try NativeStore(directory: store.records.directory).house(id)["media"].array.map(\.id), items.map(\.id))
    }
}
