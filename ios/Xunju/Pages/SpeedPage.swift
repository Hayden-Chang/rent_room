import SwiftUI

struct SpeedPage: View {
    @State private var flow: SpeedFlow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    init(workspace: AppWorkspace, houseID: String) {
        let store = workspace.store
        var test = NativeSpeedTest(transport: NativeSpeedTransport()), network = NativeNetwork()
        #if DEBUG
        if let fixture = MeasurementNetworkFixture.make() { test = fixture.0; network = fixture.1 }
        #endif
        _flow = State(initialValue: SpeedFlow(session: SpeedSession(store: store, houseID: houseID, test: test, validScope: { workspace.store === store }), network: network))
    }
    var body: some View {
        ScrollView {
            SpeedStatusCard(state: flow.state, reading: flow.session.reading,
                            cancel: { flow.cancel(close: true) }, retry: { flow.start() }, save: { flow.save() })
                .padding(.horizontal, 16).padding(.top, 24)
        }.background(XJTheme.background).miniNavigation("网速测试")
            .background {
                SpeedNetworkConsent(request: flow.prompt) { id, accepted in flow.answer(id, accepted: accepted) }
                    .frame(width: 0, height: 0)
            }
            .task { flow.start() }
            .onChange(of: flow.closeRequested) { if flow.closeRequested { dismiss() } }
            .onChange(of: flow.network.current?.version) { if let version = flow.network.current?.version { flow.networkChanged(to: version) } }
            .onChange(of: scenePhase) { if scenePhase != .active { flow.cancel() } }
            .onDisappear { flow.cancel(leaving: true) }
    }
}
