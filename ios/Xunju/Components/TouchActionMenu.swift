import SwiftUI
import UIKit

enum TouchMenuPlacement {
    static func frame(anchor: CGPoint, menu: CGSize, bounds: CGRect) -> CGRect {
        let inset = bounds.insetBy(dx: 12, dy: 12)
        let size = CGSize(width: min(menu.width, max(0, inset.width)),
                          height: min(menu.height, max(0, inset.height)))
        return CGRect(x: min(max(anchor.x + 8, inset.minX), inset.maxX - size.width),
                      y: min(max(anchor.y, inset.minY), inset.maxY - size.height),
                      width: size.width, height: size.height)
    }
}

// Keep the existing exclusive high-priority press/tap gesture in charge of the
// Button. The passive observer supplies coordinates without competing for input.
struct TouchMenuPressActions: ViewModifier {
    let tap: () -> Void
    let hold: (CGPoint) -> Void
    @State private var location = TouchMenuTouchLocation()

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { geometry in
                TouchMenuTouchObservation { point in
                    let frame = geometry.frame(in: .global)
                    location.point = CGPoint(x: frame.minX + point.x, y: frame.minY + point.y)
                }.frame(width: geometry.size.width, height: geometry.size.height).allowsHitTesting(false)
            }
        }.modifier(MPPressActions(tap: tap, hold: {
            if let point = location.point { hold(point) }
        }))
    }
}

private final class TouchMenuTouchLocation {
    var point: CGPoint?
}

private struct TouchMenuTouchObservation: UIViewRepresentable {
    let record: (CGPoint) -> Void
    func makeUIView(context: Context) -> TouchMenuTouchObserver { TouchMenuTouchObserver() }
    func updateUIView(_ view: TouchMenuTouchObserver, context: Context) { view.record = record }
    static func dismantleUIView(_ view: TouchMenuTouchObserver, coordinator: ()) { view.detach() }
}

@MainActor
final class TouchMenuTouchObserver: UIView {
    var record: (CGPoint) -> Void = { _ in }
    private weak var observedWindow: UIWindow?
    private(set) var recognizer: TouchMenuTouchRecognizer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detach()
        guard let window else { return }
        let recognizer = TouchMenuTouchRecognizer(observer: self)
        self.recognizer = recognizer
        observedWindow = window
        window.addGestureRecognizer(recognizer)
    }

    func detach() {
        if let recognizer { observedWindow?.removeGestureRecognizer(recognizer) }
        recognizer = nil
        observedWindow = nil
    }

    func recordIfInside(_ point: CGPoint) {
        if bounds.contains(point) { record(point) }
    }
}

@MainActor
final class TouchMenuTouchRecognizer: UIGestureRecognizer {
    private weak var observer: TouchMenuTouchObserver?

    init(observer: TouchMenuTouchObserver) {
        self.observer = observer
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let observer, let touch = touches.first else { return }
        observer.recordIfInside(touch.location(in: observer))
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
}

struct TouchActionMenu: View {
    let anchor: CGPoint
    let actions: [(String, Bool, () -> Void)]
    var identifiers: [String] = []
    let close: () -> Void
    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 48

    var body: some View {
        GeometryReader { geometry in
            let bounds = geometry.frame(in: .global)
            let frame = TouchMenuPlacement.frame(anchor: anchor,
                menu: CGSize(width: 220, height: rowHeight * CGFloat(actions.count) + 12), bounds: bounds)
            ZStack(alignment: .topLeading) {
                Color.clear.contentShape(Rectangle()).ignoresSafeArea()
                    .onTapGesture(perform: close).accessibilityHidden(true)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(actions.indices, id: \.self) { index in
                            Button(action: actions[index].2) {
                                AppText(actions[index].0)
                                    .font(.body)
                                    .foregroundStyle(actions[index].1 ? XJTheme.danger : XJTheme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: rowHeight)
                                    .padding(.horizontal, 18).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier(index < identifiers.count ? identifiers[index] : "touch-menu.action.\(index)")
                        }
                    }.padding(.vertical, 6)
                }.scrollBounceBehavior(.basedOnSize)
                    .frame(width: frame.width, height: frame.height)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("touch-menu.panel")
                    .offset(x: frame.minX - bounds.minX, y: frame.minY - bounds.minY)
            }.accessibilityAction(.escape, close)
        }
    }
}
