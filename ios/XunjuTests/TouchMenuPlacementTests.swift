import XCTest
@testable import Xunju

final class TouchMenuPlacementTests: XCTestCase {
    private let bounds = CGRect(x: 0, y: 90, width: 390, height: 720)
    private let menu = CGSize(width: 220, height: 156)

    func testUsesTouchPointAndOnlyShiftsForOverflow() {
        let first = TouchMenuPlacement.frame(anchor: CGPoint(x: 40, y: 180), menu: menu, bounds: bounds)
        let second = TouchMenuPlacement.frame(anchor: CGPoint(x: 70, y: 220), menu: menu, bounds: bounds)
        XCTAssertEqual(first.origin, CGPoint(x: 48, y: 180))
        XCTAssertEqual(second.origin, CGPoint(x: 78, y: 220))
        let right = TouchMenuPlacement.frame(anchor: CGPoint(x: 360, y: 220), menu: menu, bounds: bounds)
        XCTAssertEqual(right.origin, CGPoint(x: 158, y: 220))
        XCTAssertEqual(right.maxX, bounds.maxX - 12)
    }

    func testClampsTopBottomAndOversizedMenuInsideViewport() {
        for point in [CGPoint(x: -10, y: 0), CGPoint(x: 380, y: 800)] {
            let result = TouchMenuPlacement.frame(anchor: point, menu: menu, bounds: bounds)
            XCTAssertTrue(bounds.insetBy(dx: 12, dy: 12).contains(result))
        }
        let result = TouchMenuPlacement.frame(anchor: .zero, menu: CGSize(width: 600, height: 1200), bounds: bounds)
        XCTAssertEqual(result, bounds.insetBy(dx: 12, dy: 12))
    }

    func testReviewRequiresExplicitRoute() {
        XCTAssertEqual(ReviewSurface.parse(["--component-review", "touch-menu"]), .touchMenu)
        XCTAssertNil(ReviewSurface.parse(["touch-menu"]))
    }
}
