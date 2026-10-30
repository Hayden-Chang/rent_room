import UIKit
import XCTest
@testable import Xunju

@MainActor final class SwipeGestureTests: XCTestCase {
    func testHorizontalPanExcludesParentScrollingAndOnlyPrioritizesItsScrollPan() throws {
        guard #available(iOS 18, *) else { throw XCTSkip("UIKit gesture bridge requires iOS 18") }
        let delegate = MPHorizontalPan.Coordinator(trace: { _ in }, vertical: {})
        let scroll = UIScrollView()
        let row = UIView()
        scroll.addSubview(row)
        let pan = UIPanGestureRecognizer()
        row.addGestureRecognizer(pan)
        XCTAssertFalse(delegate.gestureRecognizer(pan, shouldRecognizeSimultaneouslyWith: scroll.panGestureRecognizer))
        XCTAssertTrue(delegate.gestureRecognizer(pan, shouldBeRequiredToFailBy: scroll.panGestureRecognizer))

        let unrelated = UIScrollView()
        XCTAssertFalse(delegate.gestureRecognizer(pan, shouldBeRequiredToFailBy: unrelated.panGestureRecognizer))
        let siblingPan = UIPanGestureRecognizer()
        row.addGestureRecognizer(siblingPan)
        XCTAssertFalse(delegate.gestureRecognizer(pan, shouldBeRequiredToFailBy: siblingPan))
        let extraScrollPan = UIPanGestureRecognizer()
        scroll.addGestureRecognizer(extraScrollPan)
        XCTAssertFalse(delegate.gestureRecognizer(pan, shouldBeRequiredToFailBy: extraScrollPan))
    }

    func testVerticalIntentFailsBeforeRecognitionAndClosesActions() throws {
        guard #available(iOS 18, *) else { throw XCTSkip("UIKit gesture bridge requires iOS 18") }
        let coordinator = MPSwipeCoordinator()
        let delegate = MPHorizontalPan.Coordinator(trace: { _ in }, vertical: coordinator.close)
        let pan = VelocityPan()
        for x in [-300.0, 300.0] {
            for y in [-100.0, 100.0] {
                pan.sampleVelocity = CGPoint(x: x, y: y)
                XCTAssertTrue(delegate.gestureRecognizerShouldBegin(pan))
            }
        }
        coordinator.reveal("row")
        pan.sampleVelocity = CGPoint(x: -50, y: 300)
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(pan))
        XCTAssertNil(coordinator.active)
        pan.sampleVelocity = CGPoint(x: -50, y: -300)
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(pan))
        pan.sampleVelocity = CGPoint(x: 0, y: 0)
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(pan))
        pan.sampleVelocity = CGPoint(x: -100, y: 100)
        XCTAssertFalse(delegate.gestureRecognizerShouldBegin(pan))
    }
}

@MainActor private final class VelocityPan: UIPanGestureRecognizer {
    var sampleVelocity = CGPoint.zero
    override func velocity(in view: UIView?) -> CGPoint { sampleVelocity }
}
