import SwiftUI

struct FeedbackPage: View {
    let workspace: AppWorkspace
    let completed: () -> Void
    @State private var busy = false
    @State private var error = ""
    @State private var task: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    private let questions = [("ease", "操作是否方便？", ["方便", "一般", "不方便"]),
                             ("checklist", "检查项是否合理？", ["合理", "一般", "不合理"]),
                             ("functionality", "功能是否正常？", ["目前正常", "遇到问题"])]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    XiaodaMessage(text: "刚才用起来怎么样？说说你的感受吧！", pose: "greet") { EmptyView() }
                    ForEach(questions, id: \.0) { key, title, options in
                        Text(title).font(.system(size: 15, weight: .semibold))
                        ChoiceFlow {
                            ForEach(options, id: \.self) { option in
                                Button(option) { binding(key).wrappedValue = option }
                                    .buttonStyle(FilterChip(selected: binding(key).wrappedValue == option))
                                    .accessibilityIdentifier("feedback.\(key).\(option)")
                            }
                        }
                    }
                    Text("你的使用感受或想要的功能").font(.system(size: 15, weight: .semibold))
                    TextEditor(text: binding("message")).frame(minHeight: 120).padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(XJTheme.line)).accessibilityIdentifier("feedback.message")
                    if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger).accessibilityIdentifier("feedback.error") }
                    Button(busy ? "正在提交…" : "提交反馈", action: submit).buttonStyle(XJButtonStyle(primary: true)).accessibilityIdentifier("feedback.submit")
                    Button("先跳过", action: skip).frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("feedback.skip")
                }.padding(20).disabled(busy)
            }.navigationTitle("说说你的使用感受").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("关闭反馈", action: skip).disabled(busy) } }
        }.interactiveDismissDisabled(true).onDisappear { task?.cancel() }
    }
    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { workspace.store.state["xiaoda"]["feedbackDraft"][key].string }, set: { value in
            do {
                let draft = workspace.store.state["xiaoda"]["feedbackDraft"]
                let base = draft == .null ? JSONValue.object([:]) : draft
                try workspace.store.call("feedbackDraft", ["value": base.setting(key, to: .string(String(value.prefix(2000))))])
            } catch { self.error = error.localizedDescription }
        })
    }
    private func skip() {
        if workspace.perform({ try workspace.store.call("feedbackFinish", ["value": .string("skip")]) }) { dismiss() }
    }
    private func submit() {
        guard !busy else { return }
        busy = true; error = ""; let store = workspace.store
        task = Task { @MainActor in
            defer { busy = false }
            do {
                let request = try store.call("feedbackRequest")
                let receipt = try await NativeFeedback().submit(request)
                try Task.checkCancellation()
                guard workspace.store === store else { return }
                try store.call("feedbackFinish", ["value": .string(receipt)])
                completed(); dismiss()
            } catch is CancellationError {} catch { if workspace.store === store { self.error = error.localizedDescription } }
        }
    }
}
