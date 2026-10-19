import SwiftUI

enum InspectionSelection {
    static func toggled(current: String, choice: String) -> String {
        current == choice ? "" : choice
    }
}

struct InspectionChoiceRow: View {
    let title: String
    let options: [String]
    @Binding var value: String
    @Binding var flagged: Bool
    var readonly = false
    var note: () -> Void
    var capture: () -> Void
    @State private var actionsOpen = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 13)).frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                if actionsOpen && !readonly {
                    HStack(spacing: 0) {
                        action("标记问题", icon: flagged ? "swipe-issue-active" : "swipe-issue",
                               background: flagged ? XJTheme.danger : XJTheme.dangerBackground) {
                            flagged.toggle()
                        }
                        action("备注", icon: "swipe-note", background: XJTheme.soft, action: note)
                        action("拍摄", icon: "swipe-camera", background: XJTheme.primary, action: capture)
                    }
                } else {
                    HStack(spacing: 4) {
                        ForEach(options, id: \.self) { choice in
                            Button {
                                value = InspectionSelection.toggled(current: value, choice: choice)
                            } label: {
                                Text(choice).font(.system(size: 13)).padding(.horizontal, 10)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .foregroundStyle(value == choice ? XJTheme.primary : XJTheme.ink)
                                    .background(value == choice ? XJTheme.soft : XJTheme.background)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain).disabled(readonly)
                                .accessibilityIdentifier("choice.\(title).\(choice)")
                                .accessibilityAddTraits(value == choice ? .isSelected : [])
                        }
                    }
                }
            }.frame(minHeight: 44).contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { gesture in
                    guard !readonly, abs(gesture.translation.width) > abs(gesture.translation.height) else { return }
                    withAnimation(.easeOut(duration: 0.18)) { actionsOpen = gesture.translation.width < 0 }
                })
                .onLongPressGesture { if !readonly { actionsOpen = true } }
            Rectangle().fill(XJTheme.line).frame(height: 1)
        }.padding(.vertical, 2).padding(.horizontal, flagged ? 8 : 0)
            .background(flagged ? XJTheme.dangerBackground : .clear)
            .clipShape(RoundedRectangle(cornerRadius: flagged ? 8 : 0))
            .foregroundStyle(flagged ? XJTheme.danger : XJTheme.ink)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("row.\(title)")
    }

    private func action(_ label: String, icon: String, background: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { XJIcon(name: icon).frame(width: 44, height: 44).background(background) }
            .buttonStyle(.plain).accessibilityLabel(label).accessibilityIdentifier("row.\(title).\(label)")
    }
}

struct ChecklistDisclosure<Content: View>: View {
    let title: String
    let progress: String
    @Binding var expanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        XJCard {
            VStack(spacing: 0) {
                Button { expanded.toggle() } label: {
                    HStack(spacing: 8) {
                        Text(title).font(.system(size: 14, weight: .semibold))
                        Text(expanded ? "⌃" : "⌄").font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                        Spacer()
                        Text(progress).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    }.frame(minHeight: 56).foregroundStyle(XJTheme.ink).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("group.\(title)")
                if expanded { content }
            }
        }
    }
}
