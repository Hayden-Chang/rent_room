#if DEBUG
import SwiftUI

// Explicit component review only. No workspace, account, StoreKit or network.
struct CapacityReviewHost: View {
    @State private var authenticated = false
    @State private var activity: CapacityActivity = .idle
    @State private var price: String? = "¥1.99"
    @State private var error = ""
    @State private var used = 2
    @State private var purchases = 0
    @State private var restores = 0
    @State private var logins = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CapacitySurface(used: used, limit: 2, authenticated: authenticated, price: price, activity: activity, error: error,
                        purchase: {
                            if authenticated { purchases += 1; activity = .purchasing; error = "" }
                            else { logins += 1 }
                        }, restore: {
                            if authenticated { restores += 1; activity = .restoring; error = "" }
                            else { logins += 1 }
                        })
                    Text("测试价格 · 登录回调 \(logins) 次 · 购买回调 \(purchases) 次 · 恢复回调 \(restores) 次")
                        .font(.system(size: 12)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("review.capacity.events")
                }.padding(16)
            }.background(XJTheme.background).navigationTitle("房源容量").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("评审状态") {
                            Button("游客") { reset(); authenticated = false }
                            Button("已登录") { reset() }
                            Button("商品加载") { reset(); price = nil; activity = .loading }
                            Button("商品未开放") { reset(); price = nil; error = "房源包暂未开放购买，请稍后再试" }
                            Button("取消购买") { activity = .idle; error = "" }
                            Button("等待购买确认") { reset(); activity = .pending }
                            Button("恢复失败") { activity = .idle; error = "购买记录暂时无法确认，请稍后重试" }
                            Button("已有记录超过容量") { reset(); used = 12 }
                        }.accessibilityIdentifier("review.capacity.state")
                    }
                }
        }.tint(XJTheme.primary)
    }
    private func reset() { authenticated = true; activity = .idle; price = "¥1.99"; error = ""; used = 2 }
}
#endif
