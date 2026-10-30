import XCTest
import UIKit
@testable import Xunju

@MainActor final class ExampleHousesTests: XCTestCase {
    private func root() -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "example-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    func testFirstInstallationSeedsTwoSimpleExamplesOnceAndDeletionSurvivesRestart() throws {
        let url = root(), workspace = try AppWorkspace(root: url, keychain: VolatileSessionStorage(), firstVisitExamples: true)
        let store = workspace.store, ids = store.houses.map(\.id)
        XCTAssertEqual(ids.count, 2)
        for house in store.houses {
            XCTAssertEqual(house.cover, "media/\(house.id).jpg")
            let file = try LocalMediaFiles.file(house.cover, in: store.records.directory)
            XCTAssertNotNil(UIImage(contentsOfFile: file.path))
            XCTAssertNotNil(houseCover(house, store: store))
        }
        XCTAssertTrue(store.state["houses"].array.allSatisfy { $0["checklistMode"].string == "simple" })
        XCTAssertEqual(store.state["xiaoda"]["firstHouseId"].string, "")
        XCTAssertEqual(store.state["iosReview"]["created"].int, 0)
        let rows = try store.call("compare", ["ids": .array(ids.map(JSONValue.string)), "differences": .bool(true)]).array
        XCTAssertEqual(rows.first { $0.id == "f1_6" }?["values"].array.map(\.string), ["CNY 2800", "CNY 3600"])
        let restored = try AppWorkspace(root: url, keychain: VolatileSessionStorage(), firstVisitExamples: true)
        XCTAssertEqual(restored.store.houses.map(\.id), ids)
        XCTAssertTrue(restored.store.houses.allSatisfy { houseCover($0, store: restored.store) != nil })
        for id in ids { try restored.store.archive(id, archived: true); try restored.store.call("remove", ["id": .string(id)]) }
        XCTAssertTrue(try AppWorkspace(root: url, keychain: VolatileSessionStorage(), firstVisitExamples: true).store.houses.isEmpty)
    }
    func testExistingEmptyInstallationAndOldHouseAreNeverSeeded() throws {
        let url = root(), old = try AppWorkspace(root: url, keychain: VolatileSessionStorage())
        XCTAssertTrue(try AppWorkspace(root: url, keychain: VolatileSessionStorage(), firstVisitExamples: true).store.houses.isEmpty)
        let id = try old.store.add("原有房源")
        try old.store.answer(id, field: "f1_6", value: .string("2500"))
        try old.store.answer(id, field: "f1_6", property: "note", value: .string("原备注"))
        let bytes = try old.store.records.read()
        let upgraded = try AppWorkspace(root: url, keychain: VolatileSessionStorage(), firstVisitExamples: true)
        XCTAssertEqual(upgraded.store.houses.map(\.id), [id])
        XCTAssertEqual(try upgraded.store.records.read(), bytes)
    }
    func testExistingEmptyFileAndRecoveryCopyAreNeverSeeded() throws {
        for filename in ["state.json", "state.previous.json"] {
            let url = root(); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            try Data().write(to: url.appending(path: filename))
            let store = try NativeStore(directory: url, firstVisit: true)
            XCTAssertTrue(store.houses.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url.appending(path: filename)), Data())
        }
    }
    func testExamplePhotosSurviveBackupExportAndImport() async throws {
        let source = try AppWorkspace(root: root(), keychain: VolatileSessionStorage(), firstVisitExamples: true).store
        let target = try NativeStore(directory: root(), freeLimit: 3), transfers = BackupTransfers()
        let archive = source.records.directory.appending(path: "examples.zip")
        let ids = source.houses.map(\.id)
        try await transfers.export(ids: ids, store: source, to: archive)
        let preview = try await transfers.preview(archive, store: target)
        try await transfers.importSelected(archive, preview: preview, selectedIDs: ids, replacing: [], store: target, isCurrent: { true })
        XCTAssertEqual(target.houses.map(\.id), ids)
        for id in ids {
            let before = source.house(id)["media"].array[0], after = target.house(id)["media"].array[0]
            XCTAssertEqual(after["caption"], before["caption"])
            let original = try LocalMediaFiles.file(before["path"].string, in: source.records.directory)
            let restored = try LocalMediaFiles.file(after["path"].string, in: target.records.directory)
            XCTAssertEqual(try Data(contentsOf: restored), try Data(contentsOf: original))
        }
    }
}
