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
                }), conciseWelcome: true, initialStep: step, changeStep: { value in
                    let saved = workspace.perform { try workspace.store.call("setupStep", ["value": .string(value)]) }
                    if saved { step = value }; return saved
                }, finish: {
                    workspace.perform { try workspace.store.call("setupFinish", ["value": .string(mode.rawValue)]) }
                })
            } else { ProgressView(AppCopy.text("读取清单设置…")) }
        }.miniNavigation(AppCopy.text("初次见面"), showsBack: false, background: .white).task {
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
            MPCard {
                VStack(spacing: 0) {
                    ForEach(InspectionMode.allCases, id: \.self) { mode in
                        HStack(spacing: 8) {
                            Button { editing = mode } label: {
                                AppText(mode.title).font(.system(size: 14, weight: .medium)).foregroundStyle(XJTheme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityIdentifier("templates.edit.\(mode.rawValue)")
                            Button { selected = mode } label: {
                                ZStack {
                                    Circle().fill(selected == mode ? XJTheme.primary : .white)
                                    Circle().strokeBorder(selected == mode ? XJTheme.primary : Color(white: 0.84), lineWidth: 1)
                                    if selected == mode { AppText("✓").font(.system(size: 16)).foregroundStyle(.white) }
                                }.frame(width: 24, height: 24).frame(width: 44, height: 44).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel(AppCopy.text(mode.title)).accessibilityIdentifier("setup.mode.\(mode.rawValue)")
                                .accessibilityAddTraits(selected == mode ? .isSelected : [])
                            AppText("›").font(.system(size: 24)).foregroundStyle(XJTheme.muted).onTapGesture { editing = mode }
                        }.overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
                    }
                }
            }.padding(16).padding(.bottom, 84)
        }.background(XJTheme.background).miniNavigation(AppCopy.text("模板"), leadingTitle: true, back: { if selected != original { leaving = true } else { dismiss() } })
            .overlay(alignment: .bottom) {
                Button(AppCopy.text("确定"), action: confirm).buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("templates.confirm")
                    .padding(.horizontal, 20).padding(.bottom, 16)
            }
            .overlay {
                if leaving { MPBottomSheet(close: { leaving = false }) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppText("要更换模板吗？").font(.system(size: 17, weight: .semibold))
                        Button(AppCopy.text("更换并退出"), action: confirm).buttonStyle(MPButtonStyle(kind: .primary))
                        Button(AppCopy.text("不更换并退出")) { dismiss() }.buttonStyle(MPButtonStyle())
                        Button(AppCopy.text("继续选择")) { leaving = false }.buttonStyle(MPButtonStyle()).accessibilityIdentifier("templates.stay")
                    }
                } }
            }
            // Capturing the whole parent also captures its changing dismiss environment.
            // Keep destination construction independent of that navigation context.
            .navigationDestination(item: $editing) { [workspace] mode in InspectionTemplatePage(workspace: workspace, mode: mode) }
            .onAppear {
                // Returning from an editor must not silently reset the user's radio selection.
                if !initialized {
                    let value = workspace.store.state["settings"]["selectedTemplate"].string
                    selected = InspectionMode(rawValue: value) ?? .detailed; original = selected; initialized = true
                }
            }
    }
    @State private var initialized = false
    private func confirm() {
        if workspace.perform({ try workspace.store.call("templateSelect", ["value": .string(selected.rawValue)]) }) { dismiss() }
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
        ScrollView { InspectionTemplateEditor(draft: $draft).padding(16).padding(.bottom, 84) }
            .background(XJTheme.background).miniNavigation(AppCopy.text(mode.title), leadingTitle: true, back: { if draft != original { leaving = true } else { dismiss() } })
            .interactiveDismissDisabled(draft != original)
            .safeAreaInset(edge: .bottom) { if !error.isEmpty { AppText(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger).padding(16).background(.white).accessibilityIdentifier("template.error") } }
            .overlay(alignment: .bottom) {
                Button(AppCopy.text("保存"), action: save).buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("template.save")
                    .padding(.horizontal, 20).padding(.bottom, 16)
            }
            .overlay {
                if leaving { MPBottomSheet(close: { leaving = false }) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppText("要保存修改吗？").font(.system(size: 17, weight: .semibold))
                        Button(AppCopy.text("保存并退出"), action: save).buttonStyle(MPButtonStyle(kind: .primary))
                        Button(AppCopy.text("不保存退出")) { dismiss() }.buttonStyle(MPButtonStyle())
                        Button(AppCopy.text("继续编辑")) { leaving = false }.buttonStyle(MPButtonStyle()).accessibilityIdentifier("template.stay")
                    }
                } }
            }.task {
                workspace.perform {
                    let modes = try workspace.store.call("templates")["modes"].array
                    draft = InspectionTemplateDraft(modes.first { $0.id == mode.rawValue }?["config"] ?? .null); original = draft
                }
            }
    }
    private func save() {
        do { try workspace.store.call("templateSave", ["value": .object(["mode": .string(mode.rawValue), "config": draft.json])]); dismiss() }
        catch { self.error = error.localizedDescription }
    }

}
