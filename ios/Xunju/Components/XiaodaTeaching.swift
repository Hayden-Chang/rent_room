import SwiftUI
import UIKit

enum XiaodaSpeech {
    struct Part: Equatable { var text: String; var emphasis = false; var icon: String? }
    static func parts(_ text: String, highlights: [String], icons: [Character: String]) -> [Part] {
        let letters = Array(text), terms = highlights.filter { !$0.isEmpty }.map(Array.init).sorted { $0.count > $1.count }
        var result: [Part] = [], index = 0
        while index < letters.count {
            if let icon = icons[letters[index]] {
                result.append(Part(text: String(letters[index]), icon: icon)); index += 1; continue
            }
            let term = terms.first { letters[index...].starts(with: $0) }
            let count = term?.count ?? 1, value = String(letters[index..<(index + count)])
            if let last = result.last, last.icon == nil, last.emphasis == (term != nil) {
                result[result.count - 1].text += value
            } else { result.append(Part(text: value, emphasis: term != nil)) }
            index += count
        }
        return result
    }
    static func iconMap(_ value: JSONValue) -> [Character: String] {
        guard case let .object(entries) = value else { return [:] }
        return entries.reduce(into: [:]) { result, entry in
            if entry.key.count == 1, let character = entry.key.first,
               ["handle", "trash", "issue", "note", "camera"].contains(entry.value.string) {
                result[character] = entry.value.string
            }
        }
    }
    @MainActor static func attributed(_ text: String, highlights: [String], icons: [Character: String],
                                      fontSize: CGFloat, lineHeight: CGFloat, centered: Bool, highlightColor: UIColor) -> NSAttributedString {
        let font = UIFont.systemFont(ofSize: fontSize), paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .left
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineBreakStrategy = []
        paragraph.lineSpacing = max(0, lineHeight - font.lineHeight)
        let result = NSMutableAttributedString(string: "")
        for part in parts(text, highlights: highlights, icons: icons) {
            if let icon = part.icon {
                let isAction = ["issue", "note", "camera"].contains(icon)
                let image = isAction ? actionImage(icon) : UIImage(systemName: icon == "handle" ? "line.3.horizontal" : "trash",
                    withConfiguration: UIImage.SymbolConfiguration(font: font))?
                    .withTintColor(icon == "handle" ? .gray : UIColor(XJTheme.danger), renderingMode: .alwaysOriginal)
                if let image {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    attachment.bounds = CGRect(origin: CGPoint(x: 0, y: isAction ? -4 : font.descender), size: image.size)
                    if isAction { result.append(NSAttributedString(string: " ")) }
                    result.append(NSAttributedString(attachment: attachment))
                    if isAction { result.append(NSAttributedString(string: " ")) }
                    continue
                }
            }
            result.append(NSAttributedString(string: part.text, attributes: [
                .font: part.emphasis ? UIFont.boldSystemFont(ofSize: fontSize) : font,
                .foregroundColor: part.emphasis ? highlightColor : UIColor(red: 52/255, green: 59/255, blue: 77/255, alpha: 1)
            ]))
        }
        result.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: result.length))
        // Attachments and their spaces inherit the same font metrics as the surrounding text.
        result.enumerateAttribute(.font, in: NSRange(location: 0, length: result.length)) { value, range, _ in
            if value == nil { result.addAttribute(.font, value: font, range: range) }
        }
        return result
    }
    @MainActor static func actionImage(_ name: String) -> UIImage? { actionImages[name] }
    @MainActor private static let actionImages: [String: UIImage] = {
        let colors: [String: UIColor] = ["issue": UIColor(XJTheme.dangerBackground), "note": UIColor(XJTheme.soft), "camera": UIColor(XJTheme.primary)]
        return colors.reduce(into: [:]) { result, entry in
            guard let image = UIImage(named: "swipe-" + entry.key) else { return }
            result[entry.key] = UIGraphicsImageRenderer(size: CGSize(width: 21, height: 21)).image { context in
                entry.value.setFill(); context.fill(CGRect(x: 0, y: 0, width: 21, height: 21))
                image.draw(in: CGRect(x: 2, y: 2, width: 17, height: 17))
            }
        }
    }()
}

