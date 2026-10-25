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
    func testAppleChallengeFailureCanRetryWithoutCreatingSession() async throws {
        let transport = StubAuthTransport([(503, "{}"),
            (200, "{\"challengeId\":\"\(challenge)\",\"nonce\":\"\(challenge)\",\"expiresIn\":300}")])
        let api = AuthenticationAPI(transport: transport)
        do { _ = try await api.requestAppleChallenge(); XCTFail("Unavailable challenge must fail") }
        catch { XCTAssertEqual(error.localizedDescription, "登录服务暂不可用，请稍后重试") }
        let pending = try await api.requestAppleChallenge()
        XCTAssertEqual(pending.challengeId, challenge)
        let requests = await transport.captured()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.url?.path == "/api/rent-room/auth/apple/challenge" })
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
    }

    func testAppleRejectsInvalidChallengeAndTokenBeforeSessionRequest() async throws {
        for response in ["{\"challengeId\":\"short\",\"nonce\":\"\(challenge)\",\"expiresIn\":300}",
                         "{\"challengeId\":\"\(challenge)\",\"nonce\":\"short\",\"expiresIn\":300}",
                         "{\"challengeId\":\"\(challenge)\",\"nonce\":\"\(challenge)\",\"expiresIn\":0}"] {
            let api = AuthenticationAPI(transport: StubAuthTransport([(200, response)]))
            do { _ = try await api.requestAppleChallenge(); XCTFail("Invalid challenge must fail") } catch {}
        }
        let transport = StubAuthTransport([]), api = AuthenticationAPI(transport: transport)
        let pending = AppleChallenge(challengeId: challenge, nonce: challenge, expiresIn: 300)
        for invalid in ["", String(repeating: "x", count: 16385)] {
            do { _ = try await api.appleSession(token: invalid, challenge: pending); XCTFail("Invalid token must fail") } catch {}
        }
        let requests = await transport.captured()
        XCTAssertTrue(requests.isEmpty)
    }

    func testAppleRejectsUnverifiedProviderIdentityAndCapacityReceipts() async throws {
        let pending = AppleChallenge(challengeId: challenge, nonce: challenge, expiresIn: 300)
        for (id, provider, packs, limit) in [(account, "phone", 0, 2), ("../other-user", "apple", 0, 2), (account, "apple", 1, 2)] {
            let response = "{\"account\":\"\(id)\",\"token\":\"\(token)\",\"provider\":\"\(provider)\",\"expiresIn\":7200,\"packs\":\(packs),\"limit\":\(limit)}"
            let api = AuthenticationAPI(transport: StubAuthTransport([(200, response)]))
            do { _ = try await api.appleSession(token: "signed.token", challenge: pending); XCTFail("Unverified receipt must fail") } catch {}
        }
    }

    func testAppleSessionUsesV2CapacityAndExpiresAtServerLifetime() async throws {
        let response = "{\"account\":\"\(account)\",\"token\":\"\(token)\",\"provider\":\"apple\",\"expiresIn\":7200,\"packs\":1,\"limit\":11,\"capacity\":{\"version\":2,\"freeLimit\":1}}"
        let transport = StubAuthTransport([(200, response)])
        let receipt = try await AuthenticationAPI(transport: transport).appleSession(token: "signed.token",
            challenge: AppleChallenge(challengeId: challenge, nonce: challenge, expiresIn: 300))
        let session = try LocalSession(receipt: receipt, now: Date(timeIntervalSince1970: 100))
        XCTAssertEqual(session.provider, "apple")
        XCTAssertEqual(session.expiresAt.timeIntervalSince1970, 7300)
        XCTAssertEqual(session.capacityPolicy?.freeLimit, 1)
        let requests = await transport.captured()
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "x-rent-room-capacity-version"), "2")
    }

    #if DEBUG
    func testAppleRetryFixtureRequiresExplicitUUIDSandbox() {
        XCTAssertFalse(AppleLoginFixture.enabled(arguments: ["app", "--apple-login-retry-fixture"]))
        XCTAssertFalse(AppleLoginFixture.enabled(arguments: ["app", "--business-test", "../user", "--apple-login-retry-fixture"]))
        XCTAssertFalse(AppleLoginFixture.enabled(arguments: ["app", "--business-test", UUID().uuidString]))
        XCTAssertTrue(AppleLoginFixture.enabled(arguments: ["app", "--business-test", UUID().uuidString, "--apple-login-retry-fixture"]))
    }
    #endif

}
