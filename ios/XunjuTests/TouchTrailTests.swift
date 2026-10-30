import SwiftUI
import UIKit
import XCTest
@testable import Xunju

@MainActor
final class TouchTrailTests: XCTestCase {
    func testPreferenceDefaultsOffAndPersistsBothChoices() {
        let name = "TouchTrailTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        XCTAssertFalse(TouchTrailPreference.defaultValue)
        XCTAssertFalse(defaults.bool(forKey: TouchTrailPreference.key))
        defaults.set(true, forKey: TouchTrailPreference.key)
        XCTAssertTrue(UserDefaults(suiteName: name)!.bool(forKey: TouchTrailPreference.key))
        defaults.set(false, forKey: TouchTrailPreference.key)
        XCTAssertFalse(UserDefaults(suiteName: name)!.bool(forKey: TouchTrailPreference.key))
    }

    func testCanvasBoundsHistoryAndKeepsTouchesIndependent() throws {
        let canvas = TouchTrailCanvas(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let first = NSObject()
        let second = NSObject()
        for x in 0..<100 { canvas.update(ObjectIdentifier(first), at: CGPoint(x: x, y: 100)) }
        canvas.update(ObjectIdentifier(second), at: CGPoint(x: 20, y: 40))
        let trail = try XCTUnwrap(canvas.trails[ObjectIdentifier(first)])
        XCTAssertEqual(trail.points.count, TouchTrailCanvas.maximumPoints)
        XCTAssertEqual(trail.points.last, CGPoint(x: 99, y: 100))
        XCTAssertEqual(trail.circle.path?.boundingBox, CGRect(x: 83, y: 84, width: 32, height: 32))
        canvas.finish(ObjectIdentifier(first))
        XCTAssertEqual(canvas.trails.count, 1)
        XCTAssertNotNil(canvas.trails[ObjectIdentifier(second)])
        canvas.clear()
        XCTAssertTrue(canvas.trails.isEmpty)
        XCTAssertTrue(canvas.layer.sublayers?.isEmpty != false)
    }

    func testRecognizerCannotCancelDelayOrPreventNativeGestures() {
        let canvas = TouchTrailCanvas()
        let recognizer = TouchTrailRecognizer(canvas: canvas)
        let native = UIPanGestureRecognizer()
        XCTAssertFalse(recognizer.cancelsTouchesInView)
        XCTAssertFalse(recognizer.delaysTouchesBegan)
        XCTAssertFalse(recognizer.delaysTouchesEnded)
        XCTAssertFalse(recognizer.canPrevent(native))
        XCTAssertFalse(recognizer.canBePrevented(by: native))
        XCTAssertFalse(canvas.isUserInteractionEnabled)
        XCTAssertTrue(canvas.accessibilityElementsHidden)
    }

    func testTurningOffImmediatelyDetachesAndClearsOnlyOwnedLayers() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let native = UIPanGestureRecognizer()
        window.addGestureRecognizer(native)
        let observer = TouchTrailObserverView()
        window.addSubview(observer)
        XCTAssertNil(observer.recognizer)
        observer.configure(isEnabled: true)
        let canvas = try XCTUnwrap(observer.canvas)
        let recognizer = try XCTUnwrap(observer.recognizer)
        XCTAssertTrue(recognizer.view === window)
        XCTAssertEqual(canvas.frame, window.bounds)
        let touch = NSObject()
        canvas.update(ObjectIdentifier(touch), at: CGPoint(x: 30, y: 60))
        observer.configure(isEnabled: false)
        XCTAssertNil(observer.canvas)
        XCTAssertNil(recognizer.view)
        XCTAssertNil(canvas.superview)
        XCTAssertTrue(canvas.trails.isEmpty)
        XCTAssertTrue(canvas.layer.sublayers?.isEmpty != false)
        XCTAssertTrue(window.gestureRecognizers?.contains(native) == true)
    }

    func testRepeatedEnableAndWindowMigrationDoNotDuplicateObservers() throws {
        let firstWindow = UIWindow()
        let secondWindow = UIWindow()
        let observer = TouchTrailObserverView()
        firstWindow.addSubview(observer)
        observer.configure(isEnabled: true)
        let oldRecognizer = try XCTUnwrap(observer.recognizer)
        observer.configure(isEnabled: true)
        XCTAssertTrue(observer.recognizer === oldRecognizer)
        secondWindow.addSubview(observer)
        XCTAssertNil(oldRecognizer.view)
        XCTAssertTrue(observer.recognizer?.view === secondWindow)
        let touch = NSObject()
        observer.canvas?.update(ObjectIdentifier(touch), at: .zero)
        oldRecognizer.reset()
        XCTAssertEqual(observer.canvas?.trails.count, 1)
        observer.removeFromSuperview()
        XCTAssertNil(observer.recognizer)
        XCTAssertNil(observer.canvas)
    }

