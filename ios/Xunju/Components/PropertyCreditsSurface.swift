import SwiftUI

/// Presentation only. The caller owns the balance, StoreKit price and callbacks.
struct PropertyCreditsSurface: View {
    let remaining: Int
    let price: String?
    var activity: CapacityActivity = .idle
    var error = ""
    var fromCreation = false
    let purchase: () -> Void
    let restore: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var balanceSize = 64

    private var english: Bool { AppLanguage.shared.value == .english }
    private func copy(_ zh: String, _ en: String) -> String { english ? en : zh }
    private var canPurchase: Bool { price != nil && !activity.busy && activity != .pending }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if fromCreation && remaining == 0 {
                XiaodaMessage(text: copy("你的房源点数不够啦～", "You’re out of property credits~"), pose: "expect") {
                    EmptyView()
                }
            }
            VStack(spacing: 12) {
                Text(copy("剩余房源点数", "Property credits remaining"))
                    .font(.subheadline).foregroundStyle(XJTheme.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "\(remaining)")
                        .font(.system(size: balanceSize, weight: .bold, design: .rounded))
                        .monospacedDigit().foregroundStyle(XJTheme.primary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(copy("点", "credits")).font(.body).foregroundStyle(XJTheme.muted)
                }.accessibilityElement(children: .combine).accessibilityIdentifier("credits.balance")
                Text(copy("1 点 = 1 套新增房源", "1 credit = 1 new property"))
                    .font(.subheadline).foregroundStyle(XJTheme.muted)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8).accessibilityIdentifier("credits.rules")
            }.padding(.top, 24).padding(.bottom, 16).frame(maxWidth: .infinity)

            Button(action: purchase) {
                HStack(spacing: 8) {
                    if activity == .purchasing { ProgressView().tint(.white) }
                    Text(purchaseTitle).font(.headline)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, 12).padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(PropertyCreditsPurchaseStyle()).disabled(!canPurchase)
                .padding(.horizontal, 20).accessibilityIdentifier("credits.purchase")

            if activity == .pending {
                Text(copy("支付结果正在确认，点数到账前不会增加余额。", "Payment is pending. Credits will appear after confirmation."))
                    .font(.subheadline).foregroundStyle(XJTheme.primary)
                    .accessibilityIdentifier("credits.pending")
            }
            if !error.isEmpty {
                Text(verbatim: error).font(.subheadline).foregroundStyle(XJTheme.danger)
                    .accessibilityIdentifier("credits.error")
            }
            Button(action: restore) {
                HStack(spacing: 8) {
                    if activity == .restoring { ProgressView() }
                    Text(activity == .restoring ? copy("正在恢复购买记录…", "Restoring purchases…") : copy("恢复购买记录", "Restore purchases"))
                }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44)
            }.buttonStyle(.plain).foregroundStyle(XJTheme.muted).disabled(activity.busy)
                .accessibilityIdentifier("credits.restore")
        }.frame(maxWidth: 480).foregroundStyle(XJTheme.ink)
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

private struct PropertyCreditsPurchaseStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(.white)
            .background(XJTheme.primary, in: RoundedRectangle(cornerRadius: 14))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
    }
}