// Keep the same field padding, viewport clearance, and card gap as onboarding.js.
enum XiaodaTutorialLayout {
    static let accent = Color(red: 103/255, green: 99/255, blue: 237/255)
    static func spotlight(_ target: CGRect?, available: CGSize) -> CGRect? {
        guard let target, target.width > 0, target.height > 0,
              target.minY >= 0, target.maxY <= available.height else { return nil }
        return target.insetBy(dx: -4, dy: -4).intersection(CGRect(origin: .zero, size: available))
    }
    static func scrollAdjustment(target: CGRect?, cardHeight: CGFloat?, available: CGFloat) -> CGFloat {
        guard let target, let cardHeight else { return 0 }
        let desired = max(20, min(target.minY, available - cardHeight - target.height - 36))
        return target.minY - desired
    }
    static func scrollAnchor(target: CGRect?, cardHeight: CGFloat, available: CGFloat) -> UnitPoint? {
        guard let target, available > target.height else { return nil }
        let top = target.minY - scrollAdjustment(target: target, cardHeight: cardHeight, available: available)
        return UnitPoint(x: 0, y: min(1, max(0, top / (available - target.height))))
    }
    static func cardTop(target: CGRect?, height: CGFloat, available: CGFloat) -> CGFloat {
        guard let target else { return max(12, (available - height) / 2) }
        if target.maxY + height + 16 < available { return target.maxY + 16 }
        return max(12, target.minY - height - 16)
    }
}

// Measure and place in one layout pass, without feeding the card height back
// through state inside the parent's anchor-preference overlay.
struct XiaodaTutorialCardLayout: Layout {
    let target: CGRect?
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let card = subviews.first else { return }
        let size = card.sizeThatFits(ProposedViewSize(width: max(0, bounds.width - 24), height: nil))
        let top = XiaodaTutorialLayout.cardTop(target: target, height: size.height, available: bounds.height)
        card.place(at: CGPoint(x: bounds.minX + 12, y: bounds.minY + top), anchor: .topLeading,
            proposal: ProposedViewSize(width: size.width, height: size.height))
    }
}

// Reuse the checklist's distance/velocity rules; a wrong direction cancels the
// whole attempt, so returning left after an initial right/vertical drag is inert.
struct XiaodaSwipeGesture {
    private var motion = MPSwipeMotion()
    private var cancelled = false
    mutating func move(x: CGFloat, y: CGFloat, time: Double) {
        motion.sample(x: x, y: y, time: time)
        if motion.axis == .vertical || (motion.axis == .horizontal && x > 0) { cancelled = true }
    }
    mutating func end(x: CGFloat, y: CGFloat, time: Double) -> Bool {
        move(x: x, y: y, time: time)
        let accepted = !cancelled && motion.finish(x: x, y: y, time: time)
        self = XiaodaSwipeGesture()
        return accepted
    }
}

struct XiaodaSwipeTarget: View {
    let completed: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gesture = XiaodaSwipeGesture()
    @State private var started = Date()
    var body: some View {
        Rectangle().fill(.white.opacity(0.001)).contentShape(Rectangle())
            .overlay {
                TimelineView(.animation(paused: reduceMotion || scenePhase != .active)) { context in
                    let phase = context.date.timeIntervalSince(started).truncatingRemainder(dividingBy: 1.8) / 1.8
                    let travel = reduceMotion ? 0.5 : min(1, max(0, (phase - 0.22) / 0.48))
                    ZStack(alignment: .leading) {
                        HStack(spacing: 0) {
                            Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                            LinearGradient(colors: [XiaodaTutorialLayout.accent, XiaodaTutorialLayout.accent.opacity(0.1)], startPoint: .leading, endPoint: .trailing).frame(width: 110, height: 4)
                        }.foregroundStyle(XiaodaTutorialLayout.accent)
                        Image("coach-hand").resizable().scaledToFit().frame(width: 48, height: 52)
                            .offset(x: 104 * (1 - travel))
                            .opacity(reduceMotion || (phase >= 0.12 && phase < 0.85) ? 1 : 0)
                    }.frame(width: 160, height: 52)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in gesture.move(x: value.translation.width, y: value.translation.height, time: value.time.timeIntervalSinceReferenceDate) }
                .onEnded { value in
                    if gesture.end(x: value.translation.width, y: value.translation.height, time: value.time.timeIntervalSinceReferenceDate) { completed() }
                })
            .accessibilityElement(children: .ignore).accessibilityLabel(AppCopy.text("在此检查项上向左滑"))
            .accessibilityIdentifier("coach.swipeTarget")
            .accessibilityAction(named: AppCopy.text("向左滑")) { completed() }
            .onChange(of: scenePhase) { _, _ in gesture = XiaodaSwipeGesture() }
            .onDisappear { gesture = XiaodaSwipeGesture() }
    }
}
