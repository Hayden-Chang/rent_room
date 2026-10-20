import XCTest
@testable import Xunju

final class UtilityComponentTests: XCTestCase {
    func testCoachCardStaysWithinAvailableHeightAndUsesLiveTarget() {
        XCTAssertEqual(CoachPlacement.cardTop(target: CGRect(x: 16, y: 100, width: 80, height: 40), height: 196, available: 700), 158)
        XCTAssertEqual(CoachPlacement.cardTop(target: CGRect(x: 16, y: 500, width: 80, height: 40), height: 196, available: 568), 286)
        XCTAssertEqual(CoachPlacement.cardTop(target: nil, height: 220, available: 568), 174)
        XCTAssertEqual(CoachPlacement.cardTop(target: CGRect(x: 16, y: 80, width: 300, height: 48), height: 220, available: 300), 68)
    }

    func testReviewRoutesRequireExplicitKnownDebugArgument() {
        #if DEBUG
        for surface in ["place", "routes", "speed", "coach", "speed-consent", "measurements", "media", "issue-media", "headings"] {
            XCTAssertEqual(ReviewSurface.parse(["--component-review", surface])?.rawValue, surface)
        }
        XCTAssertNil(ReviewSurface.parse(["--component-review"]))
        XCTAssertNil(ReviewSurface.parse(["place"]))
        XCTAssertNil(ReviewSurface.parse(["--component-review", "unknown"]))
        #endif
    }
}
