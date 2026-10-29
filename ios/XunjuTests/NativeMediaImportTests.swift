import XCTest
import UIKit
@testable import Xunju

@MainActor final class NativeMediaImportTests: XCTestCase {
    private func store() throws -> NativeStore {
        let root = FileManager.default.temporaryDirectory.appending(path: "media-import-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return try NativeStore(directory: root)
    }
    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in UIColor.purple.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
    }
    func testImageStagesValidJPEGWithoutMutatingHouseAndScopeFailuresCleanUp() async throws {
        let store = try store(), id = try store.add("导入照片")
        let item = try await NativeMediaImport.stage(image: image(), video: nil, store: store, isCurrent: { true })
        let url = try LocalMediaFiles.file(item["path"].string, in: store.records.directory)
        XCTAssertNotNil(UIImage(contentsOfFile: url.path)); XCTAssertTrue(store.house(id)["media"].array.isEmpty)
        var checks = 0
        do {
            _ = try await NativeMediaImport.stage(image: image(), video: nil, store: store, isCurrent: { checks += 1; return checks == 1 })
            XCTFail("Changed identity must reject the staged image")
        } catch { XCTAssertTrue(error.localizedDescription.contains("账号已变化")) }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path).count, 1)
    }
    func testVideoExportsRealMP4AndInvalidSourceDoesNotLeavePartialFiles() async throws {
        let store = try store(), fixtures = try MediaReviewFixtures.make()
        defer { if let root = fixtures.first?.url?.deletingLastPathComponent() { try? FileManager.default.removeItem(at: root) } }
        let source = try XCTUnwrap(fixtures.first { $0.kind == .video }?.url)
        let item = try await NativeMediaImport.stage(image: nil, video: source, store: store, isCurrent: { true })
        XCTAssertEqual(item["type"].string, "video"); XCTAssertEqual(item["duration"].number ?? -1, 12, accuracy: 0.1)
        XCTAssertGreaterThan(try LocalMediaFiles.file(item["path"].string, in: store.records.directory).resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0, 0)
        do { _ = try await NativeMediaImport.stage(image: nil, video: source.deletingLastPathComponent(), store: store, isCurrent: { true }); XCTFail("Directory is not a video") } catch {}
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.records.directory.appending(path: "media").path).count, 1)
    }
    func testCancellationAndInvalidPayloadCreateNoMedia() async throws {
        let store = try store()
        let task = Task { @MainActor in try await NativeMediaImport.stage(image: self.image(), video: nil, store: store, isCurrent: { true }) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled import must fail") } catch { XCTAssertTrue(error is CancellationError) }
        do { _ = try await NativeMediaImport.stage(image: nil, video: nil, store: store, isCurrent: { true }); XCTFail("Empty import must fail") } catch {}
        let root = store.records.directory.appending(path: "media")
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: root.path).count) ?? 0, 0)
    }
    func testFixtureRequiresExplicitFlagAndValidDisposableIdentity() {
        let id = UUID().uuidString
        XCTAssertTrue(MediaImportFixture.enabled(["--business-test", id, "--media-import-fixture"]))
        for args in [[], ["--business-test", id], ["--media-import-fixture"], ["--business-test", "bad", "--media-import-fixture"], ["--media-import-fixture", "--business-test"]] {
            XCTAssertFalse(MediaImportFixture.enabled(args))
        }
    }
}
