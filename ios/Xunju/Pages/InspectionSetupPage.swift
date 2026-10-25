import SwiftUI

struct InspectionSetupPage: View {
    let workspace: AppWorkspace
    @State private var draft = InspectionTemplateDraft(order: [])
    @State private var mode = InspectionMode.simple
    @State private var step = "sort"
    @State private var ready = false

    var body: some View {
        Group {
            if ready {
                InspectionSetupSurface(draft: Binding(get: { draft }, set: { value in
                    if workspace.perform({ try workspace.store.call("setupDraft", ["value": value.json]) }) { draft = value }
                }), mode: Binding(get: { mode }, set: { value in
                    if workspace.perform({ try workspace.store.call("setupMode", ["value": .string(value.rawValue)]) }) { mode = value }
                }), initialStep: step, changeStep: { value in
                    let saved = workspace.perform { try workspace.store.call("setupStep", ["value": .string(value)]) }
                    if saved { step = value }; return saved
                }, finish: {
                    workspace.perform { try workspace.store.call("setupFinish", ["value": .string(mode.rawValue)]) }
                })
            } else { ProgressView("读取清单设置…") }
        }.task {
            workspace.perform {
                let value = try workspace.store.call("setupState")
                draft = InspectionTemplateDraft(value["config"])
                mode = InspectionMode(rawValue: value["mode"].string) ?? .simple
                step = value["step"].string; ready = true
            }
        }
    }
}

struct InspectionTemplatesPage: View {
    let workspace: AppWorkspace
    @State private var selected = InspectionMode.detailed
    @State private var original = InspectionMode.detailed
    @State private var editing: InspectionMode?
    @State private var leaving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                InspectionModeChoice(selection: $selected)
                ForEach(InspectionMode.allCases, id: \.self) { mode in
                    Button("编辑" + mode.title + "清单") { editing = mode }
                        .buttonStyle(XJButtonStyle(primary: false)).accessibilityIdentifier("templates.edit.\(mode.rawValue)")
                }
                Text("模板只用于以后新建的房源，已有房源保留原来的清单和记录。")
                    .font(.system(size: 13)).foregroundStyle(XJTheme.muted)
            }.padding(20)
        }.background(.white).navigationTitle("检查清单模板").navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { if selected != original { leaving = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        if workspace.perform({ try workspace.store.call("templateSelect", ["value": .string(selected.rawValue)]) }) { dismiss() }
                    }.accessibilityIdentifier("templates.confirm")
                }
            }
            .confirmationDialog("修改尚未保存，是否放弃？", isPresented: $leaving, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }
            .sheet(item: $editing) { mode in NavigationStack { InspectionTemplatePage(workspace: workspace, mode: mode) } }
            .onAppear {
                let value = workspace.store.state["settings"]["selectedTemplate"].string
                selected = InspectionMode(rawValue: value) ?? .detailed; original = selected
            }
    }
}

extension InspectionMode: Identifiable { var id: String { rawValue } }

private struct InspectionTemplatePage: View {
    let workspace: AppWorkspace
    let mode: InspectionMode
    @State private var draft = InspectionTemplateDraft(order: [])
    @State private var original = InspectionTemplateDraft(order: [])
    @State private var leaving = false
    @State private var error = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView { InspectionTemplateEditor(draft: $draft).padding(20) }
            .background(.white).navigationTitle(mode.title).navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(draft != original)
            .safeAreaInset(edge: .bottom) { if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger).padding(16).background(.white).accessibilityIdentifier("template.error") } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("返回") { if draft != original { leaving = true } else { dismiss() } } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        do { try workspace.store.call("templateSave", ["value": .object(["mode": .string(mode.rawValue), "config": draft.json])]); dismiss() }
                        catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("template.save")
                }
            }
            .confirmationDialog("修改尚未保存，是否放弃？", isPresented: $leaving, titleVisibility: .visible) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            }.task {
                workspace.perform {
                    let modes = try workspace.store.call("templates")["modes"].array
                    draft = InspectionTemplateDraft(modes.first { $0.id == mode.rawValue }?["config"] ?? .null); original = draft
                }
            }
    }
}
