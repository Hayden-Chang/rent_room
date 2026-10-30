#if DEBUG
import SwiftUI

struct HouseLongPressHintReviewHost: View {
    private let defaults: UserDefaults
    @State private var empty: Bool

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let index = arguments.firstIndex(of: "--hint-review-id")
        let runID = index.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? UUID().uuidString
        defaults = UserDefaults(suiteName: "house-hint-review." + runID)!
        _empty = State(initialValue: arguments.contains("--hint-review-empty"))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if empty {
                        EmptyHouseState { empty = false }
                    } else {
                        HouseLongPressHint(defaults: defaults)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                            HouseCard(house: HouseCardContent(name: "阳光小区", rent: "2800", address: "朝阳路18号", area: "45", decision: "", done: 0, total: 302, issues: 0)) {}
                                .accessibilityIdentifier("hint.review.house")
                        }
                    }
                }.padding(16)
            }.background(XJTheme.background)
                .miniNavigation(AppCopy.text("我的房源"), showsBack: false)
        }
    }
}
#endif
