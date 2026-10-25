import SwiftUI
import Observation

/// Captures the enclosing native scroll view without replacing its delegate or gestures.
@MainActor @Observable final class NativeScrollPosition {
    @ObservationIgnored weak var view: UIScrollView?
    @ObservationIgnored private var edgeTask: Task<Void, Never>?
    @ObservationIgnored private var finger = CGPoint.zero
    @ObservationIgnored private var dragStart: CGFloat?
    private(set) var dragOffset: CGFloat = 0
    var offset: CGFloat? { view?.contentOffset.y }

    func restore(_ offset: CGFloat) {
        guard let view else { return }
        view.layoutIfNeeded()
        let minimum = -view.adjustedContentInset.top
        let maximum = max(minimum, view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom)
        view.setContentOffset(CGPoint(x: view.contentOffset.x, y: min(maximum, max(minimum, offset))), animated: false)
    }
    func track(_ point: CGPoint) {
        finger = point
        guard edgeTask == nil, let view else { return }
        dragStart = view.contentOffset.y
        edgeTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(16)) } catch { return }
                self?.advance()
            }
        }
    }
    private func advance() {
        guard let view, let dragStart else { return }
        let frame = view.convert(view.bounds, to: nil)
        let top = frame.minY + view.adjustedContentInset.top
        let bottom = frame.maxY - view.adjustedContentInset.bottom
        let distance: CGFloat = finger.y > bottom - 52 ? min(1, (finger.y - bottom + 52) / 52)
            : finger.y < top + 52 ? -min(1, (top + 52 - finger.y) / 52) : 0
        guard distance != 0 else { return }
        restore(view.contentOffset.y + distance * 8)
        dragOffset = view.contentOffset.y - dragStart
    }
    func stop() { edgeTask?.cancel(); edgeTask = nil; dragStart = nil; dragOffset = 0 }
}

struct NativeScrollProbe: UIViewRepresentable {
    let position: NativeScrollPosition
    func makeUIView(context: Context) -> Probe {
        let view = Probe(); view.position = position; view.isUserInteractionEnabled = false; return view
    }
    func updateUIView(_ view: Probe, context: Context) { view.position = position; view.attach() }
    final class Probe: UIView {
        weak var position: NativeScrollPosition?
        override func didMoveToWindow() { super.didMoveToWindow(); attach() }
        override func layoutSubviews() { super.layoutSubviews(); attach() }
        func attach() {
            var parent = superview
            while let current = parent {
                if let scroll = current as? UIScrollView { position?.view = scroll; return }
                parent = current.superview
            }
        }
    }
}
