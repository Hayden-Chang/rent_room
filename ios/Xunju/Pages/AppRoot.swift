import SwiftUI

struct AppRoot: View {
    @State private var workspace: AppWorkspace?
    @State private var launchError = ""
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if let workspace { WorkspaceRoot(workspace: workspace) }
            else if !launchError.isEmpty {
                VStack(spacing: 16) {
                    Text("本机记录暂时无法打开").font(.headline)
                    Text(launchError).font(.subheadline)
                    Button("重试", action: load).buttonStyle(XJButtonStyle(primary: true))
                }.padding(24)
            } else { ProgressView("正在读取本机记录…") }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(XJTheme.background)
            .task { if workspace == nil { load() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { workspace?.save() } }
            .environment(\.locale, Locale(identifier: "zh_CN")).preferredColorScheme(.light)
    }
    private func load() {
        do {
            #if DEBUG
            if UtilityNetworkFixture.enabled {
                workspace = try AppWorkspace(root: AppWorkspace.dataRoot(), keychain: VolatileSessionStorage(), mapTransport: UtilityNetworkFixture.transport, mapKey: "fixture")
            } else {
                workspace = try AppWorkspace(root: AppWorkspace.dataRoot(), keychain: AppWorkspace.isBusinessTest ? VolatileSessionStorage() : SessionKeychain())
            }
            #else
            workspace = try AppWorkspace(root: AppWorkspace.dataRoot())
            #endif
            launchError = ""
        }
        catch { launchError = error.localizedDescription }
    }
}

private struct WorkspaceRoot: View {
    @Bindable var workspace: AppWorkspace
    @State private var tab = "房源"
    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case "对比": ComparisonPage(workspace: workspace)
                case "我的": SettingsPage(workspace: workspace)
                default: HomePage(workspace: workspace)
                }
            }.safeAreaInset(edge: .bottom, spacing: 0) {
                XJTabBar(selection: $tab, items: [("房源", "home"), ("对比", "compare"), ("我的", "settings")])
            }.background(XJTheme.background)
        }.id(workspace.identityRevision).tint(XJTheme.primary)
            .toolbarBackground(XJTheme.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .alert("提示", isPresented: Binding(get: { !workspace.error.isEmpty }, set: { if !$0 { workspace.error = "" } })) {
                Button("知道了", role: .cancel) { workspace.error = "" }
            } message: { Text(workspace.error) }
    }
}

struct XJTabBar: View {
    @Binding var selection: String
    let items: [(String, String)]
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { name, icon in
                Button { selection = name } label: {
                    VStack(spacing: 4) {
                        XJIcon(name: icon + (selection == name ? "-selected" : "-default"))
                        Text(name).font(.system(size: items.count == 4 ? 13 : 10))
                    }.frame(maxWidth: .infinity, minHeight: items.count == 4 ? 48 : 56).contentShape(Rectangle())
                        .foregroundStyle(selection == name ? XJTheme.primary : XJTheme.muted)
                }.buttonStyle(.plain).accessibilityIdentifier("tab.\(name)")
                    .accessibilityAddTraits(selection == name ? .isSelected : [])
            }
        }.padding(.horizontal, 8).background(.white)
            .overlay(alignment: .top) { Rectangle().fill(XJTheme.line).frame(height: 1) }
    }
}

struct SaveBanner: View {
    let workspace: AppWorkspace
    var body: some View {
        if !workspace.store.status.error.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(workspace.store.status.error).font(.system(size: 13))
                Button(workspace.store.status.blocked ? "尝试恢复本机记录" : "重试保存") {
                    workspace.perform { try workspace.store.call(workspace.store.status.blocked ? "recover" : "save") }
                }.buttonStyle(XJButtonStyle(primary: false))
            }.padding(12).foregroundStyle(XJTheme.danger).background(XJTheme.dangerBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityIdentifier("save.error")
        }
    }
}

struct TextPrompt: View {
    let title: String
    let placeholder: String
    @State var text: String
    var maxLength = 100
    let save: (String) throws -> Void
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField(placeholder, text: $text).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("prompt.text").focused($focused)
                    .onChange(of: text) { _, value in if value.count > maxLength { text = String(value.prefix(maxLength)) } }
                if !error.isEmpty {
                    Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger)
                        .accessibilityIdentifier("prompt.error")
                }
                Spacer()
            }.padding(20).background(XJTheme.background).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("确定") {
                            do { try save(text.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }
                            catch { self.error = error.localizedDescription }
                        }
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("prompt.confirm")
                    }
                }.onAppear { focused = true }
        }.presentationDetents([.medium])
    }
}
