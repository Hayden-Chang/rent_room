import SwiftUI

enum CapacityActivity: String, CaseIterable {
    case idle, loading, purchasing, restoring, pending
    var busy: Bool { [.loading, .purchasing, .restoring].contains(self) }
}

// The caller supplies the localized StoreKit price and verified capacity.
// Rendering or tapping this surface never grants an entitlement.
struct CapacitySurface: View {
    let used: Int
    let limit: Int
    let authenticated: Bool
    let price: String?
    var activity: CapacityActivity = .idle
    var error = ""
    let purchase: () -> Void
    let restore: () -> Void
    private var canPurchase: Bool { !activity.busy && activity != .pending && (!authenticated || price != nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XJCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("房源容量").font(.system(size: 17, weight: .semibold))
                    (Text("\(used)").font(.system(size: 38, weight: .semibold)).foregroundStyle(XJTheme.primary)
                     + Text(" / \(limit) 套").font(.system(size: 16)).foregroundStyle(XJTheme.muted))
                        .accessibilityIdentifier("capacity.total")
                }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
            }
            XJCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("房源包").font(.system(size: 17, weight: .semibold))
                        Spacer()
                        if activity == .loading { ProgressView().accessibilityLabel("正在加载价格") }
                        else { Text(price ?? "暂不可用").font(.system(size: price == nil ? 14 : 24, weight: .semibold)).foregroundStyle(XJTheme.primary)
                            .accessibilityIdentifier("capacity.price") }
                    }
                    Text("增加 10 套房源容量").font(.system(size: 16))
                    if !authenticated {
                        Text("购买或恢复已购容量需登录，免费记录可继续使用。")
                            .font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    }
                    Button(action: purchase) {
                        HStack(spacing: 8) {
                            if activity == .purchasing { ProgressView().tint(.white) }
                            Text(purchaseTitle)
                        }
                    }.buttonStyle(XJButtonStyle(primary: true)).disabled(!canPurchase)
                        .opacity(canPurchase ? 1 : 0.45).padding(.top, 12).accessibilityIdentifier("capacity.purchase")
                }.padding(4)
            }
            if activity == .pending {
                Text("支付结果仍在确认，请稍后重试。")
                    .font(.system(size: 14)).foregroundStyle(XJTheme.primary).padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.soft)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("capacity.pending")
            }
            if !error.isEmpty {
                Text(error).font(.system(size: 14)).foregroundStyle(XJTheme.danger).padding(.vertical, 12).padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading).background(XJTheme.dangerBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityIdentifier("capacity.error")
            }
            Button(action: restore) {
                HStack(spacing: 8) {
                    if activity == .restoring { ProgressView() }
                    Text(activity == .restoring ? "正在恢复容量…" : authenticated ? "恢复已购容量" : "登录并恢复容量")
                }.font(.system(size: 14, weight: .medium)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(XJTheme.primary).disabled(activity.busy)
                .opacity(activity.busy ? 0.45 : 1).padding(.top, 12).accessibilityIdentifier("capacity.restore")
        }.foregroundStyle(XJTheme.ink)
    }
    private var purchaseTitle: String {
        if activity == .loading { return "正在加载房源包…" }
        if activity == .purchasing { return "正在确认购买…" }
        if activity == .pending { return "等待购买结果" }
        if !authenticated { return "登录后购买" }
        return price.map { $0 + " 扩容10个" } ?? "房源包暂未开放"
    }
}
