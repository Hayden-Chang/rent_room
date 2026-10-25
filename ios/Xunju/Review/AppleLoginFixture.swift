#if DEBUG
import Foundation

/// Only the challenge service is replaced. No Apple authorization or login
/// receipt is fabricated, and ordinary Debug/Release launches never use this.
enum AppleLoginFixture {
    static func enabled(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        guard let test = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(test + 1),
              UUID(uuidString: arguments[test + 1]) != nil else { return false }
        return arguments.contains("--apple-login-retry-fixture")
    }
    static func api() -> AuthenticationAPI? {
        enabled() ? AuthenticationAPI(transport: ChallengeHTTP()) : nil
    }
    private actor ChallengeHTTP: AuthTransport {
        private var requests = 0
        func send(_ request: URLRequest) throws -> HTTPPayload {
            guard request.url?.path == "/api/rent-room/auth/apple/challenge" else {
                throw CoreFailure(message: "Unexpected Apple fixture request")
            }
            requests += 1
            if requests == 1 {
                return HTTPPayload(data: Data("{}".utf8), status: 503)
            }
            let value: [String: Any] = ["challengeId": String(repeating: "a", count: 43),
                                       "nonce": String(repeating: "n", count: 43), "expiresIn": 300]
            return HTTPPayload(data: try JSONSerialization.data(withJSONObject: value), status: 200)
        }
    }
}
#endif
