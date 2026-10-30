#if DEBUG
import SwiftUI

// Explicit review route only: responses and store failure are fixtures, with no network or account access.
struct AppUpdateReviewHost: View {
    enum Response: String, CaseIterable {
        case available = "发现新版本"
        case current = "已是最新版本"
        case unavailable = "商店暂无版本"
        case failed = "网络失败"
        case requiresSystem = "需要升级系统"
        case storefrontUnavailable = "无法获取商店"
    }

    @State private var response = Response.available
    @State private var state = AppUpdateCheckState.idle
    @State private var promptVersion: String?
    @State private var checks = 0
    @State private var storeOpens = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    AppUpdateSettingsCard(state: state, promptVersion: $promptVersion, onCheck: {
                        checks += 1
                        state = .checking
                    }, onUpdate: {
                        storeOpens += 1
                        state = .storeOpenFailed
                    })
                    VStack(alignment: .leading, spacing: 12) {
                        Text("检查更新组件预览").font(.system(size: 14, weight: .medium))
                        Text("以下控件仅用于验证组件状态，尚未连接 App Store。")
                            .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        Menu("测试响应：\(response.rawValue)") {
                            ForEach(Response.allCases, id: \.self) { item in
                                Button(item.rawValue) { response = item; state = .idle; promptVersion = nil }
                            }
                        }.accessibilityIdentifier("review.update.response")
                        if state == .checking {
                            Button("返回测试响应", action: finishCheck)
                                .accessibilityIdentifier("review.update.finish")
                        }
                        Text("检查 \(checks) 次 · 商店跳转回调 \(storeOpens) 次")
                            .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                            .accessibilityIdentifier("review.update.events")
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                }.padding(16)
            }.background(XJTheme.background)
                .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
        }.tint(XJTheme.primary)
    }

    private func finishCheck() {
        switch response {
        case .available: state = .available("1.2.0"); promptVersion = "1.2.0"
        case .current: state = .current
        case .unavailable: state = .unavailable
        case .failed: state = .failed
        case .requiresSystem: state = .requiresSystem("26.0")
        case .storefrontUnavailable: state = .storefrontUnavailable
        }
    }
}
#endif
