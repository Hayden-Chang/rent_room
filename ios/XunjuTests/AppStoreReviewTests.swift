import XCTest
@testable import Xunju

final class AppStoreReviewTests: XCTestCase {
    func testReviewURLTargetsWritingReviewWithoutPinningStorefront() throws {
        let url = try XCTUnwrap(AppStoreReview.url(appID: "1234567890"))
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "apps.apple.com")
        XCTAssertEqual(components.path, "/app/id1234567890")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "action", value: "write-review")])
    }

    func testMissingOrInvalidAppIDCannotOpenAnUnrelatedDestination() {
        for id: String? in [nil, "", "0", "0123", "-1", "id123", "１２３", "123?other=1", "123/456", " 123 "] {
            XCTAssertNil(AppStoreReview.url(appID: id), "Unexpected URL for \(id ?? "nil")")
        }
    }
}
