import XCTest
@testable import Xunju

private actor StubAuthTransport: AuthTransport {
    var responses: [HTTPPayload]
    var requests: [URLRequest] = []
    init(_ values: [(Int, String)]) { responses = values.map { HTTPPayload(data: Data($0.1.utf8), status: $0.0) } }
    func send(_ request: URLRequest) async throws -> HTTPPayload {
        requests.append(request)
        guard !responses.isEmpty else { throw CoreFailure(message: "No test response") }
        return responses.removeFirst()
    }
    func captured() -> [URLRequest] { requests }
}

final class AuthenticationAPITests: XCTestCase {
    private let challenge = String(repeating: "a", count: 43)
    private let account = String(repeating: "b", count: 64)
    private let token = String(repeating: "t", count: 43)

    func testSMSChallengeAndSessionKeepServerIdentityContract() async throws {
        let transport = StubAuthTransport([(200, "{\"challengeId\":\"\(challenge)\",\"expiresIn\":300,\"retryAfter\":60}"),
            (200, "{\"account\":\"\(account)\",\"token\":\"\(token)\",\"provider\":\"phone\",\"expiresIn\":7200,\"packs\":1,\"limit\":12}")])
        let api = AuthenticationAPI(transport: transport)
        let pending = try await api.requestPhoneCode("13800138000")
        let receipt = try await api.phoneSession(phone: "13800138000", code: "012345", challenge: pending)
        XCTAssertEqual(receipt.account, account)
        XCTAssertEqual(receipt.packs, 1)
        let requests = await transport.captured()
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/rent-room/auth/phone/code", "/api/rent-room/auth/phone/session"])
        let payload = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(requests.last?.httpBody))
        XCTAssertEqual(payload["code"], "012345")
        XCTAssertEqual(payload["challengeId"], challenge)
        XCTAssertNil(requests.last?.value(forHTTPHeaderField: "Authorization"))
        let session = try LocalSession(receipt: receipt, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(session.expiresAt.timeIntervalSince1970, 7300)
    }

    func testSMSFailuresDoNotCreateReceiptAndInvalidInputDoesNotSend() async throws {
        let transport = StubAuthTransport([(503, "{\"detail\":{\"message\":\"短信服务尚未接通\"}}")])
        let api = AuthenticationAPI(transport: transport)
        do { _ = try await api.requestPhoneCode("13800138000\n"); XCTFail("Must reject malformed phone") } catch { }
        let before = await transport.captured()
        XCTAssertEqual(before.count, 0)
        do { _ = try await api.requestPhoneCode("13800138000"); XCTFail("Must not report sent") }
        catch { XCTAssertEqual(error.localizedDescription, "短信服务尚未接通") }
        let after = await transport.captured()
        XCTAssertEqual(after.count, 1)
        let invalid = LoginReceipt(account: "../another-user", token: token, provider: "phone", expiresIn: 7200, packs: 0, limit: 2)
        XCTAssertThrowsError(try invalid.validated(provider: "phone"))
        let badCapacity = LoginReceipt(account: account, token: token, provider: "phone", expiresIn: 7200, packs: 1, limit: 2)
        XCTAssertThrowsError(try badCapacity.validated(provider: "phone"))
    }

    func testAppleNonceAndTokenArePassedToServerAndRevokeUsesBearer() async throws {
        let transport = StubAuthTransport([(200, "{\"challengeId\":\"\(challenge)\",\"nonce\":\"\(challenge)\",\"expiresIn\":300}"),
            (200, "{\"account\":\"\(account)\",\"token\":\"\(token)\",\"provider\":\"apple\",\"expiresIn\":7200,\"packs\":0,\"limit\":2}"),
            (200, "{\"revoked\":true}")])
        let api = AuthenticationAPI(transport: transport)
        let pending = try await api.requestAppleChallenge()
        XCTAssertEqual(pending.nonce, challenge)
        let receipt = try await api.appleSession(token: "signed.identity.token", challenge: pending)
        try await api.revoke(receipt.token)
        let requests = await transport.captured()
        let payload = try JSONDecoder().decode([String: String].self, from: XCTUnwrap(requests[1].httpBody))
        XCTAssertEqual(payload, ["identityToken": "signed.identity.token", "challengeId": challenge])
        XCTAssertEqual(requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer " + token)
        XCTAssertThrowsError(try receipt.validated(provider: "phone"))
    }
}
