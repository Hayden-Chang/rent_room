import SwiftUI

struct SettingsPage: View {
    let workspace: AppWorkspace
    var showsBack = false
    var imported: () -> Void = {}
    @State private var destination: LocalSettingsAction?
    @State private var feedback = false
    @State private var sharing = false
    @Environment(\.openURL) private var openURL
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SaveBanner(workspace: workspace)
                RegionalSettingsSection(preferences: workspace.regional.preferences,
                    chooseLanguage: { destination = .language }, chooseCurrency: { destination = .currency })
                LocalSettingsSurface(remaining: workspace.store.capacity.remaining,
                    archived: workspace.store.archivedHouses.count, workplace: workspace.store.state["settings"]["workplace"].string,
                    version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
                    onboarding: Binding(get: { workspace.store.state["xiaoda"]["enabled"].bool }, set: { value in
                        workspace.perform { try workspace.store.call("settings", ["property": .string("onboarding"), "value": .bool(value)]) }
                    }), action: act, openLegal: { openURL($0.url) })
            }.padding(16)
        }.miniNavigation(AppCopy.text("我的"), showsBack: showsBack)
            .navigationDestination(item: $destination) { action in
                switch action {
                case .language:
                    LanguageSelectionSurface(selection: workspace.regional.preferences.language, select: workspace.regional.selectLanguage)
                        .miniNavigation(RegionalCopy.text("settings.language", language: workspace.regional.language))
                case .currency:
                    CurrencySelectionSurface(preferences: workspace.regional.preferences, select: workspace.currencyLocation.chooseCurrency)
                        .miniNavigation(RegionalCopy.text("settings.currency", language: workspace.regional.language))
                case .capacity: CapacityPage(workspace: workspace)
                case .workplace: WorkplacePage(workspace: workspace)
                case .archive: ArchivePage(workspace: workspace)
                case .templates: InspectionTemplatesPage(workspace: workspace)
                case .importFile: BackupPage(workspace: workspace, importing: true, imported: imported)
                case .export: BackupPage(workspace: workspace)
                default: EmptyView()
                }
            }
            .fullScreenCover(isPresented: $feedback) { FeedbackPage(workspace: workspace, completed: {}).presentationBackground(.clear) }
            .sheet(isPresented: $sharing) {
                if let cover = AppCopy.shareCoverURL {
                    LocalShareSheet(items: [cover])
                }
            }
    }
    private func act(_ action: LocalSettingsAction) {
        switch action {
        case .permissions: if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        case .feedback: feedback = true
        case .share: sharing = true
        default: destination = action
        }
    }
}
private struct LocalShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct CloseSheetButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button(AppCopy.text("关闭")) { dismiss() } }
}
