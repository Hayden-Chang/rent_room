import SwiftUI

/// Local presentation preference; dismissing this hint never changes house data.
struct HouseLongPressHint: View {
    static let preferenceKey = "presentation.house-long-press-hint.dismissed"
    @AppStorage private var dismissed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    init(defaults: UserDefaults? = nil) {
        _dismissed = AppStorage(wrappedValue: false, Self.preferenceKey, store: defaults)
    }

    var body: some View {
        if !dismissed {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            layout {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").accessibilityHidden(true)
                    Text(AppLanguage.shared.value == .english ? "Long press for more actions" : "长按支持更多操作")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("home.longPressHint.message")
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { dismissed = true }
                } label: {
                    Text(AppLanguage.shared.value == .english ? "Got it" : "我知道了")
                        .fontWeight(.medium).fixedSize()
                        .frame(minWidth: 64, minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("home.longPressHint.dismiss")
            }
            .font(.subheadline).foregroundStyle(XJTheme.ink)
            .padding(.horizontal, 16).padding(.vertical, 4)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home.longPressHint")
            .transition(.opacity)
        }
    }
}
