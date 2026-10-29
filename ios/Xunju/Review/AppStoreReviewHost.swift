#if DEBUG
import SwiftUI

struct AppStoreReviewHost: View {
    // A synthetic ID is intercepted by this host; it is never opened externally.
    private let fixtureID = "1234567890"
    @State private var openedURL = ""
    @State private var openCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    XJCard {
                        AppStoreReviewRow(appID: ProcessInfo.processInfo.arguments.contains("--review-missing-id") ? nil : fixtureID)
                    }
                    if !openedURL.isEmpty {
                        Text(openedURL).font(.footnote).accessibilityIdentifier("review.openedURL")
                        Text("打开次数：\(openCount)").accessibilityIdentifier("review.openCount")
                    }
                }.padding(16)
            }.background(XJTheme.background)
                .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
        }.environment(\.openURL, OpenURLAction { url in
            openedURL = url.absoluteString
            openCount += 1
            return ProcessInfo.processInfo.arguments.contains("--review-open-fails") ? .discarded : .handled
        })
    }
}
#endif
