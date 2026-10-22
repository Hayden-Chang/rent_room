#if DEBUG
import SwiftUI

/// Renders production rows from the bundled shared rules. Only this explicit
/// review route creates the disposable fixture; no user workspace is opened.
struct CorridorTitleReviewHost: View {
    @State private var rows: [JSONValue] = []
    @State private var heading = MPFieldState()
    @State private var coordinator = MPSwipeCoordinator()
    @State private var error = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if let group = rows.first(where: { $0.id == "topic_14" }) {
                        MPFieldRow(item: ChecklistPresentation.item(group["swipe"]), state: $heading,
                            coordinator: coordinator, note: {}, capture: {})
                        if heading.expanded {
                            ForEach(rows.filter { $0["kind"].string == "field" }, id: \.id) { field in
                                MPFieldRow(item: ChecklistPresentation.item(field),
                                    state: .constant(ChecklistPresentation.state(field)),
                                    coordinator: coordinator, note: {}, capture: {})
                                    .padding(.leading, ChecklistPresentation.indent(field))
                            }
                        }
                    } else if !error.isEmpty {
                        Text(error).accessibilityIdentifier("review.fixtureError")
                    } else { ProgressView() }
                }.padding(16).background(.white).clipShape(RoundedRectangle(cornerRadius: 16)).padding(16)
            }.background(XJTheme.background).navigationTitle("楼道标题组件")
                .navigationBarTitleDisplayMode(.inline)
        }.task {
            guard rows.isEmpty, error.isEmpty else { return }
            let root = FileManager.default.temporaryDirectory.appending(path: "corridor-review-\(UUID().uuidString)")
            defer { try? FileManager.default.removeItem(at: root) }
            do {
                let store = try NativeStore(directory: root)
                let id = try store.add("楼道标题组件")
                rows = try store.form(id, query: "楼道").flatMap { $0["rows"].array }
                if let group = rows.first(where: { $0.id == "topic_14" }) {
                    heading = ChecklistPresentation.state(group["swipe"])
                } else { error = "楼道分组缺失" }
            } catch { self.error = error.localizedDescription }
        }
    }
}
#endif
