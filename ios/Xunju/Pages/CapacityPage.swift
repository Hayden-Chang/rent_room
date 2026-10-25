import SwiftUI

struct CapacityPage: View {
    let workspace: AppWorkspace
    var continued: ((JSONValue) -> Void)? = nil
    @State private var login = false
    @State private var thanking = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
            if continued != nil || thanking {
                Text(thanking ? "谢谢你的小饼干！" : "房源容量不够啦").font(.system(size: 24, weight: .bold))
                XiaodaMessage(text: thanking ? "谢谢主人，您现在多了 10 套房源额度啦！" : "主人，可以投喂我一个小饼干🍪吗？", pose: thanking ? "success" : "expect", compact: false) { EmptyView() }
            }
            CapacitySurface(used: workspace.store.capacity.used, limit: workspace.store.capacity.limit,
                authenticated: workspace.session != nil, price: workspace.billing.product?.displayPrice,
                activity: workspace.billing.activity, error: workspace.billing.error,
                purchase: { act(restore: false) }, restore: { act(restore: true) })
            Text("免费额度 \(workspace.capacityPolicy.freeLimit) 套；归档或删除房源可释放额度。已有超额房源仍可查看和编辑。")
                .font(.system(size: 13)).foregroundStyle(XJTheme.muted)
            NavigationLink("管理归档房源") { ArchivePage(workspace: workspace) }
            if continued != nil {
                Button(workspace.store.state["xiaoda"]["intent"]["kind"].string == "restore" ? "继续恢复房源" : "继续新建房源") {
                    workspace.perform { let result = try workspace.store.call("finishHouseAction"); continued?(result); dismiss() }
                }.buttonStyle(XJButtonStyle(primary: true)).disabled(workspace.store.capacity.remaining == 0)
                    .accessibilityIdentifier("capacity.continue")
            }
            }.padding(16).disabled(thanking)
        }.background(XJTheme.background).navigationTitle("房源容量").navigationBarTitleDisplayMode(.inline)
            .task {
                if !AppWorkspace.isBusinessTest { await workspace.refreshPolicy() }
                await workspace.billing.load()
                if !workspace.billing.activity.busy && workspace.billing.activity != .pending { resume() }
            }
            .task(id: thanking) {
                guard thanking else { return }
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                thanking = false; resume()
            }
            .toolbar { if continued != nil { ToolbarItem(placement: .cancellationAction) { Button("返回") { if workspace.perform({ try workspace.store.call("cancelHouseAction") }) { dismiss() } } } } }
            .sheet(isPresented: $login) { NavigationStack { SettingsPage(workspace: workspace).toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } } } }
    }
    private func resume() {
        guard continued != nil, workspace.store.capacity.remaining > 0, workspace.store.state["xiaoda"]["intent"] != .null else { return }
        workspace.perform { let result = try workspace.store.call("finishHouseAction"); continued?(result); dismiss() }
    }
    private func act(restore: Bool) {
        guard workspace.session != nil else { login = true; return }
        let store = workspace.store, previous = workspace.store.capacity.packs
        Task {
            if restore { await workspace.billing.restore() } else { await workspace.billing.purchase() }
            guard workspace.store === store, workspace.billing.activity != .pending, workspace.billing.error.isEmpty else { return }
            if store.capacity.packs > previous { thanking = true } else if restore { resume() }
        }
    }
}
