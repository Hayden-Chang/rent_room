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
    @State private var keyboardHeight: CGFloat = 0
    var body: some View {
        GeometryReader { geometry in
            MPBottomSheet(cornerRadius: 28, bottomPadding: 20 + (keyboardHeight == 0 ? geometry.safeAreaInsets.bottom : 0), close: {}) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("说说你的使用感受").font(.system(size: 22, weight: .bold)).foregroundStyle(Color(red: 48/255, green: 57/255, blue: 76/255)).frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: skip) { Image(systemName: "xmark").font(.system(size: 17)).foregroundStyle(XJTheme.muted).frame(width: 44, height: 44) }
                            .buttonStyle(.plain).accessibilityLabel("关闭反馈").offset(x: 10, y: -10)
                    }.frame(height: 31, alignment: .top).padding(.bottom, 20)
                    XiaodaMessage(text: "刚才用起来怎么样？说说你的感受吧！", pose: "greet", compact: false) { EmptyView() }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(questions, id: \.0) { key, title, options in
                                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 64/255, green: 73/255, blue: 93/255)).padding(.top, 16).padding(.bottom, 10)
                                ChoiceFlow {
                                    ForEach(options, id: \.self) { option in
                                        let chosen = binding(key).wrappedValue == option
                                        Button { binding(key).wrappedValue = option } label: {
                                            HStack(spacing: 4) {
                                                ZStack {
                                                    Circle().fill(chosen ? XJTheme.primary : .white)
                                                    Circle().strokeBorder(chosen ? XJTheme.primary : Color(white: 0.84))
                                                    if chosen { Text("✓").font(.system(size: 13)).foregroundStyle(.white) }
                                                }.frame(width: 18, height: 18)
                                                Text(option).font(.system(size: 13))
                                            }.padding(.horizontal, 10).frame(minHeight: 44)
                                                .foregroundStyle(chosen ? Color(red: 82/255, green: 80/255, blue: 220/255) : XJTheme.ink)
                                                .background(chosen ? SetupStyle.soft : .white, in: RoundedRectangle(cornerRadius: 12))
                                                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(chosen ? SetupStyle.purple : SetupStyle.border, lineWidth: 2))
                                        }.buttonStyle(.plain).accessibilityIdentifier("feedback.\(key).\(option)")
                                            .accessibilityAddTraits(chosen ? .isSelected : [])
                                    }
                                }
                            }
                            Text("你的使用感受或想要的功能").font(.system(size: 15, weight: .semibold)).padding(.top, 16).padding(.bottom, 8)
                            ZStack(alignment: .topLeading) {
                                if binding("message").wrappedValue.isEmpty { Text("哪里不好用，或者希望增加什么功能？").font(.system(size: 14)).foregroundStyle(XJTheme.muted).padding(12).allowsHitTesting(false) }
                                TextEditor(text: binding("message")).font(.system(size: 14)).scrollContentBackground(.hidden).padding(7).accessibilityIdentifier("feedback.message")
                            }.frame(height: 100).background(Color(red: 248/255, green: 249/255, blue: 252/255), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(SetupStyle.border, lineWidth: 2))
                        }.padding(.bottom, 8)
                    }.frame(height: max(110, min(geometry.size.height * 0.44, geometry.size.height - keyboardHeight - 300)))
                        .padding(.top, 8).padding(.bottom, 16).scrollDismissesKeyboard(.interactively)
                    if !error.isEmpty { Text(error).font(.system(size: 13)).foregroundStyle(XJTheme.danger).padding(.bottom, 12).accessibilityIdentifier("feedback.error") }
                    GeometryReader { actions in
                        HStack(spacing: 12) {
                            Button("先跳过", action: skip).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(red: 85/255, green: 91/255, blue: 193/255))
                                .frame(width: (actions.size.width - 12) / 3, height: 48).accessibilityIdentifier("feedback.skip")
                            Button(busy ? "正在提交…" : "提交反馈", action: submit).buttonStyle(SetupButtonStyle()).accessibilityIdentifier("feedback.submit")
                        }
                    }.frame(height: 50)
                }.disabled(busy)
            }
        }.interactiveDismissDisabled(true).onDisappear { task?.cancel() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
                let screen = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen.bounds ?? .zero
                keyboardHeight = max(0, screen.maxY - frame.minY)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardHeight = 0 }
    }
    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { workspace.store.state["xiaoda"]["feedbackDraft"][key].string }, set: { value in
            do {
                let draft = workspace.store.state["xiaoda"]["feedbackDraft"]
                let base = draft == .null ? JSONValue.object([:]) : draft
                try workspace.store.call("feedbackDraft", ["value": base.setting(key, to: .string(String(value.prefix(2000))))])
                if !workspace.store.status.error.isEmpty { throw CoreFailure(message: workspace.store.status.error) }
            } catch { self.error = error.localizedDescription }
        })
    }
    private func skip() {
        do { try workspace.store.call("feedbackFinish", ["value": .string("skip")]); dismiss() }
        catch { self.error = error.localizedDescription }
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
