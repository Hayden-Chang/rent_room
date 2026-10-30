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
                            LinearGradient(colors: [XJTheme.primary, XJTheme.primary.opacity(0.1)], startPoint: .leading, endPoint: .trailing).frame(width: 110, height: 4)
                        }.foregroundStyle(XJTheme.primary)
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
