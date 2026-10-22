#if DEBUG
import SwiftUI

// Uses the production field, presenter and store in a disposable review directory.
// No identity services, page integration or user records are involved.
struct TopFloorReviewHost: View {
    @State private var store: NativeStore?
    @State private var error = ""
    @State private var coordinator = MPSwipeCoordinator()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let store, let house = store.houses.first {
                        let field = (try? store.form(house.id, query: "顶楼"))?
                            .flatMap { $0["rows"].array }.first { $0.id == "f1_top" } ?? .null
                        XJCard {
                            MPFieldRow(item: ChecklistPresentation.item(field), state: Binding(
                                get: { ChecklistPresentation.state(field) },
                                set: { value in
                                    do { try ChecklistPresentation.write(value, from: field, houseID: house.id, store: store) }
                                    catch { self.error = error.localizedDescription }
                                }), coordinator: coordinator, note: {}, capture: {})
                        }
                        Text("异常项：\(house.stats.issues)").foregroundStyle(XJTheme.muted)
                            .accessibilityIdentifier("review.topFloor.issues")
                    }
                    if !error.isEmpty { Text(error).accessibilityIdentifier("review.topFloor.error") }
                }.padding(16)
            }.background(XJTheme.background)
                .navigationTitle("房源基本信息").navigationBarTitleDisplayMode(.inline)
        }.task {
            guard store == nil else { return }
            do {
                let args = ProcessInfo.processInfo.arguments
                let index = args.firstIndex(of: "--top-floor-review-id")
                let id = index.flatMap { args.indices.contains($0 + 1) ? UUID(uuidString: args[$0 + 1]) : nil } ?? UUID()
                let directory = FileManager.default.temporaryDirectory.appending(path: "XunjuTopFloorReview/\(id.uuidString)")
                let value = try NativeStore(directory: directory)
                if value.houses.isEmpty {
                    let house = try value.add("顶楼检查")
                    try value.answer(house, field: "f1_top", property: "note", value: .string("已确认楼层与隔热情况"))
                }
                store = value
            } catch { self.error = error.localizedDescription }
        }
    }
}
#endif
