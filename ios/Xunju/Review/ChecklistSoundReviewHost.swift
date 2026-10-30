#if DEBUG
import SwiftUI

// Disposable real-store fixture. Calls the same choice adapters as the app;
// counters observe audio requests, not the device's speaker or Silent switch.
struct ChecklistSoundReviewHost: View {
    @State private var store: NativeStore?
    @State private var houseID = ""
    @State private var fields: [JSONValue] = []
    @State private var group: JSONValue = .null
    @State private var expanded = true
    @State private var readonly = false
    @State private var coordinator = MPSwipeCoordinator()
    @State private var positive = 0
    @State private var problem = 0
    @State private var error = ""

    var body: some View {
        VStack(spacing: 12) {
            Text("叮 \(positive) · 嘟嘟 \(problem)").accessibilityIdentifier("sound.counts")
            if store != nil {
                MPCard {
                    VStack(spacing: 0) {
                        groupRow
                        ForEach(fields) { field in
                            MPFieldRow(item: ChecklistPresentation.item(field), state: Binding(get: {
                                ChecklistPresentation.state(field)
                            }, set: { value in
                                perform {
                                    emit(try ChecklistPresentation.write(value, from: field, houseID: houseID, store: store!))
                                    try refresh()
                                }
                            }), readonly: readonly, coordinator: coordinator, note: {}, capture: {})
                        }
                    }
                }
                Button("恢复展示状态") {
                    perform {
                        try store!.answer(houseID, field: "f77_0", value: .string("是"))
                        try refresh()
                    }
                }.accessibilityIdentifier("sound.restore")
                Button(readonly ? "恢复编辑" : "切换只读") { readonly.toggle() }
                    .accessibilityIdentifier("sound.readonly")
                Text("就绪").accessibilityIdentifier("sound.ready")
            }
            if !error.isEmpty { Text(error).accessibilityIdentifier("sound.error") }
            Spacer()
        }.padding(16).task {
            guard store == nil else { return }
            perform {
                let root = FileManager.default.temporaryDirectory.appending(path: "sound-review-\(UUID().uuidString)")
                store = try NativeStore(directory: root)
                houseID = try store!.add("音效验收")
                try refresh()
            }
        }
    }
    private var groupRow: some View {
        let field = group["swipe"]
        return MPFieldRow(item: ChecklistPresentation.item(field), state: Binding(get: {
            var state = ChecklistPresentation.state(field); state.expanded = expanded; return state
        }, set: { state in
            perform {
                let old = ChecklistPresentation.state(field)
                if state.selected != old.selected {
                    emit(try ChecklistPresentation.writeGroup(group.id, operation: "result", value: state.selected.first ?? old.selected.first ?? "", houseID: houseID, store: store!))
                    try refresh()
                }
                expanded = state.expanded
            }
        }), readonly: readonly, coordinator: coordinator, note: {}, capture: {})
    }
    private func refresh() throws {
        guard let store else { return }
        fields = try [("f77_0", "冬季水管"), ("f21_1", "日照时段")].compactMap { id, query in
            try store.form(houseID, query: query).flatMap { $0["rows"].array }.first { $0.id == id }
        }
        group = try store.form(houseID, query: "窗户").flatMap { $0["rows"].array }.first { $0.id == "topic_37" } ?? .null
    }
    private func emit(_ sound: ChecklistSound?) {
        guard let sound else { return }
        sound.play()
        if sound == .problem { problem += 1 } else { positive += 1 }
    }
    private func perform(_ action: () throws -> Void) {
        do { try action() } catch { self.error = error.localizedDescription }
    }
}
#endif
