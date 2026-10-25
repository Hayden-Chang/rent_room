import SwiftUI

struct CapacityPage: View {
    let workspace: AppWorkspace
    var continued: ((JSONValue) -> Void)? = nil
    @State private var login = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
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
            }.padding(16)
        }.background(XJTheme.background).navigationTitle("房源容量").navigationBarTitleDisplayMode(.inline)
            .task { if !AppWorkspace.isBusinessTest { await workspace.refreshPolicy() }; await workspace.billing.load() }
            .toolbar { if continued != nil { ToolbarItem(placement: .cancellationAction) { Button("返回") { dismiss() } } } }
            .sheet(isPresented: $login) { NavigationStack { SettingsPage(workspace: workspace).toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } } } }
    }
    private func act(restore: Bool) {
        guard workspace.session != nil else { login = true; return }
        Task { if restore { await workspace.billing.restore() } else { await workspace.billing.purchase() } }
    }
}
