import Foundation
import Observation

enum SupportedLanguage: String, Codable, CaseIterable {
    case chinese = "zh-Hans", english = "en"
    var locale: Locale { Locale(identifier: rawValue) }
}

enum LanguageSelection: String, Codable, CaseIterable {
    case system, chinese, english
    var titleKey: String { "language.\(rawValue)" }

    func resolve(_ preferredLanguages: [String]) -> SupportedLanguage {
        switch self {
        case .chinese: return .chinese
        case .english: return .english
        case .system:
            for identifier in preferredLanguages {
                switch identifier.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").first {
                case "zh": return .chinese
                case "en": return .english
                default: continue
                }
            }
            return .english
        }
    }
}

enum CurrencySelection: Codable, Equatable {
    case automatic, manual(String)
}

/// Device preferences are independent of account records. A house must snapshot
/// currencyCode when created; changing this default never converts an amount.
struct RegionalPreferences: Codable, Equatable {
    var language = LanguageSelection.system
    var currencySelection = CurrencySelection.automatic
    private(set) var automaticCurrency = "USD"
    private(set) var countryCode: String?
    private(set) var currencyPromptHandled = false
    private(set) var automaticLocationRequested: Bool? = nil

    var currencyCode: String {
        let code: String
        switch currencySelection {
        case .automatic: code = automaticCurrency
        case .manual(let selected): code = selected
        }
        return CurrencyCatalog.codes.contains(code) ? code : "USD"
    }

    mutating func detect(countryCode: String?) {
        guard currencySelection == .automatic else { return }
        self.countryCode = countryCode?.uppercased()
        automaticCurrency = CurrencyCatalog.currency(for: countryCode)
        currencyPromptHandled = true
    }

    mutating func declineLocation() {
        automaticLocationRequested = false
        detect(countryCode: nil)
    }

    mutating func markCurrencyPromptHandled() { currencyPromptHandled = true }
    mutating func beginLocationDetection() {
        currencySelection = .automatic; currencyPromptHandled = true; automaticLocationRequested = true
    }

    @discardableResult mutating func selectCurrency(_ code: String?) -> Bool {
        if let code {
            guard CurrencyCatalog.codes.contains(code) else { return false }
            currencySelection = .manual(code)
            automaticLocationRequested = false
            currencyPromptHandled = true
        } else {
            currencySelection = .automatic
        }
        return true
    }
}

enum RegionalCopy {
    static let entries: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "RegionalCopy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return result
    }()

    static func text(_ key: String, language: SupportedLanguage, values: [String: String] = [:]) -> String {
        let template = entries[language.rawValue]?[key] ?? entries[SupportedLanguage.chinese.rawValue]?[key] ?? key
        return values.reduce(template) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}

enum CurrencyCatalog {
    static let codes = Set(RegionalCopy.entries["zh-Hans", default: [:]].keys.compactMap { key -> String? in
        guard key.hasPrefix("currency.") else { return nil }
        let code = String(key.dropFirst("currency.".count))
        return code.count == 3 && code.unicodeScalars.allSatisfy({ (65...90).contains($0.value) }) ? code : nil
    })
    static let common = ["USD", "EUR", "GBP", "CNY", "JPY", "HKD", "AUD", "CAD", "SGD", "NZD"]

    static func currency(for country: String?) -> String {
        guard let region = country?.uppercased(), Locale.Region.isoRegions.contains(where: { $0.identifier == region }),
              let code = Locale(identifier: "und_\(region)").currency?.identifier, codes.contains(code) else { return "USD" }
        return code
    }

    static func name(_ code: String, language: SupportedLanguage) -> String {
        RegionalCopy.text("currency.\(code)", language: language)
    }

    static func matching(_ query: String, language: SupportedLanguage) -> [String] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return codes.filter { code in
            query.isEmpty || code.localizedCaseInsensitiveContains(query) ||
            SupportedLanguage.allCases.contains { name(code, language: $0).localizedCaseInsensitiveContains(query) }
        }.sorted { name($0, language: language).compare(name($1, language: language), locale: language.locale) == .orderedAscending }
    }
}

@MainActor @Observable final class RegionalSettingsModel {
    private(set) var preferences: RegionalPreferences
    private(set) var preferredLanguages: [String]
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key = "regional-preferences.v1"

    init(defaults: UserDefaults, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        self.preferredLanguages = preferredLanguages
        preferences = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(RegionalPreferences.self, from: $0) } ?? RegionalPreferences()
    }

    var language: SupportedLanguage { preferences.language.resolve(preferredLanguages) }

    func updateSystemLanguages(_ values: [String]) { preferredLanguages = values }
    func selectLanguage(_ value: LanguageSelection) { update { $0.language = value } }
    func selectCurrency(_ code: String?) { update { $0.selectCurrency(code) } }
    func detect(countryCode: String?) { update { $0.detect(countryCode: countryCode) } }
    func declineLocation() { update { $0.declineLocation() } }
    func markCurrencyPromptHandled() { update { $0.markCurrencyPromptHandled() } }
    func beginLocationDetection() { update { $0.beginLocationDetection() } }

    private func update(_ change: (inout RegionalPreferences) -> Void) {
        var next = preferences
        change(&next)
        guard let data = try? JSONEncoder().encode(next) else { return }
        defaults.set(data, forKey: key)
        preferences = next
    }
}
