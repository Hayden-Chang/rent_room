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

struct PhoneChallenge: Decodable, Sendable { let challengeId: String; let expiresIn: Int; let retryAfter: Int }
struct AppleChallenge: Decodable, Sendable { let challengeId: String; let nonce: String; let expiresIn: Int }
struct LoginReceipt: Decodable, Sendable {
    let account: String
    let token: String
    let provider: String
    let expiresIn: Int
    let packs: Int
    let limit: Int

    func validated(provider: String) throws -> LoginReceipt {
        guard account.range(of: "\\A[a-f0-9]{64}\\z", options: .regularExpression) != nil,
              (32...256).contains(token.count), self.provider == provider,
              (1...86400).contains(expiresIn), packs >= 0, packs <= (Int.max - 2) / 10,
              limit == 2 + 10 * packs else { throw CoreFailure(message: "账号校验失败，请重试") }
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

    func requestPhoneCode(_ phone: String) async throws -> PhoneChallenge {
        guard PhoneLoginValidation.validPhone(phone) else { throw CoreFailure(message: "请输入正确的手机号") }
        let result: PhoneChallenge = try await post("auth/phone/code", body: ["phone": phone])
        guard validChallenge(result.challengeId), (1...600).contains(result.expiresIn), (1...600).contains(result.retryAfter) else {
            throw CoreFailure(message: "验证码请求返回无效，请重试")
        }
        return result
    }
    func phoneSession(phone: String, code: String, challenge: PhoneChallenge) async throws -> LoginReceipt {
        guard PhoneLoginValidation.validPhone(phone), PhoneLoginValidation.validCode(code), validChallenge(challenge.challengeId) else {
            throw CoreFailure(message: "请输入正确的手机号和6位验证码")
        }
        let result: LoginReceipt = try await post("auth/phone/session", body: ["phone": phone, "code": code, "challengeId": challenge.challengeId])
        return try result.validated(provider: "phone")
    }
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
