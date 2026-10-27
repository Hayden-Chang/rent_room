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
    var cancel: () -> Void = {}
    private var canPurchase: Bool { !activity.busy && activity != .pending && (!authenticated || price != nil) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("房源额度").font(.system(size: 16, weight: .semibold))
                Spacer()
                (Text("\(used)").font(.system(size: 32, weight: .bold)).foregroundStyle(Color(red: 82/255, green: 80/255, blue: 220/255))
                 + Text(" / \(limit) 套").font(.system(size: 16)).foregroundStyle(XJTheme.muted))
                    .accessibilityIdentifier("capacity.total")
            }.frame(height: 48).padding(.horizontal, 22).padding(.vertical, 18)
                .frame(maxWidth: .infinity).background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(red: 226/255, green: 229/255, blue: 236/255), lineWidth: 2))
            VStack(alignment: .leading, spacing: 0) {
                Text("🍪 1 块小饼干 = 增加 10 套房源额度").font(.system(size: 17, weight: .bold)).lineSpacing(7).frame(minHeight: 27.2, alignment: .leading)
                GeometryReader { geometry in
                HStack(spacing: 12) {
                    Button("先等等", action: cancel).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 85/255, green: 91/255, blue: 193/255))
                        .frame(width: (geometry.size.width - 12) / 3, height: 48).disabled(activity.busy)
                    Button(action: purchase) {
                        HStack(spacing: 8) {
                            if activity == .purchasing { ProgressView().tint(.white) }
                            Text(purchaseTitle).font(.system(size: 15, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                        }
                    }.buttonStyle(SetupButtonStyle()).disabled(!canPurchase).opacity(canPurchase ? 1 : 0.45)
                        .frame(maxWidth: .infinity).layoutPriority(1).accessibilityIdentifier("capacity.purchase")
                }
                }.frame(height: 50).padding(.top, 20)
            }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 248/255, green: 247/255, blue: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(red: 217/255, green: 214/255, blue: 251/255), lineWidth: 2))
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
                }.font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(Color(red: 85/255, green: 91/255, blue: 193/255)).disabled(activity.busy)
                .opacity(activity.busy ? 0.45 : 1).padding(.top, -12).accessibilityIdentifier("capacity.restore") // 16-point stack gap minus 12 matches the 4-point CSS margin.
        }.foregroundStyle(XJTheme.ink).padding(.top, 24)
    }
    private var purchaseTitle: String {
        if activity == .loading { return "正在加载房源包…" }
        if activity == .purchasing { return "正在确认购买…" }
        if activity == .pending { return "等待购买结果" }
        if !authenticated { return "登录后购买" }
        return price.map { $0 + " 购买小饼干" } ?? "房源包暂未开放"
    }
}
