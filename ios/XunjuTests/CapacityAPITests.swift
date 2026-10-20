import XCTest
@testable import Xunju

private actor CapacityHTTP: AuthTransport {
    var responses: [HTTPPayload]; var requests: [URLRequest] = []
    init(_ values: [(Int, String)]) { responses = values.map { HTTPPayload(data: Data($0.1.utf8), status: $0.0) } }
    func send(_ request: URLRequest) throws -> HTTPPayload { requests.append(request); return responses.removeFirst() }
    func captured() -> [URLRequest] { requests }
}
final class CapacityAPITests: XCTestCase {
    private let balance = "\"account\":\"\(String(repeating: "a", count: 64))\",\"environment\":\"Sandbox\",\"packs\":1,\"limit\":12,\"revision\":3"
    func testContextVerificationAndRestoreUseServerContractAndBearer() async throws {
        let http = CapacityHTTP([(200, "{\(balance),\"available\":true,\"productId\":\"test.capacity\",\"packSize\":10,\"appAccountToken\":\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\"}"),
            (200, "{\(balance),\"transactionId\":\"123\",\"status\":\"verified\"}"), (200, "{\(balance)}")])
        let api = CapacityAPI(transport: http)
        let context = try await api.context(token: "session")
        XCTAssertEqual(context.productID, "test.capacity"); XCTAssertEqual(context.balance.limit, 12)
        let confirmed = try await api.verify("123", token: "session"); XCTAssertEqual(confirmed.status, "verified")
        let restored = try await api.restore(token: "session"); XCTAssertEqual(restored, confirmed.balance)
        let requests = await http.captured()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "POST", "POST"])
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "Authorization") }, Array(repeating: "Bearer session", count: 3))
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: XCTUnwrap(requests[1].httpBody)), ["transactionId": "123"])
        XCTAssertNil(requests[0].httpBody)
    }
    func testMalformedAndUnconfirmedResponsesCannotBecomeCapacity() async throws {
        let bodies = [balance.replacingOccurrences(of: "\"limit\":12", with: "\"limit\":2"),
                      balance.replacingOccurrences(of: "Sandbox", with: "Xcode"),
                      balance.replacingOccurrences(of: "\"revision\":3", with: "\"revision\":-1")]
        for body in bodies {
            do { _ = try await CapacityAPI(transport: CapacityHTTP([(200, "{\(body)}")])).restore(token: "session"); XCTFail("Invalid balance accepted") } catch { }
        }
        let http = CapacityHTTP([(503, "{\"detail\":{\"message\":\"购买记录暂时无法确认\"}}"), (200, "{\(balance),\"transactionId\":\"999\",\"status\":\"verified\"}")])
        let api = CapacityAPI(transport: http)
        do { _ = try await api.verify("123\n", token: "session"); XCTFail("Invalid identifier sent") } catch { }
        let before = await http.captured(); XCTAssertEqual(before.count, 0)
        do { _ = try await api.verify("123", token: "session"); XCTFail("Unconfirmed purchase accepted") } catch { XCTAssertEqual(error.localizedDescription, "购买记录暂时无法确认") }
        do { _ = try await api.verify("123", token: "session"); XCTFail("Mismatched transaction accepted") } catch { }
    }
}
