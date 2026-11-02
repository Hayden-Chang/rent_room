#if DEBUG
import XCTest
@testable import Xunju

final class DevelopmentCreditsTapSequenceTests: XCTestCase {
    func testTenthTapGrantsOnceAndNextBurstCanRepeat() {
        var sequence = DevelopmentCreditsTapSequence()
        for burst in 0..<2 {
            for tap in 0..<10 {
                XCTAssertEqual(sequence.tap(at: Double(burst * 10) + Double(tap) * 0.2), tap == 9)
            }
        }
    }

    func testFiveSecondBoundaryAndExpiredBurst() {
        var sequence = DevelopmentCreditsTapSequence()
        for _ in 0..<9 { XCTAssertFalse(sequence.tap(at: 100)) }
        XCTAssertTrue(sequence.tap(at: 105))
        for _ in 0..<9 { XCTAssertFalse(sequence.tap(at: 110)) }
        XCTAssertFalse(sequence.tap(at: 115.001))
        for _ in 0..<8 { XCTAssertFalse(sequence.tap(at: 116)) }
        XCTAssertTrue(sequence.tap(at: 116))
    }

    func testLeavingScreenOrBackgroundingDiscardsPartialBurst() {
        var sequence = DevelopmentCreditsTapSequence()
        for _ in 0..<9 { XCTAssertFalse(sequence.tap(at: 0)) }
        sequence.reset()
        for _ in 0..<9 { XCTAssertFalse(sequence.tap(at: 1)) }
        XCTAssertTrue(sequence.tap(at: 1))
    }

    func testInvalidOrReversedTimeNeverCompletesOldBurst() {
        for invalid in [Double.nan, .infinity, -1] {
            var sequence = DevelopmentCreditsTapSequence()
            for _ in 0..<9 { XCTAssertFalse(sequence.tap(at: 0)) }
            XCTAssertFalse(sequence.tap(at: invalid))
        }
    }

    func testReviewRouteRequiresExplicitKnownArgument() {
        XCTAssertEqual(LocalSettingsReviewRoute.parse(["--local-settings-review", "developmentCredits"]), .developmentCredits)
        XCTAssertEqual(LocalSettingsReviewRoute.parse(["--local-settings-review", "developmentCreditsFailure"]), .developmentCreditsFailure)
        XCTAssertNil(LocalSettingsReviewRoute.parse([]))
        XCTAssertNil(LocalSettingsReviewRoute.parse(["developmentCredits"]))
        XCTAssertNil(LocalSettingsReviewRoute.parse(["--local-settings-review"]))
        XCTAssertNil(LocalSettingsReviewRoute.parse(["--local-settings-review", "unknown"]))
    }
}
#endif
