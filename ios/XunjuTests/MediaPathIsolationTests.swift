import XCTest
@testable import Xunju

final class MediaPathIsolationTests: XCTestCase {
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-path-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func linkMedia(from root: URL, to other: URL) throws {
        try FileManager.default.createDirectory(at: other, withIntermediateDirectories: true)
        try Data("private-other-account".utf8).write(to: other.appendingPathComponent("private.jpg"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("media"), withDestinationURL: other)
    }

    @MainActor func testGuestMediaResolutionRejectsAnotherScopeSymlink() throws {
        let root = try root(), scopes = try LocalIdentityScopes(root: root)
        let guest = try scopes.guestDirectory()
        let other = root.appending(path: "accounts/other/media")
        try linkMedia(from: guest, to: other)
        XCTAssertThrowsError(try scopes.mediaURL("media/private.jpg", in: guest), "A symlink must not expose another scope's media")
    }

    @MainActor func testZIPExportRejectsMediaDirectorySymlink() async throws {
        let root = try root(), store = try NativeStore(directory: root.appendingPathComponent("source"))
        let id = try store.add("隔离导出")
        try linkMedia(from: store.records.directory, to: root.appendingPathComponent("other-media"))
        try store.call("addMedia", ["id": .string(id), "value": .object(["id": .string("m1"), "type": .string("image"), "path": .string("media/private.jpg"), "fieldId": .string("")])])
        let output = root.appendingPathComponent("must-not-export.zip")
        do {
            try await NativeBackup().export(houses: [store.house(id)], root: store.records.directory, to: output)
            XCTFail("A symlink must not export another scope's bytes")
        } catch { }
    }

    @MainActor func testZIPStagingRejectsMediaDirectorySymlink() async throws {
        let root = try root(), source = try NativeStore(directory: root.appendingPathComponent("source"))
        let target = try NativeStore(directory: root.appendingPathComponent("target"))
        let id = try source.add("隔离导入")
        let media = source.records.directory.appendingPathComponent("media")
        try FileManager.default.createDirectory(at: media, withIntermediateDirectories: true)
        try Data([1, 2, 3]).write(to: media.appendingPathComponent("original.jpg"))
        try source.call("addMedia", ["id": .string(id), "value": .object(["id": .string("m1"), "type": .string("image"), "path": .string("media/original.jpg"), "fieldId": .string("")])])
        let worker = NativeBackup(), archive = root.appendingPathComponent("source.zip")
        try await worker.export(houses: [source.house(id)], root: source.records.directory, to: archive)
        let preview = try await worker.preview(archive)
        try linkMedia(from: target.records.directory, to: root.appendingPathComponent("other-media"))
        do {
            let staged = try await worker.stage(archive, preview: preview, selectedIDs: [id], into: target.records.directory)
            await worker.discard(staged)
            XCTFail("A symlink must not write into another scope")
        } catch { }
    }

    @MainActor func testExistingDirectoryAcceptsEquivalentURLForms() throws {
        let root = try root()
        let expected = root.standardizedFileURL.resolvingSymlinksInPath().appendingPathComponent("media")
        XCTAssertNoThrow(try LocalMediaFiles.directory(in: root, create: true))
        let resolved = expected.resolvingSymlinksInPath()
        print("Directory URL equivalence: expected=\(expected.absoluteString), resolved=\(resolved.absoluteString), pathsEqual=\(expected.path == resolved.path)")
        XCTAssertNoThrow(try LocalMediaFiles.directory(in: root))
        XCTAssertNoThrow(try LocalMediaFiles.directory(in: URL(fileURLWithPath: root.path, isDirectory: true)))
    }
}
