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
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { workspace?.save() }
                else if !AppWorkspace.isBusinessTest { Task { await workspace?.refreshPolicy(); await workspace?.billing.load() } }
            }
            .environment(\.locale, Locale(identifier: "zh_CN")).preferredColorScheme(.light)
            .overlay { TouchTrailPresentation() }
    }
    private func load() {
        do {
            #if DEBUG
            if let mode = CapacityBusinessFixture.mode() {
                workspace = try CapacityBusinessFixture.workspace(root: AppWorkspace.dataRoot(), mode: mode)
            } else if UtilityNetworkFixture.enabled {
                workspace = try AppWorkspace(root: AppWorkspace.dataRoot(), keychain: VolatileSessionStorage(), mapTransport: UtilityNetworkFixture.transport, mapKey: "fixture", places: UtilityNetworkFixture.places)
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
    @State private var wheels = WheelInputPresentation()
    var body: some View {
        NavigationStack {
            Group {
                if workspace.store.state["xiaoda"]["setup"].string != "done", !workspace.store.status.blocked {
                    InspectionSetupPage(workspace: workspace)
                } else { switch tab {
                case "对比": ComparisonPage(workspace: workspace)
                case "我的": SettingsPage(workspace: workspace, imported: { tab = "房源" })
                default: HomePage(workspace: workspace)
                } }
            }.safeAreaInset(edge: .bottom, spacing: 0) {
                if workspace.store.state["xiaoda"]["setup"].string == "done" || workspace.store.status.blocked {
                    XJTabBar(selection: $tab, items: [("房源", "home"), ("对比", "compare"), ("我的", "settings")])
                }
            }.background(XJTheme.background)
        }.id(workspace.identityRevision).tint(XJTheme.primary)
            .environment(\.wheelInput, wheels)
            .accessibilityHidden(wheels.target != nil)
            .overlay {
                if let target = wheels.target, let spec = WheelFieldSpec.all[target.field.id] {
                    WheelInputDialog(spec: spec, value: target.field["value"].string,
                        close: { wheels.target = nil }, save: { value in
                            workspace.perform { try wheels.save(value, store: workspace.store) }
                        }).id(target.id)
                }
            }
            .onChange(of: workspace.identityRevision) { wheels.target = nil }
            .task(id: workspace.identityRevision) {
                if !AppWorkspace.isBusinessTest { workspace.billing.start(); await workspace.refreshPolicy(); await workspace.billing.load() }
            }
            .toolbarBackground(XJTheme.background, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
            .alert("提示", isPresented: Binding(get: { !workspace.error.isEmpty }, set: { if !$0 { workspace.error = "" } })) {
                Button("知道了", role: .cancel) { workspace.error = "" }
            } message: { Text(workspace.error) }
    }
}

struct XJTabBar: View {
    @Binding var selection: String
    let items: [(String, String)]
    var mediaCount = 0
    var issueCount = 0
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { name, icon in
                Button { selection = name } label: {
                    VStack(spacing: items.count == 4 ? 1 : 3) {
                        XJIcon(name: icon + (selection == name ? "-selected" : "-default"))
                        Text(name + (items.count == 4 && name == "影像" ? " \(mediaCount)" : items.count == 4 && name == "问题" ? " \(issueCount)" : "")).font(.system(size: items.count == 4 ? 13 : 10, weight: items.count == 4 ? .medium : .regular))
                    }.frame(maxWidth: .infinity, minHeight: items.count == 4 ? 48 : 50).contentShape(Rectangle())
                        .foregroundStyle(selection == name ? XJTheme.primary : Color(red: 141 / 255, green: 149 / 255, blue: 163 / 255))
                }.buttonStyle(MPStaticButtonStyle()).accessibilityIdentifier("tab.\(name)")
                    .accessibilityAddTraits(selection == name ? .isSelected : [])
            }
        }.background(.white)
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
