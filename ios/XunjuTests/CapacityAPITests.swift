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
    func testContextVerificationAndRestoreUseServerContractAndSignedAppProofWithoutLogin() async throws {
        let http = CapacityHTTP([(200, "{\(balance),\"available\":true,\"productId\":\"test.capacity\",\"packSize\":10,\"appAccountToken\":\"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa\"}"),
            (200, "{\(balance),\"transactionId\":\"123\",\"status\":\"verified\"}"), (200, "{\(balance)}")])
        let api = CapacityAPI(transport: http)
        let context = try await api.context(proof: "signed-app-proof")
        XCTAssertEqual(context.productID, "test.capacity"); XCTAssertEqual(context.balance.limit, 12)
        let confirmed = try await api.verify("123", proof: "signed-app-proof"); XCTAssertEqual(confirmed.status, "verified")
        let restored = try await api.restore(proof: "signed-app-proof"); XCTAssertEqual(restored, confirmed.balance)
        let requests = await http.captured()
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "POST", "POST"])
        XCTAssertEqual(requests.map { $0.value(forHTTPHeaderField: "Authorization") }, Array<String?>(repeating: nil, count: 3))
        XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: XCTUnwrap(requests[1].httpBody)), ["transactionId": "123", "signedAppTransaction": "signed-app-proof"])
        for request in requests {
            XCTAssertTrue(request.url!.path.hasPrefix("/api/rent-room/ios/purchases/"))
            XCTAssertEqual(try JSONDecoder().decode([String: String].self, from: XCTUnwrap(request.httpBody))["signedAppTransaction"], "signed-app-proof")
        }
    }
    func testMalformedAndUnconfirmedResponsesCannotBecomeCapacity() async throws {
        let bodies = [balance.replacingOccurrences(of: "\"limit\":12", with: "\"limit\":2"),
                      balance.replacingOccurrences(of: "Sandbox", with: "Xcode"),
                      balance.replacingOccurrences(of: "\"revision\":3", with: "\"revision\":-1")]
        for body in bodies {
            do { _ = try await CapacityAPI(transport: CapacityHTTP([(200, "{\(body)}")])).restore(proof: "signed-app-proof"); XCTFail("Invalid balance accepted") } catch { }
        }
        let http = CapacityHTTP([(503, "{\"detail\":{\"message\":\"购买记录暂时无法确认\"}}"), (200, "{\(balance),\"transactionId\":\"999\",\"status\":\"verified\"}")])
        let api = CapacityAPI(transport: http)
        do { _ = try await api.verify("123\n", proof: "signed-app-proof"); XCTFail("Invalid identifier sent") } catch { }
        let before = await http.captured(); XCTAssertEqual(before.count, 0)
        do { _ = try await api.verify("123", proof: "signed-app-proof"); XCTFail("Unconfirmed purchase accepted") } catch { XCTAssertEqual(error.localizedDescription, "购买记录暂时无法确认") }
        do { _ = try await api.verify("123", proof: "signed-app-proof"); XCTFail("Mismatched transaction accepted") } catch { }
    }
}
