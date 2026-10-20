import XCTest
@testable import Xunju

@MainActor private final class PathDriverFixture: NetworkPathDriver {
    let started: XCTestExpectation
    private(set) var stopped = false
    private var update: (@Sendable (Bool, Bool) -> Void)?
    init(_ started: XCTestExpectation) { self.started = started }
    func start(_ update: @escaping @Sendable (Bool, Bool) -> Void) { self.update = update; started.fulfill() }
    func stop() { stopped = true }
    func emit(available: Bool, wifi: Bool) { update?(available, wifi) }
}

@MainActor final class NativeNetworkTests: XCTestCase {
    func testReadinessWaitsForFirstPathAndThenReturnsCachedStatus() async throws {
        let began = expectation(description: "Monitor started"), driver = PathDriverFixture(began), network = NativeNetwork(driver: driver)
        let operation = Task { try await network.ready() }
        let started = await XCTWaiter.fulfillment(of: [began], timeout: 3); XCTAssertEqual(started, .completed)
        XCTAssertNil(network.current)
        driver.emit(available: true, wifi: true)
        let status = try await operation.value, cached = try await network.ready()
        XCTAssertEqual(status, NetworkStatus(available: true, wifi: true, version: 1)); XCTAssertEqual(cached, status)
        network.stop(); XCTAssertTrue(driver.stopped)
    }
    func testCancelledWaiterDoesNotCancelMonitorForSubsequentRetry() async throws {
        let began = expectation(description: "Monitor started"), driver = PathDriverFixture(began), network = NativeNetwork(driver: driver)
        let first = Task { try await network.ready() }
        let started = await XCTWaiter.fulfillment(of: [began], timeout: 3); XCTAssertEqual(started, .completed)
        first.cancel()
        do { _ = try await first.value; XCTFail("Cancelled readiness returned status") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(driver.stopped)
        let second = Task { try await network.ready() }
        driver.emit(available: false, wifi: false)
        let status = try await second.value
        XCTAssertFalse(status.available); XCTAssertFalse(status.wifi)
        network.stop()
    }
    func testLeavingPageStopsMonitorAndResumesOutstandingReadiness() async throws {
        let began = expectation(description: "Monitor started"), driver = PathDriverFixture(began), network = NativeNetwork(driver: driver)
        let operation = Task { try await network.ready() }
        let started = await XCTWaiter.fulfillment(of: [began], timeout: 3); XCTAssertEqual(started, .completed)
        network.stop()
        do { _ = try await operation.value; XCTFail("Stopped monitor returned status") } catch { XCTAssertTrue(error is CancellationError) }
        do { _ = try await network.ready(); XCTFail("Stopped monitor was reused") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(driver.stopped)
    }
}
