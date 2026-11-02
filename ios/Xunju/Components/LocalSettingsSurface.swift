import SwiftUI

enum LocalSettingsAction: String, CaseIterable {
    case capacity, workplace, archive, templates, importFile, export, permissions, feedback, share, language, currency
    var title: String {
        switch self {
        case .language: "语言"
        case .currency: "货币类型"
        case .capacity: "房源点数"
        case .workplace: "上班地点"
        case .archive: "删除房源"
        case .templates: "模板"
        case .importFile: "导入房源"
        case .export: "导出房源"
        case .permissions: "权限管理"
        case .feedback: "使用反馈"
        case .share: "分享看房搭子"
        }
    }
}

/// Presentation only. The owner supplies navigation and local persisted state.
struct LocalSettingsSurface: View {
    let remaining: Int
    let archived: Int
    let workplace: String
    let version: String
    @Binding var onboarding: Bool
    let action: (LocalSettingsAction) -> Void
    let openLegal: (LegalPage) -> Void
    #if DEBUG
    var grantDevelopmentCredits: (() throws -> Void)?
    func developmentCreditGrant(_ action: @escaping () throws -> Void) -> Self {
        var copy = self; copy.grantDevelopmentCredits = action; return copy
    }
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            XJCard { row(.capacity, detail: AppLanguage.shared.value == .english ? "\(remaining) credits" : "\(remaining) 点", rawDetail: true) }
            XJCard {
                VStack(spacing: 0) {
                    row(.workplace, detail: workplace.isEmpty ? AppCopy.text("未设置") : workplace, rawDetail: true)
                    row(.archive, detail: "\(archived) 套")
                    row(.templates)
                    Toggle(AppCopy.text("小搭"), isOn: $onboarding)
                        .font(.system(size: 14, weight: .medium)).toggleStyle(MPSwitchStyle())
                        .frame(minHeight: 60).accessibilityIdentifier("local-settings.onboarding")
                }
            }
            AppText("数据与备份").font(.system(size: 16, weight: .semibold)).padding(.top, 8)
            XJCard { VStack(spacing: 0) { row(.importFile); row(.export) } }
            XJCard { row(.permissions) }
            XJCard { VStack(spacing: 0) { row(.feedback); AppStoreReviewRow(appID: AppStoreReview.appID); row(.share) } }
            XJCard {
                VStack(spacing: 0) {
                    ForEach(LegalPage.allCases, id: \.self) { page in
                        Button { openLegal(page) } label: { menu(page.title) }
                            .accessibilityIdentifier("legal.\(page.rawValue)")
                    }
                }
            }
            XJCard { TouchTrailSettingsRow() }
            XJCard {
                #if DEBUG
                if let grantDevelopmentCredits {
                    DevelopmentCreditsVersionRow(version: version, grant: grantDevelopmentCredits)
                } else { versionLabel }
                #else
                versionLabel
                #endif
            }
        }.foregroundStyle(XJTheme.ink).buttonStyle(.plain)
    }
    private var versionLabel: some View {
        HStack { AppText("版本"); Spacer(); Text(verbatim: version).foregroundStyle(XJTheme.muted) }
            .font(.system(size: 14)).frame(minHeight: 50)
    }
    private func row(_ item: LocalSettingsAction, detail: String = "", rawDetail: Bool = false) -> some View {
        Button { action(item) } label: { menu(item.title, detail: detail, rawDetail: rawDetail) }
            .accessibilityIdentifier("local-settings.\(item.rawValue)")
    }
    private func menu(_ title: String, detail: String = "", rawDetail: Bool = false) -> some View {
        HStack(spacing: 16) {
            AppText(title).fontWeight(.medium).fixedSize()
            Spacer(minLength: 0)
            Text(verbatim: (rawDetail ? detail : AppCopy.text(detail)) + (detail.isEmpty ? "›" : " ›"))
                .font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted).lineLimit(1)
        }.font(.system(size: 14)).frame(minHeight: 50).contentShape(Rectangle())
            .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

struct AccountFreeCapacitySurface: View {
    let remaining: Int
    let price: String?
    let activity: CapacityActivity
    let error: String
    let purchase: () -> Void
    let restore: () -> Void
    let openLegal: (LegalPage) -> Void

    var body: some View {
        VStack(spacing: 16) {
            PropertyCreditsSurface(remaining: remaining, price: price,
                activity: activity, error: error, purchase: purchase, restore: restore)
            AppText("通过 App Store 购买，无需注册或登录看房搭子。购买与恢复需要联网，房源记录保存在本机。")
                .font(.system(size: 13)).foregroundStyle(XJTheme.muted)
            HStack(spacing: 24) {
                ForEach([LegalPage.privacy, .terms], id: \.self) { page in
                    Button(AppCopy.text(page.title)) { openLegal(page) }.accessibilityIdentifier("legal.\(page.rawValue)")
                }
            }.font(.system(size: 13)).buttonStyle(.plain).foregroundStyle(XJTheme.primary)
        }
    }
}
