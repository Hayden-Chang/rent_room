import StoreKit
import SwiftUI

/// Business events only make a request eligible. Present at a quiet, visible
/// screen after navigation/payment finishes; StoreKit decides whether to show it.
struct AppReviewPrompt: ViewModifier {
    let workspace: AppWorkspace
    let ready: Bool
    var includeFilledItems = false
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    private var eligible: Bool {
        Self.isEligible(store: workspace.store, includeFilledItems: includeFilledItems)
    }
    static func isEligible(store: NativeStore, includeFilledItems: Bool) -> Bool {
        let progress = store.state["iosReview"]
        guard !progress["requested"].bool else { return false }
        if progress["created"].int >= 3 || progress["purchased"].bool { return true }
        guard includeFilledItems else { return false }
        let examples = Set(store.state["houses"].array.filter { $0["example"].bool }.map(\.id))
        return store.houses.filter { !examples.contains($0.id) }.reduce(0) { $0 + $1.stats.done } > 50
    }
    private var canRequest: Bool {
        visible && ready && eligible && scenePhase == .active && workspace.error.isEmpty
            && !workspace.store.status.blocked && workspace.store.status.error.isEmpty
    }
    func body(content: Content) -> some View {
        content.onAppear { visible = true }.onDisappear { visible = false }
            .task(id: "\(workspace.identityRevision)-\(canRequest)") {
                guard canRequest else { return }
                let store = workspace.store
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard !Task.isCancelled, canRequest, workspace.store === store else { return }
                // Persist before calling: there is no display/completion callback.
                if (try? store.call("reviewRequest", ["value": .bool(includeFilledItems)]))?.bool == true {
                    #if DEBUG
                    // Business UI tests retain eligibility/persistence while isolating
                    // the external StoreKit rating window, like their payment service.
                    if CapacityBusinessFixture.suppressesSystemReview() || ReturningBusinessFixture.suppressesSystemReview() { return }
                    #endif
                    requestReview()
                }
            }
    }
}
