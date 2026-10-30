import XCTest
import UIKit
@testable import Xunju

@MainActor final class PerformanceRegressionTests: XCTestCase {
    private func directory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-performance-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return root
    }
    private func image(width: CGFloat = 1200, color: UIColor = .purple) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: 800), format: format).image {
            color.setFill(); $0.fill(CGRect(x: 0, y: 0, width: width, height: 800))
        }
    }
    func testRepeatedThumbnailReadsReuseDecodedImage() throws {
        let url = try directory().appendingPathComponent("photo.jpg")
        try XCTUnwrap(image().jpegData(compressionQuality: 0.9)).write(to: url)
        let first = try XCTUnwrap(thumbnail(url))
        let second = try XCTUnwrap(thumbnail(url))
        XCTAssertTrue(first === second, "UI refresh must reuse the decoded thumbnail")
        XCTAssertEqual(max(first.cgImage!.width, first.cgImage!.height), 600)
    }
    func testThumbnailReplacementDeletionAndIdentityIsolation() throws {
        let root = try directory(), other = try directory()
        let url = root.appendingPathComponent("same.jpg"), second = other.appendingPathComponent("same.jpg")
        try XCTUnwrap(image().jpegData(compressionQuality: 0.9)).write(to: url)
        try XCTUnwrap(image(width: 800, color: .green).jpegData(compressionQuality: 0.9)).write(to: second)
        let original = try XCTUnwrap(thumbnail(url))
        XCTAssertFalse(original === thumbnail(second))
        try XCTUnwrap(image(width: 1600, color: .red).jpegData(compressionQuality: 0.9)).write(to: url, options: .atomic)
        let replacement = try XCTUnwrap(thumbnail(url))
        XCTAssertFalse(original === replacement)
        XCTAssertEqual(replacement.cgImage!.height, 300)
        try FileManager.default.removeItem(at: url)
        XCTAssertNil(thumbnail(url), "Deleted files must not be shown from cache")
    }
    func testPhotoImportAllowsMainActorProgress() async throws {
        let store = try NativeStore(directory: directory())
        let photo = image(width: 4000)
        var servicedUI = false
        let update = Task { @MainActor in servicedUI = true }
        let item = try await NativeMediaImport.stage(image: photo, video: nil, store: store, isCurrent: { true })
        let progressedDuringImport = servicedUI
        await update.value
        XCTAssertTrue(progressedDuringImport, "Photo import must release the main actor for queued UI work")
        let url = try LocalMediaFiles.file(item["path"].string, in: store.records.directory)
        XCTAssertNotNil(UIImage(contentsOfFile: url.path))
    }
    func testCancellingAnInFlightPhotoImportLeavesNoFile() async throws {
        let store = try NativeStore(directory: directory()), photo = image(width: 4000)
        var operation: Task<JSONValue, Error>?
        var began = false
        operation = Task { @MainActor in
            try await NativeMediaImport.stage(image: photo, video: nil, store: store, isCurrent: {
                if !began {
                    began = true
                    Task { @MainActor in operation?.cancel() }
                }
                return true
            })
        }
        do { _ = try await operation!.value; XCTFail("Cancellation during encoding must not accept the file") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(began)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: store.records.directory.appendingPathComponent("media").path).count, 0)
    }
    func testIncrementalReadsAndMutationReturnValuesKeepStoreCurrent() throws {
        let store = try NativeStore(directory: directory(), freeLimit: 2)
        let id = try store.add("数据保留")
        let before = store.state, summaries = store.houses
        _ = try store.form(id)
        _ = try store.call("inspectionGuide", ["id": .string(id)])
        XCTAssertEqual(store.state, before); XCTAssertEqual(store.houses, summaries)
        let result = try store.call("answer", ["id": .string(id), "field": .string("f1_6"), "property": .string("value"), "value": .string("2800")])
        XCTAssertEqual(result, store.state)
        XCTAssertEqual(store.houses.first?.rent, "2800")
        _ = try store.call("setFreeLimit", ["value": .number(3)])
        XCTAssertEqual(store.capacity.limit, 3)
        _ = try store.call("snapshot")
        XCTAssertEqual(store.house(id)["answers"]["f1_6"]["value"].string, "2800")
    }
    func testThirtyHouseReadBenchmark() throws {
        let root = try directory(), seed = try NativeStore(directory: root, freeLimit: 30)
        let id = try seed.add("性能样本")
        let house = seed.house(id)
        let houses = (0..<30).map { house.setting("id", to: .string("perf-\($0)")) }
        try seed.records.write(String(decoding: JSONEncoder().encode(seed.state.setting("houses", to: .array(houses))), as: UTF8.self), keepPrevious: false)
        let start = CFAbsoluteTimeGetCurrent()
        let store = try NativeStore(directory: root, freeLimit: 30)
        let launch = (CFAbsoluteTimeGetCurrent() - start) * 1000
        XCTAssertEqual(store.houses.count, 30)
        var timings: [Double] = []
        for _ in 0..<10 {
            let start = CFAbsoluteTimeGetCurrent()
            _ = try store.form("perf-0")
            _ = try store.call("inspectionGuide", ["id": .string("perf-0")])
            let media = try store.call("media", ["id": .string("perf-0")])
            XCTAssertTrue(media.array.isEmpty)
            timings.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
        }
        XCTAssertEqual(store.house("perf-29")["name"].string, "性能样本")
        print("PERF thirty-house startup_ms=\(launch) read_median_ms=\(timings.sorted()[5]) samples_ms=\(timings)")
    }
    func testWarmThumbnailBenchmark() throws {
        let url = try directory().appendingPathComponent("photo.jpg")
        try XCTUnwrap(image(width: 4000).jpegData(compressionQuality: 0.9)).write(to: url)
        _ = try XCTUnwrap(thumbnail(url))
        var timings: [Double] = []
        for _ in 0..<20 {
            let start = CFAbsoluteTimeGetCurrent()
            let value = try XCTUnwrap(thumbnail(url))
            timings.append((CFAbsoluteTimeGetCurrent() - start) * 1000)
            XCTAssertEqual(value.cgImage!.width, 600)
        }
        print("PERF warm-thumbnail median_ms=\(timings.sorted()[10]) samples_ms=\(timings)")
    }
}
