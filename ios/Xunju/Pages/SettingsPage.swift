import SwiftUI
import AuthenticationServices
import PhotosUI

struct SettingsPage: View {
    let workspace: AppWorkspace
    var showsBack = false
    var imported: () -> Void = {}
    @State private var profileDirectory: URL?
    @State private var nickname = ""
    @State private var avatar: UIImage?
    @State private var avatarItem: PhotosPickerItem?
    @State private var choosingAvatar = false
    @FocusState private var editingNickname: Bool
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
            VStack(alignment: .leading, spacing: 12) {
                SaveBanner(workspace: workspace)
                if let session = workspace.session {
                    XJCard {
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Button { choosingAvatar = true } label: {
                                    Group {
                                        if let avatar { Image(uiImage: avatar).resizable().scaledToFill() }
                                        else { MPAccountIcon() }
                                    }.frame(width: 54, height: 54).background(XJTheme.soft).clipShape(Circle())
                                }.buttonStyle(.plain).accessibilityLabel("选择头像").accessibilityIdentifier("settings.avatar")
                                VStack(alignment: .leading, spacing: 2) {
                                    TextField("昵称", text: $nickname, prompt: Text("昵称").foregroundStyle(XJTheme.ink))
                                        .font(.system(size: 20, weight: .semibold)).frame(height: 30).focused($editingNickname)
                                        .accessibilityIdentifier("settings.nickname")
                                        .onSubmit(saveNickname).onChange(of: editingNickname) { if !editingNickname { saveNickname() } }
                                    Text(session.provider == "apple" ? "已通过 Apple 登录" : "已登录")
                                        .font(.system(size: 13)).foregroundStyle(XJTheme.primary).frame(height: 19.5)
                                }
                            }.padding(.bottom, 16)
                            XJTheme.line.frame(height: 1)
                            Button { capacity = true } label: {
                                HStack {
                                    Text("房源容量")
                                    Spacer()
                                    Text("\(workspace.store.capacity.used) / \(workspace.store.capacity.limit) 套 ›").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                                }.font(.system(size: 14, weight: .medium)).padding(.top, 14)
                            }.buttonStyle(.plain).accessibilityIdentifier("settings.capacity")
                            if session.expiresAt <= Date() { Text("登录已过期，本机记录已保留，请重新登录后购买扩容。").font(.system(size: 13)).foregroundStyle(XJTheme.muted).padding(.top, 12) }
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
                        NavigationLink { InspectionTemplatesPage(workspace: workspace) } label: { menu("模板") }
                            .accessibilityIdentifier("settings.templates")
                        Toggle("小搭", isOn: Binding(get: { workspace.store.state["xiaoda"]["enabled"].bool }, set: { value in
                            workspace.perform { try workspace.store.call("settings", ["property": .string("onboarding"), "value": .bool(value)]) }
                        })).accessibilityIdentifier("小搭引导").font(.system(size: 14, weight: .medium)).toggleStyle(MPSwitchStyle()).frame(minHeight: 60).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                    }
                }
                Text("数据与备份").font(.system(size: 16, weight: .semibold)).foregroundStyle(XJTheme.ink).padding(.top, 8).frame(maxWidth: .infinity, alignment: .leading)
                XJCard {
                    VStack(spacing: 0) {
                        NavigationLink { BackupPage(workspace: workspace, importing: true, imported: imported) } label: { menu("导入房源") }.accessibilityIdentifier("settings.import")
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
                XJCard { HStack { Text("版本"); Spacer(); Text("0.1.0").foregroundStyle(XJTheme.muted) }.font(.system(size: 14)).frame(minHeight: 50).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) } }
                if workspace.session != nil {
                    Button("退出登录") { loggingOut = true }.font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.danger)
                        .frame(maxWidth: .infinity, minHeight: 48).background(.white).clipShape(RoundedRectangle(cornerRadius: 8)).padding(.top, 8)
                }
            }.padding(16)
        }.miniNavigation("我的", showsBack: showsBack)
            .navigationDestination(isPresented: $capacity) { CapacityPage(workspace: workspace) }
            .onAppear(perform: loadProfile)
            .photosPicker(isPresented: $choosingAvatar, selection: $avatarItem, matching: .images)
            .task(id: avatarItem) { await saveAvatar() }
            .task(id: [workspace.identityRevision, applePreparationRevision]) { await prepareApple() }
            .onDisappear { saveNickname(); appleTask?.cancel(); appleChallenge = nil }
            .confirmationDialog("退出登录？", isPresented: $loggingOut, titleVisibility: .visible) {
                Button("退出登录") {
                    let token = workspace.session?.token
                    if workspace.perform({ try workspace.logout() }), let token { Task { try? await api.revoke(token) } }
                }
            } message: { Text("账号记录保留在本机，重新登录同一账号后可继续查看。") }
            .fullScreenCover(isPresented: $feedback) { FeedbackPage(workspace: workspace, completed: {}).presentationBackground(.clear) }
    }
    private func loadProfile() {
        guard workspace.session != nil else { return }
        let profile = LocalAccountProfile(directory: workspace.store.records.directory)
        profileDirectory = workspace.store.records.directory
        let value = profile.read(); nickname = value.nickname
        avatar = profile.avatarURL(value).flatMap { UIImage(contentsOfFile: $0.path) }
    }
    private func saveNickname() {
        guard workspace.session != nil, workspace.store.records.directory == profileDirectory, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let profile = LocalAccountProfile(directory: workspace.store.records.directory)
        guard nickname != profile.read().nickname else { return }
        if workspace.perform({ try profile.saveNickname(nickname) }) { nickname = profile.read().nickname }
    }
    private func saveAvatar() async {
        guard let item = avatarItem, workspace.session != nil else { return }
        let store = workspace.store
        do {
            guard let data = try await item.loadTransferable(type: Data.self), data.count <= 50 * 1024 * 1024,
                  let image = UIImage(data: data) else { throw CoreFailure(message: "头像读取失败，请重新选择") }
            try Task.checkCancellation()
            guard workspace.store === store, workspace.session != nil else { return }
            let ratio = min(1, 512 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let result = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            guard let png = result.pngData() else { throw CoreFailure(message: "头像读取失败，请重新选择") }
            try LocalAccountProfile(directory: store.records.directory).saveAvatar(png)
            avatar = result
        } catch is CancellationError {} catch { if workspace.store === store { workspace.error = error.localizedDescription } }
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
        HStack(spacing: 16) {
            Text(title).fontWeight(.medium).foregroundStyle(XJTheme.ink).fixedSize()
            Spacer(minLength: 0)
            Text(detail + (detail.isEmpty ? "›" : " ›")).font(.system(size: 12, weight: .medium)).foregroundStyle(XJTheme.muted).lineLimit(1)
        }.font(.system(size: 14)).frame(minHeight: 50).contentShape(Rectangle())
            .overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

struct CloseSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("关闭") { dismiss() } }
}
