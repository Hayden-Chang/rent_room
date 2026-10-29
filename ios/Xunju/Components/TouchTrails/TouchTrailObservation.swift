import SwiftUI
import UIKit

/// Draws transient feedback in window coordinates, independently of SwiftUI state.
@MainActor
final class TouchTrailCanvas: UIView {
    static let maximumPoints = 24
    static let fadeDuration = 0.7

    struct Trail {
        var points: [CGPoint]
        let line: CAShapeLayer
        let circle: CAShapeLayer
    }

    private(set) var trails: [ObjectIdentifier: Trail] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.zPosition = 10_000
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func update(_ identifier: ObjectIdentifier, at point: CGPoint) {
        var trail = trails[identifier] ?? makeTrail()
        if trail.points.last != point { trail.points.append(point) }
        if trail.points.count > Self.maximumPoints {
            trail.points.removeFirst(trail.points.count - Self.maximumPoints)
        }
        let path = UIBezierPath()
        if let first = trail.points.first { path.move(to: first) }
        for point in trail.points.dropFirst() { path.addLine(to: point) }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        trail.line.path = path.cgPath
        trail.circle.path = UIBezierPath(ovalIn: CGRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32)).cgPath
        CATransaction.commit()
        trails[identifier] = trail
    }

    func finish(_ identifier: ObjectIdentifier) {
        guard let trail = trails.removeValue(forKey: identifier) else { return }
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            trail.line.removeFromSuperlayer()
            trail.circle.removeFromSuperlayer()
        }
        for shape in [trail.line, trail.circle] {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = Self.fadeDuration
            shape.opacity = 0
            shape.add(fade, forKey: "touch-end")
        }
        CATransaction.commit()
    }

    func finishActiveTouches() {
        for identifier in Array(trails.keys) { finish(identifier) }
    }

    func clear() {
        trails.removeAll()
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    private func makeTrail() -> Trail {
        let color = UIColor(XJTheme.primary)
        let line = CAShapeLayer()
        line.strokeColor = color.withAlphaComponent(0.75).cgColor
        line.fillColor = UIColor.clear.cgColor
        line.lineWidth = 3
        line.lineCap = .round
        line.lineJoin = .round
        let circle = CAShapeLayer()
        circle.strokeColor = color.cgColor
        circle.fillColor = color.withAlphaComponent(0.22).cgColor
        circle.lineWidth = 2
        for shape in [line, circle] {
            shape.contentsScale = window?.screen.scale ?? traitCollection.displayScale
            layer.addSublayer(shape)
        }
        return Trail(points: [], line: line, circle: circle)
    }
}

/// Stays passive so controls and native gestures receive their ordinary input.
@MainActor
final class TouchTrailRecognizer: UIGestureRecognizer {
    weak var canvas: TouchTrailCanvas?

    init(canvas: TouchTrailCanvas) {
        self.canvas = canvas
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) { update(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) { update(touches) }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { finish(touches) }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { finish(touches) }

    override func reset() {
        super.reset()
        canvas?.finishActiveTouches()
    }

    private func update(_ touches: Set<UITouch>) {
        guard let canvas else { return }
        for touch in touches where touch.type == .direct {
            canvas.update(ObjectIdentifier(touch), at: touch.location(in: canvas))
        }
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches { canvas?.finish(ObjectIdentifier(touch)) }
        if canvas?.trails.isEmpty != false { state = .failed }
    }
}

@MainActor
final class TouchTrailObserverView: UIView {
    private var isEnabled = false
    private weak var observedWindow: UIWindow?
    private(set) var canvas: TouchTrailCanvas?
    private(set) var recognizer: TouchTrailRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(clearTouches), name: UIApplication.willResignActiveNotification, object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        configure(isEnabled: isEnabled)
    }

    func configure(isEnabled: Bool) {
        self.isEnabled = isEnabled
        guard isEnabled, let window else { stopObserving(); return }
        guard observedWindow !== window else { return }
        stopObserving()
        let canvas = TouchTrailCanvas(frame: window.bounds)
        let recognizer = TouchTrailRecognizer(canvas: canvas)
        self.canvas = canvas
        self.recognizer = recognizer
        observedWindow = window
        window.addSubview(canvas)
        window.addGestureRecognizer(recognizer)
    }

    func stopObserving() {
        recognizer?.canvas = nil
        if let recognizer { observedWindow?.removeGestureRecognizer(recognizer) }
        recognizer = nil
        canvas?.clear()
        canvas?.removeFromSuperview()
        canvas = nil
        observedWindow = nil
    }

    @objc private func clearTouches() {
        canvas?.clear()
        recognizer?.isEnabled = false
        recognizer?.isEnabled = true
    }
}

struct TouchTrailObservation: UIViewRepresentable {
    let isEnabled: Bool

    func makeUIView(context: Context) -> TouchTrailObserverView { TouchTrailObserverView() }
    func updateUIView(_ uiView: TouchTrailObserverView, context: Context) { uiView.configure(isEnabled: isEnabled) }
    static func dismantleUIView(_ uiView: TouchTrailObserverView, coordinator: ()) { uiView.stopObserving() }
}

struct TouchTrailPresentation: View {
    @AppStorage(TouchTrailPreference.key) private var isEnabled = TouchTrailPreference.defaultValue

    init(defaults: UserDefaults = .standard) {
        _isEnabled = AppStorage(wrappedValue: TouchTrailPreference.defaultValue, TouchTrailPreference.key, store: defaults)
    }

    var body: some View {
        TouchTrailObservation(isEnabled: isEnabled).allowsHitTesting(false)
    }
}
