#if DEBUG
import SwiftUI

/// Disposable review route; production startup still leaves examples disabled.
struct ExampleHousesReviewHost: View {
    @State private var workspace: AppWorkspace?
    @State private var tab = "房源"
    @State private var error = ""
    var body: some View {
        NavigationStack {
            Group {
                if let workspace {
                    if tab == "对比" { ComparisonPage(workspace: workspace) }
                    else { HomePage(workspace: workspace) }
                } else { Text(error) }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                XJTabBar(selection: $tab, items: [("房源", "home"), ("对比", "compare")])
            }
            .background(XJTheme.background)
        }
        .task {
            guard workspace == nil else { return }
            do {
                let args = ProcessInfo.processInfo.arguments
                guard let index = args.firstIndex(of: "--example-review-id"), args.indices.contains(index + 1), let id = UUID(uuidString: args[index + 1]) else { return }
                let root = FileManager.default.temporaryDirectory.appending(path: "XunjuExampleReview/\(id.uuidString)")
                workspace = try AppWorkspace(root: root, keychain: VolatileSessionStorage(), firstVisitExamples: true)
            } catch { self.error = error.localizedDescription }
        }
    }
}
#endif
