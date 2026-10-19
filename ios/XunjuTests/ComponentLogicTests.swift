import XCTest
import UIKit
import SwiftUI
@testable import Xunju

final class ComponentLogicTests: XCTestCase {
    @MainActor
    func testParityImagesAreAvailableToNativeViews() {
        for name in ["empty-art", "home-selected", "swipe-issue", "swipe-note", "swipe-camera"] {
            let image = UIImage(named: name)
            XCTAssertNotNil(image, "Missing native parity image: \(name)")
            XCTAssertGreaterThan(image?.size.width ?? 0, 0)
            XCTAssertGreaterThan(image?.size.height ?? 0, 0)
        }
    }

    @MainActor
    func testParityIconRendersVisiblePixels() throws {
        let decoded = try XCTUnwrap(UIImage(named: "home-selected"))
        XCTAssertGreaterThan(visiblePixels(decoded), 20, "Source PNG must contain visible pixels")
        let rendered = try XCTUnwrap(ImageRenderer(content: XJIcon(name: "home-selected", size: 46)).uiImage)
        XCTAssertGreaterThan(visiblePixels(rendered), 20, "Native icon must draw the bundled PNG")
    }

    private func visiblePixels(_ image: UIImage) -> Int {
        guard let source = image.cgImage else { return 0 }
        var bytes = [UInt8](repeating: 0, count: 64 * 64 * 4)
        let count = bytes.withUnsafeMutableBytes { buffer -> Int in
            guard let context = CGContext(data: buffer.baseAddress, width: 64, height: 64,
                                          bitsPerComponent: 8, bytesPerRow: 64 * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
            context.draw(source, in: CGRect(x: 0, y: 0, width: 64, height: 64))
            return stride(from: 3, to: buffer.count, by: 4).filter { buffer[$0] > 0 }.count
        }
        return count
    }

    func testPhoneRequiresElevenMainlandDigits() {
        XCTAssertTrue(PhoneLoginValidation.validPhone("13800138000"))
        for value in ["", "1380013800", "138001380001", "12800138000", "+8613800138000", "1380013800a", "13800138000\n"] {
            XCTAssertFalse(PhoneLoginValidation.validPhone(value), value)
        }
    }

    func testCodeRequiresSixASCIIDigits() {
        XCTAssertTrue(PhoneLoginValidation.validCode("012345"))
        for value in ["", "12345", "1234567", "１２３４５６", "12345a", "123456\n"] {
            XCTAssertFalse(PhoneLoginValidation.validCode(value), value)
        }
    }

    func testChoiceCanClearAndSwitchWithoutCouplingProblemFlag() {
        XCTAssertEqual(InspectionSelection.toggled(current: "正常", choice: "正常"), "")
        XCTAssertEqual(InspectionSelection.toggled(current: "正常", choice: "没有"), "没有")
        XCTAssertEqual(InspectionSelection.toggled(current: "", choice: "有问题"), "有问题")
    }

    #if DEBUG
    func testReviewHostRequiresExplicitKnownSurface() {
        XCTAssertNil(ReviewSurface.parse(["Xunju"]))
        XCTAssertNil(ReviewSurface.parse(["Xunju", "--component-review"]))
        XCTAssertNil(ReviewSurface.parse(["Xunju", "--component-review", "unknown"]))
        XCTAssertEqual(ReviewSurface.parse(["Xunju", "--component-review", "homes"]), .homes)
    }
    #endif
}
