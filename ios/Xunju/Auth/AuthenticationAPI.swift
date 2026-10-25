import Foundation

struct HTTPPayload: Sendable { let data: Data; let status: Int }
protocol AuthTransport: Sendable {
    func send(_ request: URLRequest) async throws -> HTTPPayload
}
struct URLSessionAuthTransport: AuthTransport {
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CoreFailure(message: "登录服务返回无效，请重试") }
        return HTTPPayload(data: data, status: response.statusCode)
    }
}

struct AppleChallenge: Decodable, Sendable { let challengeId: String; let nonce: String; let expiresIn: Int }
struct LoginReceipt: Decodable, Sendable {
    let account: String
    let token: String
    let provider: String
    let expiresIn: Int
    let packs: Int
    let limit: Int
    var capacity: CapacityPolicy? = nil

    func validated(provider: String) throws -> LoginReceipt {
        try CapacityPolicy.validate(packs: packs, limit: limit, policy: capacity)
        guard account.range(of: "\\A[a-f0-9]{64}\\z", options: .regularExpression) != nil,
              (32...256).contains(token.count), self.provider == provider,
              (1...86400).contains(expiresIn) else { throw CoreFailure(message: "账号校验失败，请重试") }
        return self
    }
}

private struct AuthFailureResponse: Decodable {
    struct Detail: Decodable { let message: String }
    let detail: Detail
}

struct AuthenticationAPI: Sendable {
    var baseURL = URL(string: "https://api.keeline.xyz/api/rent-room")!
    var transport: any AuthTransport = URLSessionAuthTransport()

    func requestAppleChallenge() async throws -> AppleChallenge {
        let result: AppleChallenge = try await post("auth/apple/challenge", body: [:])
        guard validChallenge(result.challengeId), (16...256).contains(result.nonce.count), (1...600).contains(result.expiresIn) else {
            throw CoreFailure(message: "Apple 登录请求返回无效，请重试")
        }
        return result
    }
    func appleSession(token: String, challenge: AppleChallenge) async throws -> LoginReceipt {
        guard !token.isEmpty, token.utf8.count <= 16384, validChallenge(challenge.challengeId) else {
            throw CoreFailure(message: "未取得 Apple 登录凭证，请重试")
        }
        let result: LoginReceipt = try await post("auth/apple/session", body: ["identityToken": token, "challengeId": challenge.challengeId])
        return try result.validated(provider: "apple")
    }
    func revoke(_ token: String) async throws {
        struct Result: Decodable { let revoked: Bool }
        let result: Result = try await post("session/revoke", body: [:], token: token)
        guard result.revoked else { throw CoreFailure(message: "退出登录未确认，请重试") }
    }

    private func validChallenge(_ value: String) -> Bool {
        value.range(of: "\\A[A-Za-z0-9_-]{32,64}\\z", options: .regularExpression) != nil
    }
    private func post<T: Decodable>(_ path: String, body: [String: String], token: String? = nil) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2", forHTTPHeaderField: "x-rent-room-capacity-version")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONEncoder().encode(body)
        let result: HTTPPayload
        do { result = try await transport.send(request) }
        catch is CancellationError { throw CancellationError() }
        catch { throw CoreFailure(message: "连接登录服务失败，请检查网络后重试") }
        guard (200...299).contains(result.status) else {
            let message = (try? JSONDecoder().decode(AuthFailureResponse.self, from: result.data))?.detail.message
            throw CoreFailure(message: message ?? "登录服务暂不可用，请稍后重试")
        }
        do { return try JSONDecoder().decode(T.self, from: result.data) }
        catch { throw CoreFailure(message: "登录服务返回无效，请重试") }
    }
}
