import SwiftUI

/// Presentation only. The caller owns the balance, StoreKit price and callbacks.
struct PropertyCreditsSurface: View {
    let remaining: Int
    let price: String?
    var activity: CapacityActivity = .idle
    var error = ""
    let purchase: () -> Void
    let restore: () -> Void
    let cancel: () -> Void

    private var english: Bool { AppLanguage.shared.value == .english }
    private func copy(_ zh: String, _ en: String) -> String { english ? en : zh }
    private var canPurchase: Bool { price != nil && !activity.busy && activity != .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(copy("剩余房源点数", "Property credits remaining"))
                    .font(.system(size: 16, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: "\(remaining)").font(.system(size: 32, weight: .bold)).foregroundStyle(XJTheme.primary)
                    Text(copy("点", "credits")).font(.system(size: 14)).foregroundStyle(XJTheme.muted)
                }.fixedSize().accessibilityElement(children: .combine).accessibilityIdentifier("credits.balance")
            }.padding(20).frame(maxWidth: .infinity)
                .background(.white).clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(XJTheme.line, lineWidth: 2))

            VStack(alignment: .leading, spacing: 18) {
                Text(copy("10 个房源点数", "10 property credits"))
                    .font(.system(size: 17, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(copy("新建 1 套房源消耗 1 点", "Creating a property uses 1 credit"))
                    .font(.system(size: 14)).foregroundStyle(XJTheme.muted)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("credits.rules")
                HStack(spacing: 12) {
                    Button(copy("先等等", "Not now"), action: cancel)
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(XJTheme.primary)
                        .frame(minWidth: 72, minHeight: 48).disabled(activity.busy)
                    Button(action: purchase) {
                        HStack(spacing: 8) {
                            if activity == .purchasing { ProgressView().tint(.white) }
                            Text(purchaseTitle).font(.system(size: 15, weight: .bold))
                                .fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(SetupButtonStyle()).disabled(!canPurchase).opacity(canPurchase ? 1 : 0.45)
                        .accessibilityIdentifier("credits.purchase")
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 248/255, green: 247/255, blue: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color(red: 217/255, green: 214/255, blue: 251/255), lineWidth: 2))

            if activity == .pending {
                Text(copy("支付结果正在确认，点数到账前不会增加余额。", "Payment is pending. Credits will appear after confirmation."))
                    .font(.system(size: 14)).foregroundStyle(XJTheme.primary)
                    .accessibilityIdentifier("credits.pending")
            }
            if !error.isEmpty {
                Text(verbatim: error).font(.system(size: 14)).foregroundStyle(XJTheme.danger)
                    .accessibilityIdentifier("credits.error")
            }
            Button(action: restore) {
                HStack(spacing: 8) {
                    if activity == .restoring { ProgressView() }
                    Text(activity == .restoring ? copy("正在恢复购买记录…", "Restoring purchases…") : copy("恢复购买记录", "Restore purchases"))
                }.font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(XJTheme.primary).disabled(activity.busy)
                .accessibilityIdentifier("credits.restore")
        }.foregroundStyle(XJTheme.ink)
    }

    private var purchaseTitle: String {
        switch activity {
        case .loading: return copy("正在加载点数包…", "Loading credits…")
        case .purchasing: return copy("正在确认购买…", "Confirming purchase…")
        case .pending: return copy("等待购买结果", "Payment pending")
        default: return price.map { copy("\($0) 购买 10 点", "\($0) Buy 10 credits") } ?? copy("点数包暂未开放", "Credits unavailable")
        }
    }
}
