import SwiftUI
import AuthenticationServices

struct SettingsPage: View {
    let workspace: AppWorkspace
    @State private var capacity = false
    @State private var appleChallenge: AppleChallenge?
    @State private var appleRequestedAt = Date.distantPast
    @State private var appleError = ""
    @State private var loggingOut = false
    @State private var appleTask: Task<Void, Never>?
    @State private var feedback = false
    @State private var applePreparationRevision = 0
    @State private var preparingApple = false
    @State private var api: AuthenticationAPI = {
        #if DEBUG
        if let api = AppleLoginFixture.api() { return api }
        #endif
        return AuthenticationAPI()
    }()
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SaveBanner(workspace: workspace)
                if let session = workspace.session {
                    XJCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(session.provider == "apple" ? "已通过 Apple 登录" : "已登录").font(.system(size: 16, weight: .semibold))
                            if session.expiresAt <= Date() { Text("登录已过期，本机记录已保留，请重新登录后购买扩容。").font(.system(size: 13)).foregroundStyle(XJTheme.muted) }
                            Button { capacity = true } label: { Text("房源容量  \(workspace.store.capacity.used) / \(workspace.store.capacity.limit) 套").font(.system(size: 14)) }.buttonStyle(.plain).accessibilityIdentifier("settings.capacity")
                            Button("退出登录") { loggingOut = true }.buttonStyle(XJButtonStyle(primary: false))
                        }
                    }
                } else {
                    LoginEntryCard(used: workspace.store.capacity.used, limit: workspace.store.capacity.limit, appleReady: appleChallenge != nil,
                        appleRequest: { request in request.nonce = appleChallenge?.nonce },
                        appleCompletion: { result in finishApple(result) }, capacity: { capacity = true })
                    if preparingApple {
                        ProgressView("正在准备 Apple 登录…").font(.system(size: 12))
                    } else if !appleError.isEmpty {
                        VStack(spacing: 8) {
                            Text(appleError).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                                .accessibilityIdentifier("login.apple.error")
                            Button("重试") { applePreparationRevision += 1 }
                                .font(.system(size: 14)).accessibilityIdentifier("login.apple.retry")
                        }
                    }
                }
                XJCard {
                    VStack(spacing: 0) {
                        NavigationLink { WorkplacePage(workspace: workspace) } label: { menu("上班地点", detail: workspace.store.state["settings"]["workplace"].string.isEmpty ? "未设置" : workspace.store.state["settings"]["workplace"].string) }
                            .accessibilityIdentifier("settings.workplace")
                        NavigationLink { ArchivePage(workspace: workspace) } label: { menu("归档房源", detail: "\(workspace.store.archivedHouses.count) 套") }
                            .accessibilityIdentifier("settings.archive")
                        NavigationLink { InspectionTemplatesPage(workspace: workspace) } label: { menu("检查清单模板") }
                            .accessibilityIdentifier("settings.templates")
                        Toggle("小搭引导", isOn: Binding(get: { workspace.store.state["xiaoda"]["enabled"].bool }, set: { value in
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
                XJCard {
                    VStack(spacing: 0) {
                        Button { feedback = true } label: { menu("使用反馈") }.accessibilityIdentifier("settings.feedback")
                        if let cover = Bundle.main.url(forResource: "InspectionShareCover", withExtension: "jpg") {
                            ShareLink(item: cover, subject: Text("看房搭子｜看房清单，避坑指南"), message: Text("看房搭子｜看房清单，避坑指南")) { menu("分享看房搭子") }
                                .accessibilityIdentifier("settings.share")
                        }
                    }
                }
                XJCard { HStack { Text("版本"); Spacer(); Text("0.1.0").foregroundStyle(XJTheme.muted) }.font(.system(size: 14)).frame(minHeight: 44) }
            }.padding(16)
        }.navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $capacity) { CapacityPage(workspace: workspace) }
            .task(id: [workspace.identityRevision, applePreparationRevision]) { await prepareApple() }
            .onDisappear { appleTask?.cancel(); appleChallenge = nil }
            .confirmationDialog("退出登录？", isPresented: $loggingOut, titleVisibility: .visible) {
                Button("退出登录") {
                    let token = workspace.session?.token
                    if workspace.perform({ try workspace.logout() }), let token { Task { try? await api.revoke(token) } }
                }
            } message: { Text("账号记录保留在本机，重新登录同一账号后可继续查看。") }
            .sheet(isPresented: $feedback) { FeedbackPage(workspace: workspace, completed: {}) }
    }
    private func prepareApple() async {
        appleChallenge = nil
        appleError = ""
        guard workspace.session == nil else { return }
        #if DEBUG
        if AppWorkspace.isBusinessTest && !AppleLoginFixture.enabled() { return }
        #endif
        preparingApple = true
        defer { preparingApple = false }
        do {
            let challenge = try await api.requestAppleChallenge()
            try Task.checkCancellation()
            guard workspace.session == nil else { return }
            appleChallenge = challenge; appleRequestedAt = Date()
        } catch is CancellationError {
        } catch {
            if !Task.isCancelled { appleError = "Apple 登录服务暂不可用，请稍后重试" }
        }
    }
    private func finishApple(_ result: Result<ASAuthorization, Error>) {
        let challenge = appleChallenge
        appleChallenge = nil
        let store = workspace.store
        appleTask = Task { @MainActor in
            defer { if !Task.isCancelled { applePreparationRevision += 1 } }
            do {
                let authorization = try result.get()
                guard let challenge, Date().timeIntervalSince(appleRequestedAt) < Double(challenge.expiresIn),
                      let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let data = credential.identityToken, let token = String(data: data, encoding: .utf8) else {
                    throw CoreFailure(message: "Apple 登录请求已失效，请重试")
                }
                let receipt = try await api.appleSession(token: token, challenge: challenge)
                try Task.checkCancellation()
                guard workspace.store === store else { throw CoreFailure(message: "账号已变化，请重新登录") }
                try workspace.accept(receipt)
            } catch is CancellationError {} catch let error as ASAuthorizationError where error.code == .canceled {} catch { workspace.error = error.localizedDescription }
        }
    }
    private func menu(_ title: String, detail: String = "") -> some View {
        HStack { Text(title).foregroundStyle(XJTheme.ink); Spacer(); Text(detail + " ›").foregroundStyle(XJTheme.muted).lineLimit(1) }
            .font(.system(size: 14)).frame(minHeight: 52).contentShape(Rectangle())
    }
}
