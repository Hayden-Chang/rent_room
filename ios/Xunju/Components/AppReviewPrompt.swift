import StoreKit
import SwiftUI

/// Business events only make a request eligible. Present at a quiet, visible
/// screen after navigation/payment finishes; StoreKit decides whether to show it.
struct AppReviewPrompt: ViewModifier {
    let workspace: AppWorkspace
    let ready: Bool
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    private var eligible: Bool {
        let progress = workspace.store.state["iosReview"]
        return !progress["requested"].bool && (progress["created"].int >= 3 || progress["purchased"].bool)
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
                if (try? store.call("reviewRequest"))?.bool == true { requestReview() }
            }
    }
}
