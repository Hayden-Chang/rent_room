import XCTest
@testable import Xunju

@MainActor final class ChecklistSoundPreferenceTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "ChecklistSoundPreferenceTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return defaults
    }

    func testPreferenceDefaultsOnPersistsAndKeepsTestScopesSeparate() {
        let id = UUID().uuidString
        let arguments = ["--business-test", id]
        let first = ChecklistSoundPreference.defaults(arguments: arguments)
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: "ChecklistSoundBusinessTests." + id) }
        XCTAssertTrue(ChecklistSoundPreference.isEnabled(in: first))
        first.set(false, forKey: ChecklistSoundPreference.key)
        let reopened = ChecklistSoundPreference.defaults(arguments: arguments)
        XCTAssertFalse(ChecklistSoundPreference.isEnabled(in: reopened))
        XCTAssertTrue(ChecklistSoundPreference.isEnabled(in: defaults()), "Other installations/scopes keep their default")
        reopened.set(true, forKey: ChecklistSoundPreference.key)
        XCTAssertTrue(ChecklistSoundPreference.isEnabled(in: first))
        XCTAssertTrue(ChecklistSoundPreference.defaults(arguments: []) === UserDefaults.standard)
        XCTAssertTrue(ChecklistSoundPreference.defaults(arguments: ["--business-test", "invalid"]) === UserDefaults.standard)
        XCTAssertTrue(ChecklistSoundPreference.defaults(arguments: ["--business-test"]) === UserDefaults.standard)
    }

    func testMuteStopsPlaybackSuppressesBothCuesAndCanResume() {
        let defaults = defaults(), positive = AudioProbe(), problem = AudioProbe()
        var prepared = 0, created = 0
        let player = ChecklistSoundPlayer(defaults: defaults, makePlayer: { url in
            created += 1
            return url.lastPathComponent == "checklist-positive.wav" ? positive : problem
        }, configureSession: { prepared += 1 })
        XCTAssertTrue(player.play(.positive))
        XCTAssertTrue(positive.playing)
        positive.currentTime = 0.2
        defaults.set(false, forKey: ChecklistSoundPreference.key)
        player.stop()
        XCTAssertFalse(positive.playing)
        XCTAssertEqual(positive.currentTime, 0)
        XCTAssertFalse(player.play(.positive))
        XCTAssertFalse(player.play(.problem))
        XCTAssertEqual(positive.plays, 1)
        XCTAssertEqual(problem.plays, 0)
        XCTAssertEqual(prepared, 1, "Muting does not activate an audio session")
        XCTAssertEqual(created, 1, "Muting does not load another sound")
        defaults.set(true, forKey: ChecklistSoundPreference.key)
        XCTAssertTrue(player.play(.problem))
        XCTAssertTrue(problem.playing)
        XCTAssertTrue(player.play(.positive))
        XCTAssertFalse(problem.playing, "Rapid choices replace the previous cue")
        XCTAssertEqual(positive.plays, 2)
        XCTAssertEqual(problem.plays, 1)
    }

    func testUnavailableAudioDoesNotThrowOrRetryWhenMuted() {
        enum Failure: Error { case unavailable }
        let defaults = defaults()
        var attempts = 0
        let player = ChecklistSoundPlayer(defaults: defaults, makePlayer: { _ in
            attempts += 1; throw Failure.unavailable
        }, configureSession: {})
        XCTAssertFalse(player.play(.positive))
        defaults.set(false, forKey: ChecklistSoundPreference.key)
        XCTAssertFalse(player.play(.problem))
        XCTAssertEqual(attempts, 1)
    }
}

@MainActor private final class AudioProbe: ChecklistAudioPlayback {
    var currentTime: TimeInterval = 0
    var playing = false
    var plays = 0
    func play() -> Bool { plays += 1; playing = true; return true }
    func stop() { playing = false }
}
