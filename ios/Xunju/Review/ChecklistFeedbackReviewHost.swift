#if DEBUG
import SwiftUI

// Explicit component-review route only. Uses production rows and haptic output;
// the counters observe requested feedback, not physical vibration on a device.
struct ChecklistFeedbackReviewHost: View {
    @State private var coordinator = MPSwipeCoordinator()
    @State private var group = MPFieldState()
    @State private var single = MPFieldState(note: "保留备注", flagged: true)
    @State private var multiple = MPFieldState()
    @State private var cost = MPFieldState(text: "3200")
    @State private var fixed = MPFieldState()
    @State private var readonly = false
    @State private var selections = 0
    @State private var disclosures = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("选择 \(selections) · 展开折叠 \(disclosures)")
                .accessibilityIdentifier("feedback.counts")
            MPCard {
                VStack(spacing: 0) {
                    row(MPFieldItem(id: "parent", title: "门窗", kind: .group, options: ["有", "无"], skippable: true), state: $group)
                    if group.expanded && !group.skipped {
                        row(MPFieldItem(id: "single", title: "窗户密封", options: ["是", "否"]), state: $single)
                    }
                    row(MPFieldItem(id: "multiple", title: "网络", options: ["联通", "移动"], multiple: true), state: $multiple)
                    row(MPFieldItem(id: "cost", title: "月租金", kind: .number, allowsNone: true), state: $cost)
                    row(MPFieldItem(id: "fixed", title: "不可折叠标题", kind: .group, collapsible: false), state: $fixed)
                }
            }
            Button(readonly ? "恢复编辑" : "切换只读") { readonly.toggle() }
                .accessibilityIdentifier("feedback.readonly")
            Button("恢复展示状态") {
                group.expanded = true
                single.selected = ["是"]
            }.accessibilityIdentifier("feedback.restore")
            Spacer()
        }.padding(16)
    }

    private func row(_ item: MPFieldItem, state: Binding<MPFieldState>) -> some View {
        MPFieldRow(item: item, state: state, readonly: readonly, coordinator: coordinator, note: {}, capture: {}, feedback: { event in
            event.play()
            switch event {
            case .selection: selections += 1
            case .disclosure: disclosures += 1
            }
        })
    }
}
#endif
