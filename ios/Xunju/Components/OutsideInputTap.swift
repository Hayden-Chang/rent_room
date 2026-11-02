import SwiftUI
import UIKit

/// Observe taps without taking them away from the button or row the user chose.
/// Text bindings keep their existing save path; resigning commits native editing.
struct OutsideInputTap: UIViewRepresentable {
    func makeUIView(context: Context) -> ObserverView { ObserverView() }
    func updateUIView(_ view: ObserverView, context: Context) {}
    static func dismantleUIView(_ view: ObserverView, coordinator: ()) { view.detach() }

    @MainActor
    final class ObserverView: UIView, UIGestureRecognizerDelegate {
        private weak var observedWindow: UIWindow?
        private weak var editing: UIView?
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(finishEditing))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesBegan = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            return tap
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
        override func didMoveToWindow() {
            super.didMoveToWindow()
            detach()
            observedWindow = window
            window?.addGestureRecognizer(tap)
        }
        func detach() {
            observedWindow?.removeGestureRecognizer(tap)
            observedWindow = nil
            editing = nil
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            editing = nil
            guard let window = observedWindow,
                  let responder = Self.firstResponder(in: window),
                  Self.shouldDismiss(responder: responder, target: touch.view),
                  !window.keyboardLayoutGuide.layoutFrame.contains(touch.location(in: window)) else { return false }
            editing = responder
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        @objc private func finishEditing() {
            // A target may already have moved focus; never dismiss that new input.
            if editing?.isFirstResponder == true { editing?.resignFirstResponder() }
            editing = nil
        }
        static func shouldDismiss(responder: UIView, target: UIView?) -> Bool {
            guard responder is UITextField || responder is UITextView, let target else { return false }
            if target.isDescendant(of: responder) { return false }
            if let accessory = responder.inputAccessoryView, target.isDescendant(of: accessory) { return false }
            var ancestor: UIView? = target
            while let view = ancestor {
                if let input = view as? UITextField, input.isEnabled { return false }
                if let input = view as? UITextView, input.isEditable { return false }
                ancestor = view.superview
            }
            return true
        }
        private static func firstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for child in view.subviews {
                if let result = firstResponder(in: child) { return result }
            }
            return nil
        }
    }
}

extension View {
    func finishInputOnOutsideTap() -> some View { background(OutsideInputTap()) }
}
