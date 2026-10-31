import SwiftUI

struct CapacityPage: View {
    let workspace: AppWorkspace
    var continued: ((JSONValue) -> Void)? = nil
    @State private var resuming = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            PropertyCreditsSurface(remaining: workspace.store.capacity.remaining,
                price: workspace.billing.product?.displayPrice,
                activity: workspace.billing.activity, error: AppCopy.text(workspace.billing.error),
                fromCreation: continued != nil && workspace.store.state["xiaoda"]["intent"]["kind"].string == "create",
                purchase: { act(restore: false) }, restore: { act(restore: true) })
                .padding(20).frame(maxWidth: .infinity)
        }.background(.white).miniNavigation(AppCopy.text("房源点数"), background: .white, back: {
            if continued == nil || workspace.perform({ try workspace.store.call("cancelHouseAction") }) { dismiss() }
        })
            .task {
                workspace.billing.start()
                await workspace.billing.load()
                resume()
            }
            .onChange(of: workspace.billing.activity) { _, _ in resume() }
            .onDisappear { workspace.billing.stop() }
            .modifier(AppReviewPrompt(workspace: workspace, ready: continued == nil
                && workspace.billing.activity == .idle && workspace.billing.error.isEmpty))
    }
    private func resume() {
        guard !resuming, continued != nil, workspace.billing.activity == .idle, workspace.billing.error.isEmpty,
              workspace.store.capacity.remaining > 0, workspace.store.state["xiaoda"]["intent"] != .null else { return }
        resuming = true
        if !workspace.perform({ let result = try workspace.store.call("finishHouseAction"); continued?(result); dismiss() }) { resuming = false }
    }
    private func act(restore: Bool) {
        Task {
            if restore { await workspace.billing.restore() } else { await workspace.billing.purchase() }
        }
    }
}
