import XCTest
import UIKit

@MainActor final class CameraPresentationTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSystemCameraCoversScreenEdges() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--returning-business-fixture", "--business-test", UUID().uuidString,
                               "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let currency = app.buttons["currency.prompt.decline"]
        XCTAssertTrue(currency.waitForExistence(timeout: 10)); currency.tap()
        XCTAssertTrue(app.staticTexts["currency.prompt.title"].waitForNonExistence(timeout: 3))
        app.buttons["home.add"].tap()
        let name = app.textFields["prompt.text"]
        XCTAssertTrue(name.waitForExistence(timeout: 3)); name.replacePromptText("相机边缘检查")
        app.buttons["prompt.confirm"].tap()
        let capture = app.buttons["mp.checklist.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 5)); capture.tap()
        let source = app.otherElements["media.source"].buttons["拍照或录视频"]
        XCTAssertTrue(source.waitForExistence(timeout: 3)); source.tap()

        let camera = app.otherElements["media.camera"].firstMatch
        XCTAssertTrue(camera.waitForExistence(timeout: 10), "This regression requires the real system camera presentation")
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "system-camera-screen-edges"; attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertEqual(camera.frame.minY, app.frame.minY, accuracy: 1, "Camera must cover the top safe area")
        XCTAssertEqual(camera.frame.maxY, app.frame.maxY, accuracy: 1, "Camera must cover the bottom safe area")

        // Sample away from the notch, status indicators and home indicator.
        // Geometry alone would miss an exposed white presentation background.
        let image = try XCTUnwrap(screenshot.image.cgImage)
        for y in [5, image.height - 6] {
            for x in [image.width / 5, image.width * 4 / 5] {
                let pixel = try XCTUnwrap(image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)))
                var rgba = [UInt8](repeating: 0, count: 4)
                try rgba.withUnsafeMutableBytes { bytes in
                    let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1,
                        bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                    context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
                }
                XCTAssertTrue(rgba.prefix(3).allSatisfy { $0 < 40 }, "Expected black camera edge at \(x),\(y); got \(rgba)")
            }
        }
    }
}
