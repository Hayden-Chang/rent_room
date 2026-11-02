import XCTest
import UIKit
@testable import Xunju

final class XiaodaTeachingTests: XCTestCase {
    @MainActor func testStageGuideRepeatsTabLabelsWithEggYellowEmphasisInBothLanguages() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "stage-guide-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try NativeStore(directory: root), id = try store.add("阶段说明")
        let entry = try store.call("inspectionGuide", ["id": .string(id)])["steps"].array[0]
        let labels = ["基本情况", "现场检查", "费用与合同"]
        XCTAssertEqual(entry["highlights"].array.map(\.string), labels)
        let yellow = UIColor(red: 184/255, green: 134/255, blue: 11/255, alpha: 1)
        for language in [SupportedLanguage.chinese, .english] {
            let text = AppCopy.text(entry["text"].string, language: language)
            let terms = labels.map { AppCopy.text($0, language: language) }
            let lines = text.components(separatedBy: "\n")
            XCTAssertEqual(lines.count, 4)
            let attributed = XiaodaSpeech.attributed(text, highlights: terms, icons: [:], fontSize: 15,
                lineHeight: 24.75, centered: false, highlightColor: yellow)
            XCTAssertEqual(attributed.string, text)
            for (index, term) in terms.enumerated() {
                XCTAssertTrue(lines[index + 1].contains(term), "Missing exact tab label: \(term)")
                let range = (text as NSString).range(of: term)
                guard range.location != NSNotFound else { XCTFail("Missing emphasis: \(term)"); continue }
                for offset in range.location..<NSMaxRange(range) {
                    XCTAssertEqual(attributed.attribute(.foregroundColor, at: offset, effectiveRange: nil) as? UIColor, yellow)
                    XCTAssertTrue(try XCTUnwrap(attributed.attribute(.font, at: offset, effectiveRange: nil) as? UIFont)
                        .fontDescriptor.symbolicTraits.contains(.traitBold))
                }
            }
            XCTAssertNotEqual(attributed.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, yellow)
        }
    }

    @MainActor func testSpeechUsesAvailableWidthAndKeepsExplicitNewlines() {
        let text = "在检查项上向左滑一下，试试看！"
        func lines(_ text: String, width: CGFloat) -> [String] {
            let value = XiaodaSpeech.attributed(text, highlights: [], icons: [:], fontSize: 15,
                lineHeight: 24.75, centered: false, highlightColor: .brown)
            let storage = NSTextStorage(attributedString: value), manager = NSLayoutManager()
            let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            storage.addLayoutManager(manager); manager.addTextContainer(container)
            var result: [String] = []
            manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, used, _, range, _ in
                XCTAssertLessThanOrEqual(used.width, width + 1)
                let characters = manager.characterRange(forGlyphRange: range, actualGlyphRange: nil)
                result.append((value.string as NSString).substring(with: characters))
            }
            return result
        }
        for width: CGFloat in [209, 171] {
            let rendered = lines(text, width: width)
            XCTAssertTrue(rendered.first?.contains("向左滑一下") == true, "\(width): \(rendered)")
            XCTAssertEqual(rendered.joined(), text)
        }
        let narrow = lines(text, width: 90)
        XCTAssertGreaterThan(narrow.count, 2)
        XCTAssertEqual(narrow.joined(), text)
        XCTAssertEqual(lines("第一行\n第二行🍪", width: 209), ["第一行\n", "第二行🍪"])
    }
    @MainActor func testAttributedSpeechKeepsEmphasisAndInlineActionImages() throws {
        let value = XiaodaSpeech.attributed("写备注🖊，\n拍照📷", highlights: ["写备注"], icons: ["🖊": "note", "📷": "camera"],
            fontSize: 15, lineHeight: 34, centered: false, highlightColor: .brown)
        XCTAssertEqual(value.string, "写备注 \u{fffc} ，\n拍照 \u{fffc} ")
        XCTAssertEqual(value.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor, .brown)
        XCTAssertTrue(try XCTUnwrap(value.attribute(.font, at: 0, effectiveRange: nil) as? UIFont).fontDescriptor.symbolicTraits.contains(.traitBold))
        var count = 0
        value.enumerateAttribute(.attachment, in: NSRange(location: 0, length: value.length)) { attachment, _, _ in
            if let attachment = attachment as? NSTextAttachment {
                count += 1
                XCTAssertEqual(attachment.bounds.size, CGSize(width: 21, height: 21))
                XCTAssertNotNil(attachment.image)
            }
        }
        XCTAssertEqual(count, 2)
    }
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
    func testTeachingGestureExposesClampedProgressAndClearsRejectedAttempts() {
        var gesture = XiaodaSwipeGesture()
        XCTAssertEqual(gesture.offset, 0)
        gesture.move(x: -6, y: 0, time: 0)
        XCTAssertEqual(gesture.offset, 0)
        gesture.move(x: -25, y: 0, time: 1)
        XCTAssertEqual(gesture.offset, -25)
        gesture.move(x: -200, y: 0, time: 2)
        XCTAssertEqual(gesture.offset, -132)
        XCTAssertTrue(gesture.end(x: -85, y: 0, time: 3))
        XCTAssertEqual(gesture.offset, 0)
        gesture.move(x: 30, y: 0, time: 4)
        gesture.move(x: -70, y: 0, time: 5)
        XCTAssertEqual(gesture.offset, 0)
        XCTAssertFalse(gesture.end(x: -70, y: 0, time: 6))
        gesture.move(x: 0, y: 30, time: 7)
        gesture.move(x: -70, y: 0, time: 8)
        XCTAssertEqual(gesture.offset, 0)
        XCTAssertFalse(gesture.end(x: -70, y: 0, time: 9))
        gesture.move(x: -30, y: 0, time: 10)
        XCTAssertEqual(gesture.offset, -30)
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
    func testTutorialScrollKeepsContextAndReservesMeasuredCardSpace() throws {
        let field = CGRect(x: 44, y: 1800, width: 317, height: 48)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: field, cardHeight: nil, available: 650), 0)
        let adjustment = XiaodaTutorialLayout.scrollAdjustment(target: field, cardHeight: 230, available: 650)
        XCTAssertEqual(field.minY - adjustment, 336)
        let visible = field.offsetBy(dx: 0, dy: -adjustment)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAdjustment(target: visible, cardHeight: 230, available: 650), 0)
        let anchor = try XCTUnwrap(XiaodaTutorialLayout.scrollAnchor(target: field, cardHeight: 230, available: 650))
        XCTAssertEqual(anchor.y * (650 - field.height), visible.minY, accuracy: 0.001)
        XCTAssertEqual(XiaodaTutorialLayout.scrollAnchor(target: visible, cardHeight: 230, available: 650), anchor)
        let tallerCardAnchor = try XCTUnwrap(XiaodaTutorialLayout.scrollAnchor(target: visible, cardHeight: 330, available: 650))
        XCTAssertEqual(tallerCardAnchor.y * (650 - field.height), 236, accuracy: 0.001)
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
