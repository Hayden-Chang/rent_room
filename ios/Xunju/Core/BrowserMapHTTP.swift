import Foundation
import WebKit

/// Browser credentials are used in an actual WebKit browser context. Keep its
/// cookies and storage ephemeral; never impersonate a browser in URLSession.
struct BrowserMapHTTP: AuthTransport {
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        try await BrowserMapSession.shared.send(request)
    }
}

@MainActor private final class BrowserMapSession {
    static let shared = BrowserMapSession()
    private let webView: WKWebView
    private init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
    }
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        guard let url = request.url, url.scheme == "https", url.host == "api.tianditu.gov.cn", url.user == nil, url.password == nil, url.port == nil,
              ["/v2/search", "/geocoder", "/transit", "/drive"].contains(url.path),
              (request.httpMethod ?? "GET") == "GET" else { throw CoreFailure(message: "地点查询请求无效") }
        let script = """
        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), timeout);
        try {
            const response = await fetch(url, {method: 'GET', credentials: 'omit', cache: 'no-store', signal: controller.signal});
            const data = await response.text();
            return JSON.stringify({status: response.status, data});
        } finally { clearTimeout(timer); }
        """
        let text: String = try await withCheckedThrowingContinuation { continuation in
            webView.callAsyncJavaScript(script, arguments: ["url": url.absoluteString, "timeout": min(12000, max(1, request.timeoutInterval * 1000))], in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    guard let text = value as? String else { continuation.resume(throwing: CoreFailure(message: "地点查询结果无效")); return }
                    continuation.resume(returning: text)
                case .failure:
                    continuation.resume(throwing: CoreFailure(message: "地点查询失败，请重试"))
                }
            }
        }
        struct Reply: Decodable { let status: Int; let data: String }
        let value = try JSONDecoder().decode(Reply.self, from: Data(text.utf8))
        return HTTPPayload(data: Data(value.data.utf8), status: value.status)
    }
}
