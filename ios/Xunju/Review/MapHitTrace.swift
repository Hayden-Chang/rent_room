#if DEBUG
import SwiftUI
import UIKit
import Observation

// Read-only diagnosis, explicitly enabled only in the isolated place host.
@MainActor @Observable final class MapHitTrace {
    static let shared = MapHitTrace()
    static var enabled: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--map-hit-diagnostics") && ReviewSurface.parse(arguments) == .place
    }
    var report = ""
}

struct MapHitProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe { Probe() }
    func updateUIView(_ view: Probe, context: Context) { view.setNeedsLayout() }
    @MainActor final class Probe: UIView {
        override init(frame: CGRect) { super.init(frame: frame); isUserInteractionEnabled = false }
        required init?(coder: NSCoder) { fatalError("Unavailable") }
        override func layoutSubviews() {
            super.layoutSubviews()
            Task { @MainActor [weak self] in self?.sample() }
        }
        private func sample() {
            guard let window, bounds.width > 0, bounds.height > 0 else { return }
            let point = convert(CGPoint(x: bounds.midX, y: 27), to: window)
            var lines = ["probe=\(convert(bounds, to: window)); point=\(point)",
                         "hit=\(window.hitTest(point, with: nil).map { NSStringFromClass(type(of: $0)) } ?? "nil")"]
            for (name, local) in [("action-text", CGPoint(x: bounds.maxX - 28, y: 27)), ("title-text", CGPoint(x: 40, y: 18)), ("row-background", CGPoint(x: bounds.midX, y: 10))] {
                let probe = convert(local, to: window)
                lines.append("\(name) \(probe): \(window.hitTest(probe, with: nil).map { NSStringFromClass(type(of: $0)) } ?? "nil")")
            }
            func visit(_ view: UIView, depth: Int) {
                let local = view.convert(point, from: window)
                guard depth < 24, view.bounds.contains(local) else { return }
                let hit = view.hitTest(local, with: nil).map { NSStringFromClass(type(of: $0)) } ?? "nil"
                lines.append("\(depth): \(NSStringFromClass(type(of: view))) frame=\(view.convert(view.bounds, to: window)) bounds=\(view.bounds) inside=\(view.point(inside: local, with: nil)) hit=\(hit) interaction=\(view.isUserInteractionEnabled) hidden=\(view.isHidden) alpha=\(view.alpha)")
                for child in view.subviews { visit(child, depth: depth + 1) }
            }
            visit(window, depth: 0)
            let report = lines.joined(separator: "\n")
            if MapHitTrace.shared.report != report { MapHitTrace.shared.report = report }
        }
    }
}
#endif
