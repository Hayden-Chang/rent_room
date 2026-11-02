#if DEBUG
import SwiftUI

/// UI-only approval host; the balance is deliberately in-memory, never a purchase.
struct DevelopmentCreditsReviewHost: View {
    @State private var remaining = 0
    let failGrant: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                XJCard {
                    HStack {
                        AppText("房源点数")
                        Spacer()
                        Text(verbatim: AppLanguage.shared.value == .english ? "\(remaining) credits" : "\(remaining) 点")
                            .accessibilityIdentifier("development-review.balance")
                    }.font(.system(size: 14)).frame(minHeight: 50)
                }
                XJCard {
                    DevelopmentCreditsVersionRow(version: "0.1.0") {
                        if failGrant { throw CoreFailure(message: "Fixture write failed") }
                        remaining += 10
                    }
                }
                Spacer()
            }.padding(16).foregroundStyle(XJTheme.ink).background(XJTheme.background)
                .miniNavigation(AppCopy.text("我的"))
        }.tint(XJTheme.primary).preferredColorScheme(.light)
    }
}
#endif
