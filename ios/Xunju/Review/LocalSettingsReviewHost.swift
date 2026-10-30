#if DEBUG
import SwiftUI

enum LocalSettingsReviewRoute: String {
    case settings, capacity
    static func parse(_ arguments: [String]) -> Self? {
        guard let index = arguments.firstIndex(of: "--local-settings-review"),
              arguments.indices.contains(index + 1) else { return nil }
        return Self(rawValue: arguments[index + 1])
    }
}

/// Isolated UI review: no workspace, network, Keychain or StoreKit.
struct LocalSettingsReviewHost: View {
    let route: LocalSettingsReviewRoute
    @State private var onboarding = true
    @State private var event = ""
    @State private var pending = false
    @State private var failed = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if route == .settings {
                        LocalSettingsSurface(remaining: 0, archived: 2, workplace: "", version: "0.1.0",
                            onboarding: $onboarding, action: { event = $0.title }, openLegal: openLegal)
                    } else {
                        Text("房源容量不够啦").font(.system(size: 24, weight: .bold))
                        XiaodaMessage(text: "主人，可以投喂我一个小饼干🍪吗？", pose: "expect", compact: false, hero: true) { EmptyView() }
                        AccountFreeCapacitySurface(used: 1, limit: 1, price: "¥1.99",
                            activity: pending ? .pending : .idle, error: failed ? "网络不可用，已有容量和房源记录已保留，请联网后重试。" : "",
                            purchase: { pending = true }, restore: { pending = false; failed = true }, cancel: { event = "已取消" }, openLegal: openLegal)
                    }
                    if !event.isEmpty {
                        Text(event).font(.system(size: 12)).accessibilityIdentifier("local-review.event")
                    }
                }.padding(16)
            }.background(XJTheme.background)
                .miniNavigation(route == .settings ? "我的" : "房源容量")
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if route == .settings { XJTabBar(selection: .constant("我的"), items: [("房源", "home"), ("对比", "compare"), ("我的", "settings")]) }
                }
        }.tint(XJTheme.primary).preferredColorScheme(.light)
    }
    private func openLegal(_ page: LegalPage) { event = page.url.absoluteString }
}
#endif
