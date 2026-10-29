import SwiftUI

// Independently reviewable counterparts of the current mini-program UI.
// Their callers own navigation and persistence; these surfaces perform no I/O.
struct MPButtonStyle: ButtonStyle {
    enum Kind { case primary, soft, plain, danger }
    var kind: Kind = .plain
    var transferDisabled = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(transferDisabled && !enabled ? Color(red: 108/255, green: 116/255, blue: 169/255) : kind == .primary ? .white : kind == .danger ? XJTheme.danger : kind == .soft ? XJTheme.primary : XJTheme.ink)
            .background(transferDisabled && !enabled ? Color(red: 228/255, green: 231/255, blue: 250/255) : kind == .primary ? XJTheme.primary : kind == .soft ? XJTheme.soft : kind == .danger ? XJTheme.dangerBackground : .white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : transferDisabled ? 1 : 0.45)
    }
}

struct MPHeader: View {
    let title: String
    var back: (() -> Void)? = nil
    var body: some View {
        ZStack {
            Text(title).font(.system(size: 17, weight: .semibold)).lineLimit(1).padding(.horizontal, 66)
            HStack {
                if let back {
                    Button(action: back) { Image(systemName: "chevron.left").font(.system(size: 20)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                        .buttonStyle(.plain).accessibilityLabel("返回").accessibilityIdentifier("mp.back")
                }
                Spacer()
            }
        }.frame(height: 44).foregroundStyle(XJTheme.ink).background(XJTheme.background)
    }
}

struct MPFrame<Content: View, Footer: View>: View {
    let title: String
    var back: (() -> Void)? = nil
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer
    var body: some View {
        VStack(spacing: 0) {
            MPHeader(title: title, back: back)
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }.background(XJTheme.background).foregroundStyle(XJTheme.ink)
    }
}

struct MPCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View { content.padding(padding).frame(maxWidth: .infinity, alignment: .leading).background(.white).clipShape(RoundedRectangle(cornerRadius: 16)) }
}

struct MPMenuRow: View {
    let title: String
    var detail = ""
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title).fontWeight(.medium).fixedSize()
                Spacer(minLength: 0)
                Text(detail + (detail.isEmpty ? "›" : " ›")).font(.system(size: 12)).foregroundStyle(XJTheme.muted).lineLimit(1)
            }.font(.system(size: 14)).frame(minHeight: 49).contentShape(Rectangle())
        }.buttonStyle(.plain).overlay(alignment: .bottom) { XJTheme.line.frame(height: 1) }
    }
}

struct MPCheckbox: View {
    let selected: Bool
    var body: some View {
        Text(selected ? "✓" : "").font(.system(size: 15)).foregroundStyle(.white).frame(width: 22, height: 22)
            .background(selected ? XJTheme.primary : .white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(selected ? XJTheme.primary : XJTheme.line))
            .accessibilityHidden(true)
    }
}

struct MPFloatingButton: View {
    let icon: String, label: String
    var size: CGFloat = 52
    let action: () -> Void
    var body: some View {
        Button(action: action) { XJIcon(name: icon).frame(width: size, height: size).background(.white)
            .clipShape(Circle()).overlay(Circle().strokeBorder(XJTheme.line)).shadow(color: XJTheme.ink.opacity(0.10), radius: 6, y: 3) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct MPTabBar: View {
    @Binding var selection: String
    var detail = false
    var mediaCount = 0, issueCount = 0
    private var items: [(String, String)] { detail ? [("清单", "checklist"), ("影像", "media"), ("问题", "issues"), ("总结", "summary")] : [("房源", "home"), ("对比", "compare"), ("我的", "settings")] }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { title, icon in
                Button { selection = title } label: {
                    VStack(spacing: detail ? 1 : 3) {
                        XJIcon(name: icon + (selection == title ? "-selected" : "-default"))
                        Text(title + (detail && title == "影像" ? " \(mediaCount)" : detail && title == "问题" ? " \(issueCount)" : ""))
                            .font(.system(size: detail ? 13 : 10, weight: detail ? .medium : .regular))
                    }.frame(maxWidth: .infinity, minHeight: detail ? 48 : 50).contentShape(Rectangle())
                        .foregroundStyle(selection == title ? XJTheme.primary : Color(red: 141/255, green: 149/255, blue: 163/255))
                }.buttonStyle(MPStaticButtonStyle()).accessibilityIdentifier("mp.tab.\(title)").accessibilityAddTraits(selection == title ? .isSelected : [])
            }
        }.background(.white).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }
    }
}