    func testLosingActivityClearsHeldAndFadingTouches() throws {
        let window = UIWindow()
        let observer = TouchTrailObserverView()
        window.addSubview(observer)
        observer.configure(isEnabled: true)
        let canvas = try XCTUnwrap(observer.canvas)
        let touch = NSObject()
        canvas.update(ObjectIdentifier(touch), at: .zero)
        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        XCTAssertTrue(canvas.trails.isEmpty)
        XCTAssertTrue(canvas.layer.sublayers?.isEmpty != false)
        XCTAssertTrue(observer.recognizer?.isEnabled == true)
        observer.stopObserving()
    }

    func testDuplicateSamplesDoNotGrowAndFinishClearsActiveTouches() throws {
        let canvas = TouchTrailCanvas(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let touch = NSObject()
        canvas.update(ObjectIdentifier(touch), at: CGPoint(x: 100, y: 160))
        canvas.update(ObjectIdentifier(touch), at: CGPoint(x: 100, y: 160))
        let trail = try XCTUnwrap(canvas.trails[ObjectIdentifier(touch)])
        XCTAssertEqual(trail.points.count, 1)
        XCTAssertNotNil(trail.circle.path)
        canvas.finishActiveTouches()
        XCTAssertTrue(canvas.trails.isEmpty)
        XCTAssertEqual(trail.circle.opacity, 0)
        XCTAssertEqual(trail.circle.animation(forKey: "touch-end")?.duration, TouchTrailCanvas.fadeDuration)
        canvas.clear()
        XCTAssertTrue(canvas.layer.sublayers?.isEmpty != false)
    }

    func testInheritedPreferenceStoreEnablesAndDisablesMountedPresentation() async throws {
        let suite = "TouchTrailPresentationTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKeyWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 300, height: 500)
        window.rootViewController = UIHostingController(rootView:
            TouchTrailPresentation().defaultAppStorage(defaults))
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
            defaults.removePersistentDomain(forName: suite)
        }
        window.layoutIfNeeded()
        let mounted = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { self.touchObserver(in: window) != nil }
        }, object: nil)
        mounted.expectationDescription = "Actual representable observer is mounted in a connected scene"
        await fulfillment(of: [mounted], timeout: 3)
        let observer = try XCTUnwrap(touchObserver(in: window))
        XCTAssertTrue(observer.window === window)
        XCTAssertFalse(window.subviews.contains { $0 is TouchTrailCanvas })
        defaults.set(true, forKey: TouchTrailPreference.key)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { window.subviews.contains { $0 is TouchTrailCanvas } }
        }, object: nil)
        enabled.expectationDescription = "Preference change attaches the actual touch canvas"
        await fulfillment(of: [enabled], timeout: 3)
        defaults.set(false, forKey: TouchTrailPreference.key)
        let disabled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !window.subviews.contains { $0 is TouchTrailCanvas } }
        }, object: nil)
        disabled.expectationDescription = "Turning the preference off removes the touch canvas"
        await fulfillment(of: [disabled], timeout: 3)
    }

    private func touchObserver(in view: UIView) -> TouchTrailObserverView? {
        if let observer = view as? TouchTrailObserverView { return observer }
        for child in view.subviews {
            if let observer = touchObserver(in: child) { return observer }
        }
        return nil
    }

    #if DEBUG
    func testOnlyExplicitBusinessUUIDIsolatesPreferences() {
        let id = UUID()
        let arguments = ["--business-test", id.uuidString]
        let defaults = TouchTrailPreference.defaults(arguments: arguments)
        defer { defaults.removePersistentDomain(forName: "TouchTrailBusinessTests." + id.uuidString) }
        defaults.set(true, forKey: TouchTrailPreference.key)
        XCTAssertTrue(TouchTrailPreference.defaults(arguments: arguments).bool(forKey: TouchTrailPreference.key))
        XCTAssertFalse(TouchTrailPreference.defaults(arguments: ["--business-test", UUID().uuidString]).bool(forKey: TouchTrailPreference.key))
        for arguments in [[], ["--business-test"], ["--business-test", "invalid"], ["--touch-trail-review", id.uuidString]] {
            XCTAssertTrue(TouchTrailPreference.defaults(arguments: arguments) === UserDefaults.standard)
        }
    }
    #endif
}
