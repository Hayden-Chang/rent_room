import SwiftUI

struct CapacityPage: View {
    let workspace: AppWorkspace
    var continued: ((JSONValue) -> Void)? = nil
    @Environment(\.openURL) private var openURL
    @State private var thanking = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
            if !workspace.billing.activity.busy || thanking {
                Text(thanking ? "谢谢你的小饼干！" : "房源容量不够啦").font(.system(size: 24, weight: .bold)).foregroundStyle(Color(red: 38/255, green: 48/255, blue: 71/255))
                    .frame(maxWidth: .infinity).frame(height: 33.6).padding(.top, 8).padding(.bottom, 24).accessibilityIdentifier("capacity.title")
                XiaodaMessage(text: thanking ? "谢谢主人，您现在多了 10 套房源额度啦！" : "主人，可以投喂我一个小饼干🍪吗？", pose: thanking ? "success" : "expect", compact: false, hero: true) { EmptyView() }
            }
            AccountFreeCapacitySurface(used: workspace.store.capacity.used, limit: workspace.store.capacity.limit,
                price: workspace.billing.product?.displayPrice,
                activity: workspace.billing.activity, error: workspace.billing.error,
                purchase: { act(restore: false) }, restore: { act(restore: true) }, cancel: {
                    if continued != nil { workspace.perform { try workspace.store.call("cancelHouseAction") } }; dismiss()
                }, openLegal: { openURL($0.url) })
            if continued != nil {
                Button(workspace.store.state["xiaoda"]["intent"]["kind"].string == "restore" ? "继续恢复房源" : "继续新建房源") {
                    workspace.perform { let result = try workspace.store.call("finishHouseAction"); continued?(result); dismiss() }
                }.buttonStyle(XJButtonStyle(primary: true)).disabled(workspace.store.capacity.remaining == 0)
                    .accessibilityIdentifier("capacity.continue")
            }
            }.padding(.horizontal, 20).padding(.vertical, 24).disabled(thanking)
        }.background(.white).miniNavigation("房源容量", background: .white, back: { if continued == nil || workspace.perform({ try workspace.store.call("cancelHouseAction") }) { dismiss() } })
            .task {
                workspace.billing.start()
                await workspace.billing.load()
                if !workspace.billing.activity.busy && workspace.billing.activity != .pending { resume() }
            }
            .task(id: thanking) {
                guard thanking else { return }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                thanking = false; resume()
            }
            .onDisappear { workspace.billing.stop() }
    }
    private func resume() {
        guard continued != nil, workspace.store.capacity.remaining > 0, workspace.store.state["xiaoda"]["intent"] != .null else { return }
        workspace.perform { let result = try workspace.store.call("finishHouseAction"); continued?(result); dismiss() }
    }
    private func act(restore: Bool) {
        let store = workspace.store, previous = workspace.store.capacity.packs
        Task {
            if restore { await workspace.billing.restore() } else { await workspace.billing.purchase() }
            guard workspace.store === store, workspace.billing.activity != .pending, workspace.billing.error.isEmpty else { return }
            if store.capacity.packs > previous { thanking = true } else if restore { resume() }
        }
    }
}
