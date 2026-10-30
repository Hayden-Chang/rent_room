import Foundation
import Observation
import SwiftUI

@MainActor @Observable final class AppLanguage {
    static let shared = AppLanguage()
    var value = LanguageSelection.system.resolve(Locale.preferredLanguages)
}

/// Display-only translation. Callers must use Text(verbatim:) for user-authored
/// names, notes, captions, addresses and summaries. Stored choices stay canonical.
@MainActor enum AppCopy {
    static let translations: [String: String] = {
        guard let url = Bundle.main.url(forResource: "AppCopy", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return value
    }()
    private struct Template {
        let pattern: NSRegularExpression
        let target: String
        let tokens: [String]
    }
    private static let templates: [Template] = translations.keys.filter { $0.contains("{v") }.sorted { $0.count > $1.count }.compactMap { source in
        guard let matcher = try? NSRegularExpression(pattern: #"\{v\d+\}"#) else { return nil }
        let range = NSRange(source.startIndex..., in: source)
        let matches = matcher.matches(in: source, range: range)
        var pattern = "^", cursor = source.startIndex, tokens: [String] = []
        for match in matches {
            guard let r = Range(match.range, in: source) else { continue }
            pattern += NSRegularExpression.escapedPattern(for: String(source[cursor..<r.lowerBound])) + "(.*?)"
            tokens.append(String(source[r])); cursor = r.upperBound
        }
        pattern += NSRegularExpression.escapedPattern(for: String(source[cursor...])) + "$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators), let target = translations[source] else { return nil }
        return Template(pattern: regex, target: target, tokens: tokens)
    }
    private static let fragments = translations.keys.filter { !$0.contains("{v") && $0.count > 1 }.sorted { $0.count > $1.count }

    static func text(_ source: String, language: SupportedLanguage? = nil, translatingArguments: Bool = false) -> String {
        guard (language ?? AppLanguage.shared.value) == .english else { return source }
        return translate(source, depth: 0, translatingArguments: translatingArguments)
    }
    private static func translate(_ source: String, depth: Int, translatingArguments: Bool = false) -> String {
        if let exact = translations[source] { return exact }
        guard source.range(of: #"[\u3400-\u9fff]"#, options: .regularExpression) != nil else { return source }
        for template in templates {
            if let match = template.pattern.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)) {
                var result = template.target
                for (i, token) in template.tokens.enumerated() {
                    if let range = Range(match.range(at: i + 1), in: source) {
                        result = result.replacingOccurrences(of: token, with: translatingArguments ? translate(String(source[range]), depth: depth + 1) : String(source[range]))
                    }
                }
                return result
            }
        }
        // Some canonical labels are assembled from a translated label and a
        // translated suffix (counts, multiple choice, units). Never write back.
        guard depth < 8 else { return source }
        for fragment in fragments {
            if source.hasPrefix(fragment) { return translations[fragment]! + translate(String(source.dropFirst(fragment.count)), depth: depth + 1) }
            if source.hasSuffix(fragment) { return translate(String(source.dropLast(fragment.count)), depth: depth + 1) + translations[fragment]! }
        }
        return source
    }
    static var shareCoverURL: URL? {
        let english = AppLanguage.shared.value == .english
        return Bundle.main.url(forResource: english ? "InspectionShareCover-en" : "InspectionShareCover", withExtension: english ? "png" : "jpg")
    }
    static func fieldLabel(_ source: String, id: String) -> String {
        id.hasPrefix("cost_") ? source : text(source)
    }
    static func comparisonValue(_ row: JSONValue, index: Int) -> String {
        if AppLanguage.shared.value == .chinese { return row["values"].array.indices.contains(index) ? row["values"].array[index].string : "" }
        let choices = row["choices"].array
        if choices.indices.contains(index), !choices[index].array.isEmpty {
            return choices[index].array.map { choice in
                let label = choice["localized"].bool ? text(choice["label"].string) : choice["label"].string
                return label + (choice["detail"].string.isEmpty ? "" : ": " + choice["detail"].string)
            }.joined(separator: AppLanguage.shared.value == .english ? ", " : "、")
        }
        let values = row["values"].array, flags = row["localized"].array
        guard values.indices.contains(index) else { return "" }
        return flags.indices.contains(index) && flags[index].bool ? text(values[index].string) : values[index].string
    }
    static func moneyLabel(_ source: String, currency: String, verbatim: Bool = false) -> String {
        let code = CurrencyCatalog.codes.contains(currency) ? currency : "CNY"
        if verbatim { return source + "（\(code)）" }
        let value = text(source)
        if AppLanguage.shared.value == .english, value.contains("CNY") {
            return value.replacingOccurrences(of: "CNY", with: code)
        }
        if value.contains("（元") { return value.replacingOccurrences(of: "（元", with: "（" + code) }
        return value + "（\(code)）"
    }
    static func searchTerms(_ query: String) -> [String] {
        guard AppLanguage.shared.value == .english, !query.isEmpty else { return [] }
        return translations.filter { !$0.key.contains("{v") && $0.value.localizedCaseInsensitiveContains(query) }.map(\.key)
    }
}

@MainActor func AppText(_ value: String) -> Text { Text(verbatim: AppCopy.text(value)) }
