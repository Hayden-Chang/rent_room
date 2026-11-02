import SwiftUI

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

// The converter keeps the actual touch and overlay in the same coordinate space.
struct TouchMenuLongPress: UIGestureRecognizerRepresentable {
    let open: (CGPoint) -> Void

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.45
        recognizer.allowableMovement = 10
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.state == .began { open(context.converter.location(in: .global)) }
    }
}

struct TouchActionMenu: View {
    let anchor: CGPoint
    let actions: [(String, Bool, () -> Void)]
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
                            }.buttonStyle(.plain).accessibilityIdentifier("touch-menu.action.\(index)")
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
