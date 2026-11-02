#if DEBUG
import SwiftUI

// Isolated production rows with disposable notes; no persisted house data.
struct ChecklistNoteReviewHost: View {
    @State private var coordinator = MPSwipeCoordinator()
    @State private var category = MPFieldState(note: "分类备注：雨天再来看一次", expanded: true)
    @State private var group = MPFieldState(note: "分组备注：重点检查窗框边缘", expanded: true)
    @State private var normal = MPFieldState(note: "普通备注：下午采光比较好", selected: ["是"])
    @State private var flagged = MPFieldState(note: "问题备注：窗框有水渍，需要复查", selected: ["否"], flagged: true)
    @State private var readonly = MPFieldState(note: "只读备注：原有记录继续保留", selected: ["有"])
    @State private var empty = MPFieldState()

    var body: some View {
        ScrollView {
            MPCard {
                VStack(spacing: 0) {
                    row(MPFieldItem(id: "note-category", title: "门窗与采光", kind: .category, stats: "3 / 4"), state: $category)
                    row(MPFieldItem(id: "note-group", title: "窗户", kind: .group), state: $group)
                    row(MPFieldItem(id: "note-normal", title: "采光充足", options: ["是", "否"]), state: $normal)
                    row(MPFieldItem(id: "note-flagged", title: "窗户密封", options: ["是", "否"]), state: $flagged)
                    row(MPFieldItem(id: "note-readonly", title: "纱窗（只读）", options: ["有", "无"]), state: $readonly, readonly: true)
                    row(MPFieldItem(id: "note-empty", title: "未添加备注", options: ["有", "无"]), state: $empty)
                }
            }.padding(16)
        }
    }

    private func row(_ item: MPFieldItem, state: Binding<MPFieldState>, readonly: Bool = false) -> some View {
        MPFieldRow(item: item, state: state, readonly: readonly, coordinator: coordinator, note: {}, capture: {})
    }
}
#endif
