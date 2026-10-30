import XCTest
@testable import Xunju

private actor PolicyTransport: AuthTransport {
    let body: String
    var request: URLRequest?
    init(_ body: String) { self.body = body }
    func send(_ request: URLRequest) -> HTTPPayload { self.request = request; return HTTPPayload(data: Data(body.utf8), status: 200) }
    func captured() -> URLRequest? { request }
}
final class CapacityPolicyTests: XCTestCase {
    func testPolicyAcceptsZeroAndValidatesTotalsWithoutInferringLegacyFreeQuota() throws {
        let zero = CapacityPolicy(version: 2, freeLimit: 0)
        XCTAssertNoThrow(try CapacityPolicy.validate(packs: 2, limit: 20, policy: zero))
        XCTAssertThrowsError(try CapacityPolicy.validate(packs: 2, limit: 22, policy: zero))
        XCTAssertThrowsError(try CapacityPolicy(version: 1, freeLimit: 1).validated())
        XCTAssertThrowsError(try CapacityPolicy(version: 2, freeLimit: -1).validated())
        XCTAssertNoThrow(try CapacityPolicy.validate(packs: 1, limit: 12, policy: nil))
        XCTAssertEqual(CapacityPolicy.initial.freeLimit, 1)
    }
    @MainActor func testLocalPolicyCacheSurvivesRestartAndDoesNotExportIdentity() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "policy-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let workspace = try AppWorkspace(root: root, keychain: VolatileSessionStorage())
        let id = try workspace.store.add("旧房源")
        try workspace.acceptPolicy(CapacityPolicy(version: 2, freeLimit: 0))
        let restored = try AppWorkspace(root: root, keychain: VolatileSessionStorage())
        XCTAssertEqual(restored.store.capacity.limit, 0)
        try restored.store.answer(id, field: "f1_6", value: .string("1000"))
        XCTAssertThrowsError(try restored.store.add("超出"))
        XCTAssertEqual(restored.store.state["capacity"], .null)
        let cache = try String(contentsOf: root.appending(path: "capacity-policy.json"), encoding: .utf8)
        XCTAssertFalse(cache.contains("token")); XCTAssertFalse(cache.contains("account")); XCTAssertFalse(cache.contains("packs"))
    }
    func testLoginAndBalanceAcceptVersionTwoZeroPolicyAndRejectMismatch() throws {
        let policy = CapacityPolicy(version: 2, freeLimit: 0)
        let receipt = LoginReceipt(account: String(repeating: "a", count: 64), token: String(repeating: "t", count: 48), provider: "phone", expiresIn: 7200, packs: 1, limit: 10, capacity: policy)
        let session = try LocalSession(receipt: receipt)
        try session.validateStored()
        XCTAssertEqual(session.capacityPolicy, policy)
        let invalid = CapacityBalance(account: receipt.account, environment: "Sandbox", packs: 1, limit: 12, revision: 0, capacity: policy)
        XCTAssertThrowsError(try invalid.validated())
    }
    func testFeedbackRequiresMatchingServerReceipt() async throws {
        let request: JSONValue = .object(["requestId": .string("feedback-id"), "ease": .string("方便")])
        do { _ = try await NativeFeedback(transport: PolicyTransport("{\"receipt\":\"wrong\"}")).submit(request); XCTFail("wrong receipt accepted") } catch {}
        let transport = PolicyTransport("{\"receipt\":\"feedback-id\"}")
        let receipt = try await NativeFeedback(transport: transport).submit(request)
        XCTAssertEqual(receipt, "feedback-id")
        let sent = await transport.captured()
        XCTAssertEqual(sent?.httpMethod, "POST")
        XCTAssertNil(sent?.value(forHTTPHeaderField: "Authorization"))
    }
}
