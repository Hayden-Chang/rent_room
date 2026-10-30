import SwiftUI

enum AppStoreReview {
    static let appID = "6828695680"

    static func url(appID: String?) -> URL? {
        guard let appID, !appID.isEmpty, appID.first != "0",
              appID.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }
}

struct AppStoreReviewRow: View {
    let appID: String?
    @Environment(\.openURL) private var openURL
    @State private var showingError = false

    var body: some View {
        Button {
            guard let url = AppStoreReview.url(appID: appID) else {
                showingError = true
                return
            }
            openURL(url) { accepted in showingError = !accepted }
        } label: {
            HStack(spacing: 16) {
                Text("在 App Store 中评价").fontWeight(.medium).foregroundStyle(XJTheme.ink)
                Spacer(minLength: 0)
                Text("›").font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted)
            }.font(.system(size: 14)).frame(minHeight: 50).contentShape(Rectangle())
                .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
        }.buttonStyle(.plain)
            .accessibilityIdentifier("settings.appStoreReview")
            .alert("无法打开 App Store", isPresented: $showingError) {
                Button("好", role: .cancel) {}
            } message: {
                Text("暂时无法打开评价页面，请稍后重试。")
            }
    }
}
