import SwiftUI

struct ChecklistHeadingRow: View {
    enum Kind { case category, group }
    let id: String
    let title: String
    var kind: Kind = .group
    var done = 0
    var total = 0
    var issues = 0
    var options: [String] = []
    var choiceLabels: [String: String] = [:]
    var skippable = false
    var readonly = false
    var noteText = ""
    @Binding var expanded: Bool
    @Binding var skipped: Bool
    @Binding var value: String
    @Binding var flagged: Bool
    @Binding var activeRow: String?
    let note: () -> Void
    let capture: () -> Void
    private var actionsOpen: Bool { activeRow == id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if kind == .group { Rectangle().fill(XJTheme.line).frame(height: 1).padding(.bottom, 4) }
            HStack(spacing: 8) {
                Button {
                    if activeRow != nil { activeRow = nil } else { expanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 14, weight: .semibold)).multilineTextAlignment(.leading)
                        Text(expanded ? "⌃" : "⌄").font(.system(size: 13)).foregroundStyle(XJTheme.muted)
                        Spacer(minLength: 0)
                    }.frame(maxWidth: .infinity, minHeight: kind == .category ? 56 : 48).contentShape(Rectangle())
                }.buttonStyle(HeadingFoldButtonStyle()).accessibilityIdentifier("heading.\(id).fold")
                    .accessibilityValue(expanded ? "已展开" : "已折叠")
                if actionsOpen && !readonly {
                    HStack(spacing: 0) {
                        action("标记问题", icon: flagged ? "swipe-issue-active" : "swipe-issue", color: flagged ? XJTheme.danger : XJTheme.dangerBackground) { flagged.toggle() }
                        action("备注", icon: "swipe-note", color: XJTheme.soft, perform: note)
                        action("拍摄", icon: "swipe-camera", color: XJTheme.primary, perform: capture)
                    }.frame(height: kind == .category ? 56 : 48, alignment: .top)
                } else {
                    HStack(spacing: 4) {
                        if kind == .category {
                            (Text("\(done) / \(total)").foregroundStyle(XJTheme.muted) + Text(issues > 0 ? " · \(issues) 问题" : "").foregroundStyle(XJTheme.danger))
                                .font(.system(size: 12)).fixedSize().accessibilityIdentifier("heading.\(id).stats")
                        }
                        if skippable {
                            Button("不涉及") { if activeRow != nil { activeRow = nil } else { skipped.toggle() } }.font(.system(size: 12)).fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 10).frame(minHeight: 44)
                                .foregroundStyle(skipped ? XJTheme.primary : XJTheme.ink)
                                .background(skipped ? XJTheme.soft : XJTheme.background)
                                .clipShape(RoundedRectangle(cornerRadius: 6)).buttonStyle(.plain).disabled(readonly)
                                .accessibilityIdentifier("heading.\(id).skip").accessibilityAddTraits(skipped ? .isSelected : [])
                        }
                        if !skipped {
                            ForEach(options, id: \.self) { choice in
                                Button {
                                    if activeRow != nil { activeRow = nil } else { value = InspectionSelection.toggled(current: value, choice: choice) }
                                } label: {
                                    Text(choiceLabels[choice] ?? choice).font(.system(size: 13, weight: .semibold)).fixedSize()
                                        .padding(.horizontal, 10).frame(minWidth: 44, minHeight: 44)
                                        .foregroundStyle(value == choice ? XJTheme.primary : XJTheme.ink)
                                        .background(value == choice ? XJTheme.soft : XJTheme.background)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }.buttonStyle(.plain).disabled(readonly).accessibilityIdentifier("heading.\(id).choice.\(choice)")
                                    .accessibilityAddTraits(value == choice ? .isSelected : [])
                            }
                        }
                    }.fixedSize(horizontal: true, vertical: false)
                }
            }.contentShape(Rectangle()).simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { gesture in
                guard !readonly, abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    if gesture.translation.width < 0 { activeRow = id }
                    else if activeRow == id { activeRow = nil }
                }
            }).onLongPressGesture { if !readonly { activeRow = id } }
            if !noteText.isEmpty {
                Button { if activeRow != nil { activeRow = nil } else { note() } } label: { Text(noteText).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    .multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8) }
                    .buttonStyle(.plain).accessibilityIdentifier("heading.\(id).note")
            }
        }.padding(.vertical, 4).padding(.top, kind == .group ? 8 : 0)
            .padding(.horizontal, flagged ? 8 : 0).background(flagged ? XJTheme.dangerBackground : .clear)
            .clipShape(RoundedRectangle(cornerRadius: flagged ? 8 : 0)).foregroundStyle(flagged ? XJTheme.danger : XJTheme.ink)
            .accessibilityElement(children: .contain).accessibilityIdentifier("heading.\(id)")
            .onChange(of: readonly) { _, value in if value && activeRow == id { activeRow = nil } }
    }

    private func action(_ label: String, icon: String, color: Color, perform: @escaping () -> Void) -> some View {
        Button { activeRow = nil; perform() } label: { XJIcon(name: icon).frame(width: 44, height: 44).background(color) }
            .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier("heading.\(id).\(label)")
    }
}

// Let the title's tap and its enclosing horizontal drag compose explicitly,
// while retaining a real Button action for accessibility activation.
private struct HeadingFoldButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.contentShape(Rectangle()).onTapGesture { configuration.trigger() }
            .accessibilityAction { configuration.trigger() }
    }
}