struct MPInputDialog: View {
    let title: String, placeholder: String
    @Binding var text: String
    var error = ""
    let cancel: () -> Void, save: () -> Void
    var body: some View {
        ZStack {
            XJTheme.ink.opacity(0.38).ignoresSafeArea()
            VStack(spacing: 0) {
                Text(title).font(.system(size: 17, weight: .semibold)).padding(.top, 24).padding(.bottom, 20)
                TextField(placeholder, text: $text).font(.system(size: 14)).padding(12).background(XJTheme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 6)).padding(.horizontal, 24).accessibilityIdentifier("mp.prompt.text")
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(XJTheme.danger).padding(12) }
                HStack(spacing: 0) {
                    Button("取消", action: cancel).foregroundStyle(XJTheme.muted).frame(maxWidth: .infinity, minHeight: 52)
                    XJTheme.line.frame(width: 1, height: 52)
                    Button("保存", action: save).foregroundStyle(XJTheme.primary).frame(maxWidth: .infinity, minHeight: 52).accessibilityIdentifier("mp.prompt.save")
                }.font(.system(size: 16, weight: .medium)).overlay(alignment: .top) { XJTheme.line.frame(height: 1) }.padding(.top, 24)
            }.background(.white).clipShape(RoundedRectangle(cornerRadius: 12)).padding(.horizontal, 40)
        }.accessibilityElement(children: .contain)
    }
}

struct MPBottomSheet<Content: View>: View {
    var cornerRadius: CGFloat = 20
    var topPadding: CGFloat = 24
    var bottomPadding: CGFloat = 24
    let close: () -> Void
    @ViewBuilder var content: Content
    @State private var keyboardHeight: CGFloat = 0
    var body: some View {
        ZStack(alignment: .bottom) {
            XJTheme.ink.opacity(0.38).ignoresSafeArea().onTapGesture(perform: close)
            content.padding(.horizontal, 20).padding(.top, topPadding).padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity).background(.white)
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius))
                .padding(.bottom, keyboardHeight)
        }.ignoresSafeArea(.container, edges: .bottom).ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? .zero
            let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
            let intersection = window.map { $0.bounds.intersection($0.convert(frame, from: nil)) } ?? .null
            withAnimation(.easeOut(duration: 0.2)) { keyboardHeight = intersection.isNull ? 0 : max(0, intersection.height) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardHeight = 0 }
        }
    }
}

struct MPNoteSheet: View {
    let title: String
    @Binding var text: String
    var readonly = false, error = ""
    let close: () -> Void, save: () -> Void
    private var bottomInset: CGFloat {
        let window = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }
        return max(8, window?.safeAreaInsets.bottom ?? 0)
    }
    var body: some View {
        MPBottomSheet(topPadding: 12, bottomPadding: bottomInset, close: close) {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.system(size: 17, weight: .semibold)).frame(minHeight: 25.5)
                TextEditor(text: $text).font(.system(size: 14)).frame(height: 136).scrollContentBackground(.hidden)
                    .padding(12).background(XJTheme.background).clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(readonly).accessibilityIdentifier("mp.note.text")
                    .onChange(of: text) { if text.count > 10000 { text = String(text.prefix(10000)) } }
                if !error.isEmpty { Text(error).font(.system(size: 12)).foregroundStyle(XJTheme.danger) }
                HStack(spacing: 8) {
                    Button(readonly ? "关闭" : "取消", action: close).buttonStyle(MPButtonStyle())
                    if !readonly { Button("保存备注", action: save).buttonStyle(MPButtonStyle(kind: .primary)).accessibilityIdentifier("mp.note.save") }
                }
            }
        }
    }
}

// Detail tabs use hover-class="none" in the mini-program.
struct MPStaticButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}
