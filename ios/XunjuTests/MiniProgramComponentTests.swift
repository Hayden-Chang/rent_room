import XCTest
@testable import Xunju

@MainActor final class MiniProgramComponentTests: XCTestCase {
    func testReviewRequiresExplicitKnownRoute() {
        XCTAssertNil(MPReviewRoute.parse(["app"]))
        XCTAssertNil(MPReviewRoute.parse(["--component-review", "homes"]))
        XCTAssertNil(MPReviewRoute.parse(["--component-review", "parity-unknown"]))
        XCTAssertNil(MPReviewRoute.parse(["--component-review"]))
        XCTAssertEqual(MPReviewRoute.parse(["app", "--component-review", "parity-detail"]), .detail)
        XCTAssertEqual(MPReviewRoute.state(["--parity-state", "readonly"]), "readonly")
        for route in MPReviewRoute.allCases {
            XCTAssertEqual(MPReviewRoute.parse(["--component-review", "parity-" + route.rawValue]), route)
        }
    }

    func testSwipeFollowsFingerAndHandlesReverseAndVerticalScroll() {
        let coordinator = MPSwipeCoordinator()
        coordinator.move("one", x: -35, y: 2, time: 1)
        XCTAssertEqual(coordinator.offset("one"), -35)
        coordinator.move("one", x: -80, y: 3, time: 1.08)
        XCTAssertEqual(coordinator.offset("one"), -80)
        coordinator.finish("one", x: -80, y: 3, time: 1.12)
        XCTAssertEqual(coordinator.active, "one")
        coordinator.move("two", x: -30, y: 1, time: 2)
        XCTAssertEqual(coordinator.offset("one"), 0, "Only one tray may be active")
        coordinator.finish("two", x: -30, y: 1, time: 2.2)
        XCTAssertEqual(coordinator.active, "two")
        coordinator.move("two", x: 30, y: 0, time: 3)
        coordinator.finish("two", x: 35, y: 0, time: 3.08)
        XCTAssertNil(coordinator.active)
        coordinator.reveal("one")
        coordinator.move("one", x: 3, y: 24, time: 4)
        coordinator.finish("one", x: 3, y: 48, time: 4.08)
        XCTAssertNil(coordinator.active)
        coordinator.reveal("one")
        XCTAssertTrue(coordinator.consumeTap())
        XCTAssertFalse(coordinator.consumeTap())
    }

    func testSwipeFastShortFlickAndClampedTravel() {
        var motion = MPSwipeMotion()
        motion.sample(x: -8, y: 0, time: 1)
        XCTAssertTrue(motion.finish(x: -18, y: 0, time: 1.02))
        var overshoot = MPSwipeMotion()
        overshoot.sample(x: -300, y: 1, time: 1)
        XCTAssertEqual(overshoot.offset, -132)
        var ambiguous = MPSwipeMotion()
        XCTAssertFalse(ambiguous.finish(x: -6, y: 5, time: 1))
    }

    func testImportRequiresExplicitConflictChoiceOnlyForSelectedHouses() {
        let items = MPReviewFixtures.transfers
        XCTAssertFalse(MPTransferSelection.ready(items: items, selected: [], modes: [:], exporting: false))
        XCTAssertFalse(MPTransferSelection.ready(items: items, selected: ["one", "two"], modes: [:], exporting: false))
        XCTAssertTrue(MPTransferSelection.ready(items: items, selected: ["one", "two"], modes: ["one": .copy], exporting: false))
        XCTAssertTrue(MPTransferSelection.ready(items: items, selected: ["one"], modes: ["one": .replace], exporting: false))
        XCTAssertTrue(MPTransferSelection.ready(items: items, selected: ["two"], modes: [:], exporting: false))
        XCTAssertTrue(MPTransferSelection.ready(items: items, selected: ["one", "two"], modes: [:], exporting: true))
        XCTAssertFalse(MPTransferSelection.ready(items: [], selected: ["stale"], modes: [:], exporting: true))
    }
}
