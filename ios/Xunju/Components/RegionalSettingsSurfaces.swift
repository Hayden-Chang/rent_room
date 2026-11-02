import SwiftUI

private struct RegionalLanguageKey: EnvironmentKey {
    static let defaultValue = SupportedLanguage.chinese
}

extension EnvironmentValues {
    var regionalLanguage: SupportedLanguage {
        get { self[RegionalLanguageKey.self] }
        set { self[RegionalLanguageKey.self] = newValue }
    }
}

/// Reusable setting rows. Navigation and persistence belong to the caller.
struct RegionalSettingsSection: View {
    let preferences: RegionalPreferences
    let chooseLanguage: () -> Void
    let chooseCurrency: () -> Void
    @Environment(\.regionalLanguage) private var language

    var body: some View {
        XJCard(verticalPadding: 4) {
            VStack(spacing: 0) {
                row("settings.language", detail: copy(preferences.language.titleKey), action: chooseLanguage)
                Divider()
                row("settings.currency", detail: currencyDetail, action: chooseCurrency)
            }
        }
    }

    private var currencyDetail: String {
        if preferences.currencySelection == .automatic { return copy("currency.automatic") + " · " + preferences.currencyCode }
        return CurrencyCatalog.name(preferences.currencyCode, language: language) + " · " + preferences.currencyCode
    }

    private func copy(_ key: String) -> String { RegionalCopy.text(key, language: language) }

    private func row(_ key: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(copy(key)).font(.system(size: 14, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text(detail).font(.system(size: 12)).foregroundStyle(XJTheme.muted)
                    .multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(XJTheme.muted)
            }.frame(minHeight: 52).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(key)
    }
}

struct LanguageSelectionSurface: View {
    let selection: LanguageSelection
    let select: (LanguageSelection) -> Void
    @Environment(\.regionalLanguage) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                XJCard {
                    VStack(spacing: 0) {
                        ForEach(LanguageSelection.allCases, id: \.self) { item in
                            RegionalChoiceRow(title: RegionalCopy.text(item.titleKey, language: language),
                                selected: selection == item, identifier: "language.\(item.rawValue)") { select(item) }
                            if item != LanguageSelection.allCases.last { Divider() }
                        }
                    }
                }
                Text(RegionalCopy.text("language.help", language: language))
                    .font(.system(size: 13)).foregroundStyle(XJTheme.muted).padding(.horizontal, 4)
            }.padding(16)
        }.background(XJTheme.background)
    }
}

struct CurrencySelectionSurface: View {
    let preferences: RegionalPreferences
    let select: (String?) -> Void
    @Environment(\.regionalLanguage) private var language
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(XJTheme.muted).accessibilityHidden(true)
                TextField(copy("currency.search"), text: $query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .accessibilityIdentifier("currency.search")
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(XJTheme.muted) }
                        .accessibilityLabel(copy("common.cancel"))
                }
            }.font(.system(size: 15)).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 10)).padding(16)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        XJCard {
                            RegionalChoiceRow(title: copy("currency.automatic"),
                                subtitle: copy("currency.automaticHelp") + " · " + preferences.automaticCurrency,
                                selected: preferences.currencySelection == .automatic, identifier: "currency.automatic") { select(nil) }
                        }
                        Text(copy("currency.help")).font(.system(size: 13)).foregroundStyle(XJTheme.muted).padding(.horizontal, 4)
                        currencyGroup("currency.common", codes: CurrencyCatalog.common.filter { CurrencyCatalog.codes.contains($0) })
                    }
                    let matches = CurrencyCatalog.matching(query, language: language)
                    let codes = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? matches.filter { !CurrencyCatalog.common.contains($0) } : matches
                    if codes.isEmpty {
                        Text(copy("currency.noResults")).font(.system(size: 15)).foregroundStyle(XJTheme.muted)
                            .frame(maxWidth: .infinity).padding(.vertical, 32).accessibilityIdentifier("currency.empty")
                    } else { currencyGroup(query.isEmpty ? "currency.all" : nil, codes: codes) }
                }.padding(.horizontal, 16).padding(.bottom, 24)
            }.scrollDismissesKeyboard(.interactively)
        }.background(XJTheme.background)
    }

    private func copy(_ key: String) -> String { RegionalCopy.text(key, language: language) }

    private func currencyGroup(_ title: String?, codes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { Text(copy(title)).font(.system(size: 13, weight: .medium)).foregroundStyle(XJTheme.muted).padding(.horizontal, 4) }
            LazyVStack(spacing: 0) {
                ForEach(codes, id: \.self) { code in
                    RegionalChoiceRow(title: CurrencyCatalog.name(code, language: language), subtitle: code,
                        selected: preferences.currencySelection == .manual(code), identifier: "currency.\(code)") { select(code) }
                        .padding(.horizontal, 16)
                    if code != codes.last { Divider().padding(.horizontal, 16) }
                }
            }.background(.white, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct RegionalChoiceRow: View {
    let title: String
    var subtitle = ""
    let selected: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                    if !subtitle.isEmpty { Text(subtitle).font(.system(size: 12)).foregroundStyle(XJTheme.muted) }
                }
                Spacer(minLength: 12)
                Image(systemName: "checkmark").font(.system(size: 16, weight: .semibold)).foregroundStyle(XJTheme.primary)
                    .opacity(selected ? 1 : 0).accessibilityHidden(true)
            }.padding(.vertical, 14).frame(minHeight: 52).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityIdentifier(identifier)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Explanation before requesting system permission. The caller owns the actual
/// permission request, denial handling and the one-time onboarding trigger.
struct CurrencyLocationPrompt: View {
    var busy = false
    var fallbackCurrency = CurrencyCatalog.fallbackCurrency(for: Locale.preferredLanguages)
    let automatic: () -> Void
    let manual: () -> Void
    let decline: () -> Void
    @Environment(\.regionalLanguage) private var language

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill").font(.system(size: 42)).foregroundStyle(XJTheme.primary).accessibilityHidden(true)
                Text(copy("location.title")).font(.system(size: 20, weight: .semibold)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("currency.prompt.title")
                if busy {
                    ProgressView(copy("location.loading")).font(.system(size: 14)).accessibilityIdentifier("currency.prompt.loading")
                } else {
                    VStack(spacing: 8) {
                        Button(copy("location.allow"), action: automatic).buttonStyle(MPButtonStyle(kind: .primary)).accessibilityIdentifier("currency.prompt.allow")
                        Button(copy("location.manual"), action: manual).buttonStyle(MPButtonStyle(kind: .soft)).accessibilityIdentifier("currency.prompt.manual")
                        Button(RegionalCopy.text("location.decline", language: language,
                            values: ["currency": language == .chinese ? CurrencyCatalog.name(fallbackCurrency, language: language) : fallbackCurrency]),
                            action: decline).buttonStyle(MPButtonStyle(kind: .plain)).accessibilityIdentifier("currency.prompt.decline")
                    }
                }
            }.padding(24).frame(maxWidth: 360).background(.white, in: RoundedRectangle(cornerRadius: 20))
                .padding(24).foregroundStyle(XJTheme.ink)
        }.accessibilityElement(children: .contain).accessibilityAddTraits(.isModal)
    }

    private func copy(_ key: String) -> String { RegionalCopy.text(key, language: language) }
}
