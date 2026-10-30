import Foundation

enum LegalPage: String, CaseIterable {
    case privacy, terms, support

    var title: String {
        switch self {
        case .privacy: "隐私政策"
        case .terms: "使用条款"
        case .support: "帮助与支持"
        }
    }

    var url: URL {
        let path: String
        switch self {
        case .privacy: path = "privacy-policies/kanfangdazi/privacy-policy.html"
        case .terms: path = "terms-of-service/kanfangdazi/terms-of-service.html"
        case .support: path = "kanfangdazi/"
        }
        return URL(string: "https://hayden-chang.github.io/support/" + path)!
    }
}
