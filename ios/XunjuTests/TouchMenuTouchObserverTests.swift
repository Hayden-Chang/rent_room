import UIKit
import XCTest
@testable import Xunju

@MainActor
final class TouchMenuTouchObserverTests: XCTestCase {
    func testCoordinateObservationDoesNotCompeteWithPressTapOrScroll() {
        let observer = TouchMenuTouchObserver()
        let recognizer = TouchMenuTouchRecognizer(observer: observer)
        XCTAssertFalse(observer.isUserInteractionEnabled)
        XCTAssertTrue(observer.accessibilityElementsHidden)
        XCTAssertFalse(recognizer.cancelsTouchesInView)
        XCTAssertFalse(recognizer.delaysTouchesBegan)
        XCTAssertFalse(recognizer.delaysTouchesEnded)
        let nativeGestures: [UIGestureRecognizer] = [UITapGestureRecognizer(), UILongPressGestureRecognizer(), UIPanGestureRecognizer()]
        for other in nativeGestures {
            XCTAssertFalse(recognizer.canPrevent(other))
            XCTAssertFalse(recognizer.canBePrevented(by: other))
        }
    }

    func testOnlyTouchesInsideTheObservedCardUpdateItsAnchor() {
        let observer = TouchMenuTouchObserver(frame: CGRect(x: 100, y: 200, width: 160, height: 286))
        var points: [CGPoint] = []
        observer.record = { points.append($0) }
        observer.recordIfInside(CGPoint(x: 24, y: 48))
        observer.recordIfInside(CGPoint(x: -10, y: 48))
        observer.recordIfInside(CGPoint(x: 180, y: 48))
        observer.recordIfInside(CGPoint(x: 24, y: 300))
        XCTAssertEqual(points, [CGPoint(x: 24, y: 48)])
    }

    func testLeavingTheWindowDetachesOnlyTheOwnedObserver() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let native = UIPanGestureRecognizer()
        window.addGestureRecognizer(native)
        let observer = TouchMenuTouchObserver(frame: CGRect(x: 16, y: 100, width: 160, height: 286))
        window.addSubview(observer)
        let recognizer = try XCTUnwrap(observer.recognizer)
        XCTAssertTrue(recognizer.view === window)
        observer.removeFromSuperview()
        XCTAssertNil(observer.recognizer)
        XCTAssertNil(recognizer.view)
        XCTAssertTrue(native.view === window)
    }
}
