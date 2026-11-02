import XCTest
import UIKit

@MainActor final class InspectionTeachingReviewTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private func capture(_ name: String, _ app: XCUIApplication) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    func testTeachingSwipeRendersIntermediateActionWidths() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "inspection-teaching", "--record-teaching-swipe",
            "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        capture("swipe-before", app)
        let start = target.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -85, dy: 0)),
            withVelocity: XCUIGestureVelocity(rawValue: 70), thenHoldForDuration: 0.1)
        XCTAssertTrue(app.buttons["coach.next"].waitForExistence(timeout: 4))
        capture("swipe-after", app)
        let raw = try XCTUnwrap(app.otherElements["teaching.motion"].value as? String)
        let samples = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [[String: Any]])
        let widths = samples.compactMap { $0["width"] as? Int }
        let trace = XCTAttachment(string: String(describing: widths)); trace.name = "rendered-action-widths"; trace.lifetime = .keepAlways; add(trace)
        for (index, sample) in samples.enumerated() {
            let data = try XCTUnwrap(Data(base64Encoded: try XCTUnwrap(sample["png"] as? String)))
            let frame = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
            frame.name = "swipe-frame-\(index)-width-\(sample["width"] ?? 0)"; frame.lifetime = .keepAlways; add(frame)
        }
        XCTAssertTrue(widths.contains(0), "Capture must see the closed row: \(widths)")
        XCTAssertTrue(widths.contains { $0 >= 40 }, "Capture must see the fully revealed action: \(widths)")
        XCTAssertGreaterThanOrEqual(Set(widths.filter { (3...39).contains($0) }).count, 3,
            "The action must visibly slide through intermediate widths, not appear in one jump: \(widths)")
        XCTAssertEqual(app.staticTexts["teaching.events"].label, "未选择；操作次数：0")
    }
    func testGuardedSwipeTeachingAndRentFreeNumberKeyboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--component-review", "inspection-teaching", "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        app.launch()
        let target = app.otherElements["coach.swipeTarget"]
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["coach.next"].exists)
        // Compare actual rendered pixels inside the target across native captures;
        // no delay or animation-state fixture substitutes for visible movement.
        var regions = Set<Data>()
        for index in 0..<8 {
            let shot = app.screenshot(), image = shot.image
            let scale = image.size.width / app.frame.width * image.scale
            let frame = target.frame.applying(CGAffineTransform(scaleX: scale, y: scale))
            let crop = try XCTUnwrap(image.cgImage?.cropping(to: frame))
            regions.insert(try XCTUnwrap(UIImage(cgImage: crop).pngData()))
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "07-swipe-hand-\(index)"; attachment.lifetime = .keepAlways; add(attachment)
        }
        XCTAssertGreaterThan(regions.count, 1, "The hand must visibly animate without advancing the tutorial")
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        target.press(forDuration: 0.7)
        target.swipeRight()
        target.swipeUp()
        XCTAssertTrue(target.exists)
        XCTAssertEqual(app.otherElements["mp.field.teaching"].value as? String, "操作已收起")
        XCTAssertEqual(app.staticTexts["teaching.events"].label, "未选择；操作次数：0")
        target.swipeLeft()
        let next = app.buttons["coach.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 4))
        XCTAssertEqual(next.label, "我会啦")
        XCTAssertFalse(target.exists)
        let message = app.otherElements["xiaoda.message"]
        message.tap()
        capture("08-inline-action-icons", app)
        XCTAssertTrue(message.label.contains("标记问题"))
        next.tap()
        let input = app.textFields["mp.field.input.f5_3"]
        XCTAssertTrue(input.waitForExistence(timeout: 4))
        XCTAssertFalse(app.buttons["mp.field.wheel.f5_3"].exists)
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.keyboards.keys["a"].exists)
        let numeric = app.keyboards.keys["9"]
        XCTAssertTrue(numeric.exists)
        input.doubleTap()
        let selectAll = app.menuItems["全选"]
        if selectAll.waitForExistence(timeout: 2) { selectAll.tap() }
        XCTAssertTrue(numeric.isHittable, "The real numeric key must be touchable")
        numeric.tap()
        app.keyboards.keys["0"].tap()
        let keyboardImage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        keyboardImage.name = "09-rent-free-system-number-keyboard"; keyboardImage.lifetime = .keepAlways; add(keyboardImage)
        app.buttons["teaching.dismissKeyboard"].tap()
        XCTAssertEqual(input.value as? String, "90")
        XCTAssertTrue(app.staticTexts["teaching.days"].label.contains("原有备注"))
        capture("10-rent-free-input-preserves-note", app)
    }
}
