import XCTest
import UIKit
@testable import Xunju

final class XiaodaTeachingTests: XCTestCase {
    func testSpeechKeepsUnicodeLinesAndMapsActionIcons() {
        let text = "标记问题❗、\n写备注🖊，\n拍照📷和录视频。"
        let parts = XiaodaSpeech.parts(text, highlights: ["写备注"], icons: ["❗": "issue", "🖊": "note", "📷": "camera"])
        XCTAssertEqual(parts.map(\.text).joined(), text)
        XCTAssertEqual(parts.compactMap(\.icon), ["issue", "note", "camera"])
        XCTAssertEqual(parts.filter(\.emphasis).map(\.text), ["写备注"])
        XCTAssertEqual(XiaodaSpeech.parts("普通消息", highlights: [], icons: [:]), [.init(text: "普通消息")])
        XCTAssertTrue(XiaodaSpeech.parts("", highlights: [""], icons: [:]).isEmpty)
    }
    func testIconMapRejectsUnknownAndMultipleCharacters() {
        XCTAssertEqual(XiaodaSpeech.iconMap(.object(["🗑": .string("trash"), "☰": .string("handle"), "AB": .string("note"), "?": .string("unknown")])), ["🗑": "trash", "☰": "handle"])
        XCTAssertTrue(XiaodaSpeech.iconMap(.null).isEmpty)
    }
    func testTeachingGestureRejectsTapRightVerticalAndAllowsRetry() {
        var gesture = XiaodaSwipeGesture()
        XCTAssertFalse(gesture.end(x: 0, y: 0, time: 1))
        gesture.move(x: 45, y: 1, time: 2)
        XCTAssertFalse(gesture.end(x: -80, y: 1, time: 3))
        gesture.move(x: 0, y: 45, time: 4)
        XCTAssertFalse(gesture.end(x: -80, y: 0, time: 5))
        gesture.move(x: -30, y: 1, time: 6)
        XCTAssertTrue(gesture.end(x: -70, y: 1, time: 7))
        XCTAssertFalse(gesture.end(x: 0, y: 0, time: 8))
    }
    func testTeachingGestureUsesChecklistShortFlickThreshold() {
        var gesture = XiaodaSwipeGesture()
        gesture.move(x: -8, y: 0, time: 0)
        XCTAssertTrue(gesture.end(x: -16, y: 0, time: 0.02))
        gesture.move(x: -8, y: 0, time: 1)
        XCTAssertFalse(gesture.end(x: -9, y: 0, time: 2))
    }
    @MainActor func testActionAndHandAssetsRenderAtInlineSize() throws {
        for icon in ["issue", "note", "camera"] {
            XCTAssertEqual(try XCTUnwrap(XiaodaSpeech.actionImage(icon)).size.width, 21)
        }
        XCTAssertNotNil(UIImage(named: "coach-hand"))
        XCTAssertNil(XiaodaSpeech.actionImage("unknown"))
    }
    func testTutorialSpotlightUsesFieldBoundsAndClipsOnlyAtViewportEdge() throws {
        let viewport = CGSize(width: 393, height: 650)
        let field = CGRect(x: 44, y: 350, width: 317, height: 48)
        XCTAssertEqual(XiaodaTutorialLayout.spotlight(field, available: viewport), field.insetBy(dx: -4, dy: -4))
        XCTAssertNil(XiaodaTutorialLayout.spotlight(field.offsetBy(dx: 0, dy: 500), available: viewport))
        XCTAssertNil(XiaodaTutorialLayout.spotlight(nil, available: viewport))
        let edge = try XCTUnwrap(XiaodaTutorialLayout.spotlight(CGRect(x: 2, y: 20, width: 389, height: 48), available: viewport))
        XCTAssertEqual(edge.minX, 0); XCTAssertEqual(edge.maxX, 393)
    }
    func testTutorialScrollKeepsContextAndReservesMeasuredCardSpace() {
        let field = CGRect(x: 44, y: 1800, width: 317, height: 48)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: field, cardHeight: nil, available: 650), 0)
        let adjustment = XiaodaTutorialLayout.scrollAdjustment(target: field, cardHeight: 230, available: 650)
        XCTAssertEqual(field.minY - adjustment, 336)
        let visible = field.offsetBy(dx: 0, dy: -adjustment)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: visible, cardHeight: 230, available: 650), 0)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: visible, cardHeight: 330, available: 650), 100)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: CGRect(x: 44, y: 0, width: 317, height: 48), cardHeight: 230, available: 650), -20)
    }
    func testTutorialCardStaysSeparatedFromHighlightOnBothSides() {
        let target = CGRect(x: 40, y: 336, width: 325, height: 56)
        XCTAssertEqual(XiaodaTutorialLayout.cardTop(target: target, height: 230, available: 650), 408)
        XCTAssertEqual(XiaodaTutorialLayout.cardTop(target: target, height: 230, available: 568), 90)
        XCTAssertEqual(XiaodaTutorialLayout.cardTop(target: nil, height: 230, available: 650), 210)
    }
    #if DEBUG
    func testTeachingReviewRequiresExplicitKnownRoute() {
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "inspection-teaching"]), .inspectionTeaching)
        XCTAssertNil(ReviewSurface.parse(["inspection-teaching"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review", "unknown"]))
    }
    #endif
}
