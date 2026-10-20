import SwiftUI
import AuthenticationServices

struct SettingsPage: View {
    let workspace: AppWorkspace
    @State private var phone = false
    @State private var workplace = false
    @State private var appleChallenge: AppleChallenge?
    @State private var appleRequestedAt = Date.distantPast
    @State private var appleError = ""
    @State private var loggingOut = false
    private let api = AuthenticationAPI()
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if let session = workspace.session {
                    XJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(session.provider == "phone" ? "已通过手机号登录" : session.provider == "apple" ? "已通过 Apple 登录" : "已通过微信登录").font(.system(size: 16, weight: .semibold))
                            if session.expiresAt <= Date() { Text("登录已过期，本机记录已保留，请重新登录后购买扩容。").font(.system(size: 13)).foregroundStyle(XJTheme.muted) }
                            Text("房源容量  \(workspace.store.capacity.used) / \(workspace.store.capacity.limit) 套").font(.system(size: 14))
                            Button("退出登录") { loggingOut = true }.buttonStyle(XJButtonStyle(primary: false))
                        }
                    }
                } else {
                    LoginEntryCard(used: workspace.store.capacity.used, limit: workspace.store.capacity.limit, appleReady: appleChallenge != nil,
                        wechat: { workspace.error = "微信原生登录尚待配置开放平台 App ID 和 Universal Link" }, phone: { phone = true },
                        appleRequest: { request in request.nonce = appleChallenge?.nonce },
                        appleCompletion: { result in finishApple(result) })
                    if !appleError.isEmpty { Text(appleError).font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                }
                XJCard {
                    VStack(spacing: 0) {
                        Button { workplace = true } label: { menu("上班地点", detail: workspace.store.state["settings"]["workplace"].string.isEmpty ? "未设置" : workspace.store.state["settings"]["workplace"].string) }
                        NavigationLink { ArchivePage(workspace: workspace) } label: { menu("归档房源", detail: "\(workspace.store.archivedHouses.count) 套") }
                            .accessibilityIdentifier("settings.archive")
                        Toggle("操作引导", isOn: Binding(get: { workspace.store.state["settings"]["onboarding"].bool }, set: { value in
                            workspace.perform { try workspace.store.call("settings", ["property": .string("onboarding"), "value": .bool(value)]) }
                        })).font(.system(size: 14)).tint(XJTheme.primary).frame(minHeight: 52)
                    }
                }
                Text("数据与备份").font(.system(size: 13)).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, alignment: .leading)
                XJCard {
                    VStack(spacing: 0) {
                        NavigationLink { BackupPage(workspace: workspace, importing: true) } label: { menu("导入房源") }
                        NavigationLink { BackupPage(workspace: workspace) } label: { menu("导出房源") }.accessibilityIdentifier("settings.export")
                    }
                }
                XJCard {
                    Button { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } } label: { menu("权限管理") }
                }
                XJCard { HStack { Text("版本"); Spacer(); Text("0.1.0").foregroundStyle(XJTheme.muted) }.font(.system(size: 14)).frame(minHeight: 44) }
            }.padding(16)
        }.navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
            .task { await prepareApple() }
            .confirmationDialog("退出登录？", isPresented: $loggingOut, titleVisibility: .visible) {
                Button("退出登录") {
                    let token = workspace.session?.token
                    if workspace.perform({ try workspace.logout() }), let token { Task { try? await api.revoke(token) } }
                }
            } message: { Text("账号记录保留在本机，重新登录同一账号后可继续查看。") }
            .sheet(isPresented: $workplace) {
                NoteEditor(title: "上班地点", text: workspace.store.state["settings"]["workplace"].string) { value in
                    try workspace.store.call("settings", ["property": .string("workplace"), "value": .string(value)])
                    if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
                }
            }
            .sheet(isPresented: $phone) { PhoneAuthenticationPage(workspace: workspace) }
    }
    private func prepareApple() async {
        guard workspace.session == nil, !AppWorkspace.isBusinessTest else { return }
        do { appleChallenge = try await api.requestAppleChallenge(); appleRequestedAt = Date(); appleError = "" }
        catch { appleError = "Apple 登录服务暂不可用，请稍后重试" }
    }
    private func finishApple(_ result: Result<ASAuthorization, Error>) {
        let challenge = appleChallenge
        appleChallenge = nil
        Task { @MainActor in
            defer { Task { await prepareApple() } }
            do {
                let authorization = try result.get()
                guard let challenge, Date().timeIntervalSince(appleRequestedAt) < Double(challenge.expiresIn),
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                    throw CoreFailure(message: "Apple 登录请求已失效，请重试")
                }
                let receipt = try await api.appleSession(token: token, challenge: challenge)
                try workspace.accept(receipt)
            } catch let error as ASAuthorizationError where error.code == .canceled {} catch { workspace.error = error.localizedDescription }
        }
    }
    private func menu(_ title: String, detail: String = "") -> some View {
        HStack { Text(title).foregroundStyle(XJTheme.ink); Spacer(); Text(detail + " ›").foregroundStyle(XJTheme.muted).lineLimit(1) }
            .font(.system(size: 14)).frame(minHeight: 52).contentShape(Rectangle())
    }
}

struct PhoneAuthenticationPage: View {
    let workspace: AppWorkspace
    @State private var challenge: PhoneChallenge?
    @State private var challengedPhone = ""
    @State private var requestedAt = Date.distantPast
    private let api = AuthenticationAPI()
    var body: some View {
        NavigationStack {
            PhoneLoginForm(requestCode: { phone in
                if challengedPhone == phone, let challenge, Date().timeIntervalSince(requestedAt) < Double(challenge.retryAfter) {
                    throw CoreFailure(message: "请稍后再获取验证码")
                }
                let result = try await api.requestPhoneCode(phone)
                self.challenge = result; challengedPhone = phone; requestedAt = Date()
            }, submit: { phone, code in
                guard let challenge, phone == challengedPhone, Date().timeIntervalSince(requestedAt) < Double(challenge.expiresIn) else {
                    throw CoreFailure(message: "请先获取当前手机号的验证码")
                }
                let receipt = try await api.phoneSession(phone: phone, code: code, challenge: challenge)
                try workspace.accept(receipt)
            }).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } }
        }
    }
}

struct CloseSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("关闭") { dismiss() } }
}
