#if DEBUG
import SwiftUI

/// Disposable presentation fixtures. No workspace, persistence, network or purchases.
struct PropertyCreditsReviewHost: View {
    @State private var remaining = 7
    @State private var price: String? = "¥9.90"
    @State private var activity = CapacityActivity.idle
    @State private var error = ""
    @State private var purchases = 0
    @State private var restores = 0
    @State private var migrated: Int? = 7

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PropertyCreditsSurface(remaining: remaining, price: price, activity: activity, error: error, migrated: migrated,
                        purchase: { purchases += 1; activity = .purchasing },
                        restore: { restores += 1; activity = .restoring }, cancel: {})
                    Text("组件预览 · 测试余额与价格 · 购买回调 \(purchases) 次 · 恢复回调 \(restores) 次")
                        .font(.system(size: 12)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("review.credits.events")
                }.padding(20)
            }.background(.white)
                .navigationTitle(AppLanguage.shared.value == .english ? "Property credits" : "房源点数")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("评审状态") {
                            Button("中国区") { reset() }
                            Button("美国区英文") { reset(); AppLanguage.shared.value = .english; price = "$1.99"; migrated = nil }
                            Button("点数用完") { reset(); remaining = 0; migrated = nil }
                            Button("商品加载") { reset(); activity = .loading; price = nil }
                            Button("商品不可用") { reset(); price = nil }
                            Button("等待支付") { reset(); activity = .pending }
                            Button("取消购买") { activity = .idle; error = "" }
                            Button("恢复失败") { activity = .idle; error = "购买记录暂时无法确认，请稍后重试" }
                        }.accessibilityIdentifier("review.credits.state")
                    }
                }
        }.tint(XJTheme.primary)
    }
    private func reset() {
        AppLanguage.shared.value = .chinese
        remaining = 7; price = "¥9.90"; activity = .idle; error = ""; migrated = 7
    }
}
#endif
