import XCTest
import ZIPFoundation
@testable import Xunju

final class BackupTests: XCTestCase {
    @MainActor private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-backup-tests-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func add(_ data: Data, path: String, archive: Archive, compressed: Bool = false) throws {
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), compressionMethod: compressed ? .deflate : .none) { position, size in
            data.subdata(in: Int(position)..<(Int(position) + size))
        }
    }
    @MainActor private func addMedia(_ store: NativeStore, house: String, bytes: Data) throws {
        let url = store.records.directory.appending(path: "media/test1.jpg")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: url)
        try store.call("addMedia", ["id": .string(house), "value": .object(["id": .string("m1"), "type": .string("image"),
            "path": .string("media/test1.jpg"), "fieldId": .string("f1_6"), "caption": .string("照片备注")])])
    }

    @MainActor func testZIPRoundTripStreamsMediaAndKeepsSettingsAndAssociations() async throws {
        let source = try store(), target = try store(), transfers = BackupTransfers()
        let id = try source.add("跨平台房源")
        try source.answer(id, field: "f1_6", value: .string("0"))
        try source.call("summary", ["id": .string(id), "property": .string("summary"), "value": .string("总结")])
        let bytes = Data(repeating: 117, count: 800_000)
        try addMedia(source, house: id, bytes: bytes)
        try target.call("settings", ["property": .string("workplace"), "value": .string("保留公司")])
        let archive = source.records.directory.appendingPathComponent("rooms.zip")
        let original = source.state
        try await transfers.export(ids: [id], store: source, to: archive)
        XCTAssertEqual(source.state, original)
        let attachment = XCTAttachment(data: try Data(contentsOf: archive), uniformTypeIdentifier: "public.zip-archive")
        attachment.name = "native-cross-platform.zip"; attachment.lifetime = .keepAlways; add(attachment)
        let preview = try await transfers.preview(archive, store: target)
        XCTAssertEqual(preview.manifest["settings"], .null)
        XCTAssertEqual(preview.houses[0]["media"].array[0]["path"].string, "media/\(id)/m1.jpg")
        try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [], store: target, isCurrent: { true })
        XCTAssertEqual(target.houses.first?.rent, "0")
        XCTAssertEqual(target.house(id)["summary"].string, "总结")
        XCTAssertEqual(target.state["settings"]["workplace"].string, "保留公司")
        let media = target.house(id)["media"].array[0]
        XCTAssertEqual(media["caption"].string, "照片备注")
        XCTAssertEqual(media["fieldId"].string, "f1_6")
        XCTAssertEqual(try Data(contentsOf: target.records.directory.appending(path: media["path"].string)), bytes)
    }

    @MainActor func testZIPCapacityFailureDiscardsStagedMediaAndKeepsRecords() async throws {
        let source = try store(), target = try store(), transfers = BackupTransfers()
        let id = try source.add("导入房源")
        try addMedia(source, house: id, bytes: Data([1, 2, 3]))
        _ = try target.add("已有房源")
        XCTAssertEqual(target.capacity.used, target.capacity.limit)
        let archive = source.records.directory.appendingPathComponent("rooms.zip")
        try await transfers.export(ids: [id], store: source, to: archive)
        let preview = try await transfers.preview(archive, store: target)
        let original = target.state
        do {
            try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [], store: target, isCurrent: { true })
            XCTFail("Over capacity import must fail")
        } catch { XCTAssertTrue(error.localizedDescription.contains("容量")) }
        XCTAssertEqual(target.state, original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.records.directory.appendingPathComponent("media").path).count, 0)
    }

    @MainActor func testReplacementImportUsesNetCapacityAndRetainsGlobalSettings() async throws {
        let source = try store(), transfers = BackupTransfers()
        let id = try source.add("原房源")
        XCTAssertEqual(source.capacity.used, source.capacity.limit)
        try source.call("settings", ["property": .string("workplace"), "value": .string("保留上班地点")])
        let archive = source.records.directory.appendingPathComponent("rooms.zip")
        try await transfers.export(ids: [id], store: source, to: archive)
        let preview = try await transfers.preview(archive, store: source)
        try source.call("rename", ["id": .string(id), "value": .string("新名称")])
        try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [id], store: source, isCurrent: { true })
        XCTAssertEqual(source.house(id)["name"].string, "原房源")
        XCTAssertEqual(source.capacity.used, 1)
        XCTAssertEqual(source.state["settings"]["workplace"].string, "保留上班地点")
    }

    @MainActor func testCancelledExportAndChangedFileNeverCommitOrOverwrite() async throws {
        let source = try store(), transfers = BackupTransfers()
        let id = try source.add("取消")
        let archive = source.records.directory.appendingPathComponent("rooms.zip")
        let progress = Progress(totalUnitCount: 1); progress.cancel()
        do { try await transfers.export(ids: [id], store: source, to: archive, progress: progress); XCTFail("Must cancel") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: archive.path))
        try await transfers.export(ids: [id], store: source, to: archive)
        let preview = try await transfers.preview(archive, store: source)
        do { try await transfers.export(ids: [id], store: source, to: archive); XCTFail("Must preserve existing ZIP") } catch { }
        let archiveWriter = try Archive(url: archive, accessMode: .update)
        try add(Data([1]), path: "extra", archive: archiveWriter)
        do {
            try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [id], store: source, isCurrent: { true })
            XCTFail("Changed ZIP must fail")
        } catch { }
        XCTAssertEqual(source.houses.count, 1)
    }

    @MainActor func testInvalidPathsDuplicateEntriesAndTruncatedZIPAreRejected() async throws {
        let store = try store(), worker = NativeBackup()
        let id = try store.add("检验")
        let manifest = try JSONEncoder().encode(JSONValue.object(["version": .number(2), "format": .string("xunju-backup"), "archiveVersion": .number(1), "houses": .array([store.house(id)])]))
        for (index, path) in ["../outside.jpg", "media/house/invalid.gif", "manifest.json"].enumerated() {
            let url = store.records.directory.appendingPathComponent("invalid\(index).zip")
            let zip = try Archive(url: url, accessMode: .create)
            try add(manifest, path: "manifest.json", archive: zip)
            try add(Data([1]), path: path, archive: zip)
            do { _ = try await worker.preview(url); XCTFail("Invalid or duplicate entry must fail: \(path)") } catch { }
        }
        let good = store.records.directory.appendingPathComponent("valid.zip")
        try await worker.export(houses: [store.house(id)], root: store.records.directory, to: good)
        var data = try Data(contentsOf: good); data.removeLast(10)
        let truncated = store.records.directory.appendingPathComponent("truncated.zip")
        try data.write(to: truncated)
        do { _ = try await worker.preview(truncated); XCTFail("Truncated archive must fail") } catch { }
    }

    @MainActor func testCompressedManifestIsAcceptedAndBadSchemaRejected() async throws {
        let store = try store(), transfers = BackupTransfers()
        let id = try store.add("压缩清单")
        let raw: JSONValue = .object(["version": .number(2), "format": .string("xunju-backup"), "archiveVersion": .number(1), "houses": .array([store.house(id)])])
        for (index, value) in [raw, raw.setting("houses", to: .array([store.house(id).setting("answers", to: .array([]))]))].enumerated() {
            let url = store.records.directory.appendingPathComponent("compressed\(index).zip")
            let zip = try Archive(url: url, accessMode: .create)
            try add(JSONEncoder().encode(value), path: "manifest.json", archive: zip, compressed: true)
            if index == 0 { let preview = try await transfers.preview(url, store: store); XCTAssertEqual(preview.houses.count, 1) }
            else { do { _ = try await transfers.preview(url, store: store); XCTFail("Invalid schema must fail") } catch { } }
        }
    }

    @MainActor func testActualMiniProgramZIPImportsMediaAndIssueAssociations() async throws {
        let store = try store(), transfers = BackupTransfers()
        let archive = try XCTUnwrap(Bundle(for: BackupTests.self).url(forResource: "wechat-backup", withExtension: "zip"))
        let preview = try await transfers.preview(archive, store: store)
        XCTAssertEqual(preview.houses.first?["name"].string, "小程序导出房源")
        try await transfers.importSelected(archive, preview: preview, selectedIDs: ["wechat_fixture_house"], replacing: [], store: store, isCurrent: { true })
        XCTAssertEqual(store.houses.first?.rent, "2400")
        let house = store.house("wechat_fixture_house")
        XCTAssertEqual(house["answers"]["f1_6"]["note"].string, "小程序租金备注")
        XCTAssertEqual(house["issues"].array.first?["title"].string, "渗水")
        let media = try XCTUnwrap(house["media"].array.first)
        XCTAssertEqual(media["issueId"].string, "issue_fixture")
        XCTAssertEqual(media["caption"].string, "小程序影像备注")
        XCTAssertEqual(try Data(contentsOf: store.records.directory.appending(path: media["path"].string)), Data("xunju-wechat-media-fixture".utf8))
    }

    @MainActor func testCorruptMediaFailsCRCAndDiscardsFiles() async throws {
        let source = try store(), target = try store(), transfers = BackupTransfers()
        let id = try source.add("损坏媒体")
        let marker = Data("unique-media-corruption-marker".utf8)
        try addMedia(source, house: id, bytes: marker)
        let archive = source.records.directory.appendingPathComponent("corrupt.zip")
        try await transfers.export(ids: [id], store: source, to: archive)
        var bytes = try Data(contentsOf: archive)
        let range = try XCTUnwrap(bytes.range(of: marker)); bytes[range.lowerBound] ^= 1
        try bytes.write(to: archive)
        let preview = try await transfers.preview(archive, store: target)
        do {
            try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [], store: target, isCurrent: { true })
            XCTFail("Selected corrupted media must fail its CRC")
        } catch { }
        XCTAssertTrue(target.houses.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.records.directory.appendingPathComponent("media").path).count, 0)
    }

    @MainActor func testUnsupportedCompressionAndEncryptionAreRejectedBeforeInflation() async throws {
        let store = try store(), worker = NativeBackup()
        let id = try store.add("压缩方式检查")
        let good = store.records.directory.appendingPathComponent("good.zip")
        try await worker.export(houses: [store.house(id)], root: store.records.directory, to: good)
        let original = try Data(contentsOf: good)
        let local = try XCTUnwrap(original.range(of: Data([0x50, 0x4b, 0x03, 0x04]))).lowerBound
        let central = try XCTUnwrap(original.range(of: Data([0x50, 0x4b, 0x01, 0x02]))).lowerBound
        for index in 0..<2 {
            var data = original
            if index == 0 { data[local + 8] = 99; data[central + 10] = 99 }
            else { data[local + 6] |= 1; data[central + 8] |= 1 }
            let bad = store.records.directory.appendingPathComponent("bad-header-\(index).zip")
            try data.write(to: bad)
            do { _ = try await worker.preview(bad); XCTFail("Unsupported entry must fail") }
            catch { XCTAssertTrue(error.localizedDescription.contains("不支持")) }
        }
    }

    @MainActor func testAccountChangeDuringImportDiscardsStaging() async throws {
        let source = try store(), target = try store(), transfers = BackupTransfers()
        let id = try source.add("账号切换")
        try addMedia(source, house: id, bytes: Data([8, 9, 10]))
        let archive = source.records.directory.appendingPathComponent("rooms.zip")
        try await transfers.export(ids: [id], store: source, to: archive)
        let preview = try await transfers.preview(archive, store: target)
        var checks = 0
        do {
            try await transfers.importSelected(archive, preview: preview, selectedIDs: [id], replacing: [], store: target, isCurrent: { checks += 1; return checks == 1 })
            XCTFail("Changed scope must never receive late import")
        } catch { XCTAssertTrue(error.localizedDescription.contains("已变化")) }
        XCTAssertTrue(target.houses.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: target.records.directory.appendingPathComponent("media").path).count, 0)
    }

    @MainActor func testArchiveLargerThanFiftyMiBHasNoArtificialTotalLimit() async throws {
        let store = try store(), transfers = BackupTransfers()
        let id = try store.add("大备份")
        // Two valid per-file sizes; total exceeds 50 MiB. The writer streams both.
        let bytes = Data(repeating: 37, count: 26 * 1024 * 1024)
        try addMedia(store, house: id, bytes: bytes)
        let second = store.records.directory.appending(path: "media/test2.jpg")
        try bytes.write(to: second)
        try store.call("addMedia", ["id": .string(id), "value": .object(["id": .string("m2"), "type": .string("image"), "path": .string("media/test2.jpg"), "fieldId": .string("")])])
        let archive = store.records.directory.appendingPathComponent("large.zip")
        try await transfers.export(ids: [id], store: store, to: archive)
        let size = try archive.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        XCTAssertGreaterThan(size, 50 * 1024 * 1024)
        let preview = try await transfers.preview(archive, store: store)
        XCTAssertEqual(preview.houses[0]["media"].array.count, 2)
    }
}
