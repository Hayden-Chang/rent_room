import XCTest
@testable import Xunju

final class HouseLongPressHintTests: XCTestCase {
    func testReviewRequiresExplicitKnownRoute() {
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "house-long-press-hint"]), .houseLongPressHint)
        XCTAssertNil(ReviewSurface.parse(["house-long-press-hint"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review"]))
    }
}
