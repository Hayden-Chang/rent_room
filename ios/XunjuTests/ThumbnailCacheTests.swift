import XCTest
import UIKit
import ImageIO
import UniformTypeIdentifiers
@testable import Xunju

@MainActor final class ThumbnailCacheTests: XCTestCase {
    private func images() throws -> [URL] {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("xunju-cache-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 800), format: format).image {
            UIColor.purple.setFill(); $0.fill(CGRect(x: 0, y: 0, width: 1200, height: 800))
        }
        return try ["one.jpg", "two.jpg"].map { name in
            let url = root.appendingPathComponent(name)
            try XCTUnwrap(image.jpegData(compressionQuality: 0.9)).write(to: url)
            return url
        }
    }
    func testByteBudgetEvictsAndMemoryWarningClearsCache() throws {
        let urls = try images(), cache = ThumbnailCache(byteLimit: 1024 * 1024)
        let first = try XCTUnwrap(cache.image(at: urls[0]))
        _ = try XCTUnwrap(cache.image(at: urls[1]))
        XCTAssertLessThanOrEqual(cache.byteCount, 1024 * 1024)
        XCTAssertFalse(first === cache.image(at: urls[0]), "Least recently used decoded image must be evicted")
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(cache.byteCount, 0)
        XCTAssertNotNil(cache.image(at: urls[0]), "Eviction must not remove the original photo")
    }
    func testDownsamplingPreservesEXIFOrientationAndRejectsInvalidImage() throws {
        let url = try images()[0]
        let original = try XCTUnwrap(UIImage(contentsOfFile: url.path)?.cgImage)
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, original, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let cache = ThumbnailCache(), rotated = try XCTUnwrap(cache.image(at: url))
        XCTAssertEqual(rotated.cgImage!.width, 400); XCTAssertEqual(rotated.cgImage!.height, 600)
        try Data("invalid photo".utf8).write(to: url, options: .atomic)
        XCTAssertNil(cache.image(at: url))
        XCTAssertEqual(cache.byteCount, 0)
    }
}
