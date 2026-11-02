import XCTest
import UIKit

@MainActor final class ChecklistNoteColorTests: XCTestCase {
    func testNotesUseWarmYellowAcrossRowStates() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "parity-notes", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let notes = [
            "分类备注：雨天再来看一次",
            "分组备注：重点检查窗框边缘",
            "普通备注：下午采光比较好",
            "问题备注：窗框有水渍，需要复查",
            "只读备注：原有记录继续保留"
        ]
        XCTAssertTrue(app.buttons[notes[0]].waitForExistence(timeout: 8))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "checklist-note-colors"
        attachment.lifetime = .keepAlways
        add(attachment)
        for note in notes {
            let button = app.buttons[note]
            XCTAssertTrue(button.exists)
            XCTAssertGreaterThan(try warmYellowPixels(button.screenshot().image), 25, note)
        }
        XCTAssertFalse(app.buttons["mp.field.choice.note-readonly.有"].isEnabled)
        XCTAssertTrue(app.staticTexts["mp.field.title.note-empty"].exists)
    }

    // Check actual rendered glyphs against the existing WeChat note color #B56516.
    // Tolerance allows rasterization while rejecting the old purple/gray text.
    private func warmYellowPixels(_ image: UIImage) throws -> Int {
        let source = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: source.width * source.height * 4)
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: source.width, height: source.height,
                bitsPerComponent: 8, bytesPerRow: source.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
        }
        var count = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let redMatches = abs(Int(pixels[index]) - 181) <= 5
            let greenMatches = abs(Int(pixels[index + 1]) - 101) <= 5
            let blueMatches = abs(Int(pixels[index + 2]) - 22) <= 5
            if redMatches && greenMatches && blueMatches && pixels[index + 3] > 250 {
                count += 1
            }
        }
        return count
    }
}
