#if DEBUG
import SwiftUI

/// Explicit opt-in, isolated preferences and simulated country resolution.
/// Never requests GPS, modifies a house, or changes normal app startup.
struct RegionalSettingsReviewHost: View {
    @State private var model: RegionalSettingsModel
    @State private var page = "settings"
    @State private var prompt = false
    @State private var message = ""

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let runIndex = arguments.firstIndex(of: "--regional-review-id")
        let runID = runIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? UUID().uuidString
        let defaults = UserDefaults(suiteName: "regional-review.\(runID)")!
        _model = State(initialValue: RegionalSettingsModel(defaults: defaults))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch page {
                case "language": LanguageSelectionSurface(selection: model.preferences.language, select: model.selectLanguage)
                case "currency": CurrencySelectionSurface(preferences: model.preferences, select: model.selectCurrency)
                default:
                    ScrollView {
                        VStack(spacing: 16) {
                            RegionalSettingsSection(preferences: model.preferences,
                                chooseLanguage: { page = "language" }, chooseCurrency: { page = "currency" })
                            Button(copy("review.prompt")) { message = ""; prompt = true }
                                .buttonStyle(MPButtonStyle(kind: .soft)).accessibilityIdentifier("regional.review.prompt")
                            if !message.isEmpty { Text(message).font(.system(size: 14)).foregroundStyle(XJTheme.muted).accessibilityIdentifier("regional.review.result") }
                        }.padding(16)
                    }
                }
            }.frame(maxHeight: .infinity)
        }.background(XJTheme.background).foregroundStyle(XJTheme.ink)
            .accessibilityHidden(prompt)
            .overlay {
                if prompt {
                    CurrencyLocationPrompt(automatic: {
                        let denied = ProcessInfo.processInfo.arguments.contains("--regional-review-denied")
                        if denied { model.declineLocation(); message = copy("location.unavailable") }
                        else { model.detect(countryCode: "GB"); message = RegionalCopy.text("location.detected", language: model.language, values: ["currency": CurrencyCatalog.name(model.preferences.currencyCode, language: model.language), "code": model.preferences.currencyCode]) }
                        prompt = false
                    }, manual: { prompt = false; page = "currency" }, decline: {
                        model.declineLocation()
                        message = RegionalCopy.text("location.detected", language: model.language, values: ["currency": CurrencyCatalog.name(model.preferences.currencyCode, language: model.language), "code": model.preferences.currencyCode])
                        prompt = false
                    })
                }
            }.environment(\.regionalLanguage, model.language).environment(\.locale, model.language.locale)
    }

    private var header: some View {
        ZStack {
            Text(copy("settings.\(page == "settings" ? "title" : page)"))
                .font(.system(size: 17, weight: .semibold)).padding(.horizontal, 52)
            if page != "settings" {
                HStack {
                    Button { page = "settings" } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .accessibilityLabel(copy("common.back")).accessibilityIdentifier("regional.back")
                    Spacer()
                }
            }
        }.frame(height: 44).accessibilityIdentifier("regional.header")
    }

    private func copy(_ key: String) -> String { RegionalCopy.text(key, language: model.language) }
}
#endif
