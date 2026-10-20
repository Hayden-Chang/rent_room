import SwiftUI

struct CapacityPage: View {
    let workspace: AppWorkspace
    @State private var login = false
    var body: some View {
        ScrollView {
            CapacitySurface(used: workspace.store.capacity.used, limit: workspace.store.capacity.limit,
                authenticated: workspace.session != nil, price: workspace.billing.product?.displayPrice,
                activity: workspace.billing.activity, error: workspace.billing.error,
                purchase: { act(restore: false) }, restore: { act(restore: true) }).padding(16)
        }.background(XJTheme.background).navigationTitle("房源容量").navigationBarTitleDisplayMode(.inline)
            .task { await workspace.billing.load() }
            .sheet(isPresented: $login) { NavigationStack { SettingsPage(workspace: workspace).toolbar { ToolbarItem(placement: .cancellationAction) { CloseSheetButton() } } } }
    }
    private func act(restore: Bool) {
        guard workspace.session != nil else { login = true; return }
        Task { if restore { await workspace.billing.restore() } else { await workspace.billing.purchase() } }
    }
}
