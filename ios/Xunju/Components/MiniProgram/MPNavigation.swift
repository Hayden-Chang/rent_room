import SwiftUI

/// Business navigation follows the mini-program's 44-point header on every iOS version.
/// Status-bar and home-indicator insets remain owned by the device.
private struct MPNavigation<Trailing: View>: ViewModifier {
    let title: String
    var showsBack: Bool
    var leadingTitle: Bool
    var background: Color
    var back: (() -> Void)?
    let trailing: Trailing
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content.foregroundStyle(XJTheme.ink).toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                ZStack(alignment: leadingTitle ? .leading : .center) {
                    Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                        .padding(.leading, leadingTitle ? 64 : 52).padding(.trailing, 52)
                    if showsBack {
                        HStack(spacing: 0) {
                            Button { if let back { back() } else { dismiss() } } label: {
                                Text("‹").font(.system(size: 34, weight: .semibold)).frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).padding(.leading, 4).accessibilityLabel("返回").accessibilityIdentifier("navigation.back")
                            Spacer(minLength: 0)
                        }
                    }
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        trailing.padding(.trailing, 4)
                    }
                }.frame(maxWidth: .infinity).frame(height: 44).foregroundStyle(XJTheme.ink)
                    .background(background.ignoresSafeArea(edges: .top))
                    .contentShape(Rectangle()).onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    .accessibilityElement(children: .contain).accessibilityIdentifier("navigation.header")
            }
    }
}

extension View {
    func miniNavigation(_ title: String, showsBack: Bool = true, leadingTitle: Bool = false,
                        background: Color = XJTheme.background, back: (() -> Void)? = nil) -> some View {
        modifier(MPNavigation(title: title, showsBack: showsBack, leadingTitle: leadingTitle, background: background, back: back, trailing: EmptyView()))
    }
}

extension View {
    func miniNavigation<Trailing: View>(_ title: String, showsBack: Bool = true, leadingTitle: Bool = false,
                                       background: Color = XJTheme.background, back: (() -> Void)? = nil,
                                       @ViewBuilder trailing: () -> Trailing) -> some View {
        modifier(MPNavigation(title: title, showsBack: showsBack, leadingTitle: leadingTitle,
                              background: background, back: back, trailing: trailing()))
    }
}
