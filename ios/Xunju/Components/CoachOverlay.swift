import SwiftUI

struct CoachStep { let title: String, body: String }

struct CoachAnchors: PreferenceKey {
    static var defaultValue: [Int: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct CoachCardHeight: PreferenceKey {
    static var defaultValue: CGFloat { 220 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

enum CoachPlacement {
    static func cardTop(target: CGRect?, height: CGFloat, available: CGFloat) -> CGFloat {
        guard let target else { return max(12, (available - height) / 2) }
        let below = target.maxY + 18, above = target.minY - height - 18
        if below + height <= available - 12 { return max(12, below) }
        if above >= 12 { return above }
        return max(12, available - height - 12)
    }
}

struct CoachOverlay: View {
    let steps: [CoachStep]
    let step: Int
    let target: CGRect?
    let fieldLabel: String
    @Binding var hideAutomatically: Bool
    var error = ""
    let next: () -> Void
    @State private var cardHeight: CGFloat = 220
    @State private var swiped = false

    var body: some View {
        let optedOut = hideAutomatically
        GeometryReader { geometry in
            if steps.indices.contains(step - 1) {
                let rect = target.map { step == 4 ? CGRect(x: $0.minX, y: $0.minY, width: $0.width, height: 48) : $0.insetBy(dx: -4, dy: -4) }
                let top = CoachPlacement.cardTop(target: rect, height: cardHeight, available: geometry.size.height)
                ZStack(alignment: .topLeading) {
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geometry.size))
                        if let rect { path.addRoundedRect(in: rect, cornerSize: CGSize(width: step == 4 ? 10 : 26, height: step == 4 ? 10 : 26)) }
                    }.fill(XJTheme.ink.opacity(0.6), style: FillStyle(eoFill: true))
                        .contentShape(Rectangle()).onTapGesture {}.accessibilityHidden(true)
                    if let rect {
                        RoundedRectangle(cornerRadius: step == 4 ? 10 : 26).stroke(.white, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY).allowsHitTesting(false)
                        Rectangle().fill(.white).frame(width: 2, height: max(0, top >= rect.maxY ? top - rect.maxY : rect.minY - (top + cardHeight)))
                            .offset(x: rect.midX - 1, y: top >= rect.maxY ? rect.maxY : top + cardHeight).allowsHitTesting(false)
                        if step == 4 {
                            swipeDemo.frame(width: rect.width, height: 48).offset(x: rect.minX, y: rect.minY)
                        }
                    }
                    card(optedOut: optedOut).frame(width: max(0, geometry.size.width - 32)).offset(x: 16, y: top)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.onPreferenceChange(CoachCardHeight.self) { cardHeight = $0 }
            .task(id: step) {
                swiped = false
                guard step == 4 else { return }
                // The original coach automatically demonstrates the left swipe.
                // This is product animation timing, never a test readiness wait.
                try? await Task.sleep(for: .milliseconds(900))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.45)) { swiped = true }
            }
    }

    private func card(optedOut: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\(step) / \(steps.count)").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
            Text(steps[step - 1].title).font(.system(size: 17, weight: .semibold)).padding(.top, 5).accessibilityIdentifier("coach.title")
            Text(steps[step - 1].body).font(.system(size: 14)).foregroundStyle(XJTheme.muted).lineSpacing(4).frame(minHeight: 48, alignment: .topLeading)
            if step == 4 {
                Button { hideAutomatically.toggle() } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4).fill(optedOut ? XJTheme.primary : .clear)
                            RoundedRectangle(cornerRadius: 4).stroke(optedOut ? XJTheme.primary : XJTheme.muted, lineWidth: 1.2)
                            if optedOut { Text("✓").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white) }
                        }.frame(width: 18, height: 18).accessibilityHidden(true)
                        Text("不再自动显示").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                    }.frame(minHeight: 36)
                }.buttonStyle(.plain).accessibilityIdentifier("coach.preference").accessibilityValue(optedOut ? "已选中" : "未选中")
                    .accessibilityAddTraits(optedOut ? [.isSelected] : [])
            }
            if target == nil { Text("当前清单没有可演示的检查项。").font(.system(size: 12)).foregroundStyle(XJTheme.danger) }
            if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(XJTheme.danger).accessibilityIdentifier("coach.error") }
            Button("知道了", action: next).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44).background(XJTheme.primary).clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.top, step == 4 ? 8 : 20).accessibilityIdentifier("coach.next")
        }.foregroundStyle(XJTheme.ink).padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 12)
            .frame(minHeight: step == 4 ? 220 : 196).background(.white).clipShape(RoundedRectangle(cornerRadius: 16))
            .background(GeometryReader { geometry in Color.clear.preference(key: CoachCardHeight.self, value: geometry.size.height) })
    }

    private var swipeDemo: some View {
        HStack(spacing: 0) {
            Text(fieldLabel).font(.system(size: 13)).foregroundStyle(XJTheme.ink).lineLimit(1).padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            if swiped {
                HStack(spacing: 0) {
                    XJIcon(name: "swipe-issue", size: 26).frame(width: 44, height: 44).accessibilityLabel("标记问题")
                    XJIcon(name: "swipe-note", size: 26).frame(width: 44, height: 44).accessibilityLabel("备注")
                    XJIcon(name: "coach-media", size: 26).frame(width: 44, height: 44).accessibilityLabel("影像")
                }.accessibilityElement(children: .ignore).accessibilityLabel("标记问题、备注、影像").accessibilityIdentifier("coach.actions")
                    .transition(.move(edge: .trailing))
            }
        }.background(.white).clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.width < -36 && abs(value.translation.width) > abs(value.translation.height) {
                    withAnimation(.easeOut(duration: 0.45)) { swiped = true }
                }
            }).accessibilityElement(children: .contain).accessibilityIdentifier("coach.demo")
    }
}
