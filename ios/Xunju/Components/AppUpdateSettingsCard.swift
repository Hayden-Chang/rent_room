import SwiftUI

enum AppUpdateCheckState: Equatable {
    case idle, checking, current, unavailable, failed, storefrontUnavailable, storeOpenFailed
    case available(String)
    case requiresSystem(String)

    var detail: String? {
        switch self {
        case .idle: nil
        case .checking: "正在检查…"
        case .current: "已是最新版本"
        case .available(let version): "新版本 \(version)"
        case .unavailable: "暂未查询到上架版本"
        case .failed: "检查失败，请重试"
        case .requiresSystem(let version): "需 iOS \(version) 或更高版本"
        case .storefrontUnavailable: "暂时无法获取商店信息"
        case .storeOpenFailed: "无法打开 App Store，请重试"
        }
    }
}

enum InstalledAppVersion {
    static func display(in bundle: Bundle = .main) -> String {
        let version = (bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return version.flatMap { $0.isEmpty ? nil : $0 } ?? "未知版本"
    }
}

// Presentation only. The owner supplies check results and performs the store handoff.
struct AppUpdateSettingsCard: View {
    var installedVersion = InstalledAppVersion.display()
    let state: AppUpdateCheckState
    @Binding var promptVersion: String?
    let onCheck: () -> Void
    let onUpdate: () -> Void

    private var offersUpdate: Bool {
        if case .available = state { return true }
        return false
    }

    var body: some View {
        XJCard {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("版本").accessibilityIdentifier("settings.versionLabel")
                    Text(installedVersion).foregroundStyle(XJTheme.muted)
                        .accessibilityIdentifier("settings.version")
                }.fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 0)
                Button(action: offersUpdate ? onUpdate : onCheck) {
                    HStack(spacing: 6) {
                        if state == .checking { ProgressView().controlSize(.small).accessibilityHidden(true) }
                        Text(offersUpdate ? "去更新" : state.detail ?? "检查更新")
                            .font(.system(size: state == .idle || offersUpdate ? 14 : 12))
                            .foregroundStyle(state == .idle || offersUpdate ? XJTheme.primary : XJTheme.muted)
                            .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                    }.frame(minHeight: 50).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(state == .checking)
                    .accessibilityLabel(offersUpdate ? "去更新" : "检查更新")
                    .accessibilityValue(state.detail ?? "")
                    .accessibilityIdentifier("settings.checkUpdate")
            }.font(.system(size: 14)).frame(minHeight: 50)
        }
        .alert("发现新版本", isPresented: Binding(
            get: { promptVersion != nil },
            set: { if !$0 { promptVersion = nil } }
        )) {
            Button("去更新", action: onUpdate)
            Button("稍后", role: .cancel) {}
        } message: {
            Text("版本 \(promptVersion ?? "") 已可下载，前往 App Store 更新。")
        }
    }
}
