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
                        RegionalSettingsSection(preferences: regionalPreferences,
                            chooseLanguage: { event = "语言" }, chooseCurrency: { event = "货币类型" })
                        LocalSettingsSurface(remaining: 0, archived: 0, workplace: "", version: "0.1.0",
                            onboarding: $onboarding, action: { event = $0.title }, openLegal: openLegal)
                    } else {
                        AccountFreeCapacitySurface(remaining: 0, price: "¥9.90",
                            activity: pending ? .pending : .idle, error: failed ? "网络不可用，请联网后重试。" : "",
                            purchase: { pending = true }, restore: { pending = false; failed = true }, openLegal: openLegal)
                    }
                    if !event.isEmpty {
                        Text(event).font(.system(size: 12)).accessibilityIdentifier("local-review.event")
                    }
                }.padding(16)
            }.background(route == .settings ? XJTheme.background : .white)
                .miniNavigation(route == .settings ? "我的" : "房源点数", showsBack: false)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if route == .settings { XJTabBar(selection: .constant("我的"), items: [("房源", "home"), ("对比", "compare"), ("我的", "settings")]) }
                }
        }.tint(XJTheme.primary).preferredColorScheme(.light)
    }
    private var regionalPreferences: RegionalPreferences {
        var preferences = RegionalPreferences()
        preferences.language = .chinese
        preferences.detect(countryCode: "CN")
        return preferences
    }
    private func openLegal(_ page: LegalPage) { event = page.url.absoluteString }
}
#endif
