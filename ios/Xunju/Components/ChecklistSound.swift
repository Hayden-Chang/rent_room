import AVFAudio

enum ChecklistSoundPreference {
    static let key = "feedback.checklist-sound.enabled"
    static let defaultValue = true

    static func defaults(arguments: [String] = ProcessInfo.processInfo.arguments) -> UserDefaults {
        #if DEBUG
        if let index = arguments.firstIndex(of: "--business-test"), arguments.indices.contains(index + 1),
           let id = UUID(uuidString: arguments[index + 1]) {
            return UserDefaults(suiteName: "ChecklistSoundBusinessTests." + id.uuidString)!
        }
        #endif
        return .standard
    }

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }
}

enum ChecklistSound: String, CaseIterable {
    case problem, positive

    var resourceURL: URL? { Bundle.main.url(forResource: "checklist-" + rawValue, withExtension: "wav") }

    @MainActor func play() { ChecklistSoundPlayer.shared.play(self) }
    @MainActor static func stop() { ChecklistSoundPlayer.shared.stop() }
}

@MainActor protocol ChecklistAudioPlayback: AnyObject {
    var currentTime: TimeInterval { get set }
    func play() -> Bool
    func stop()
}
extension AVAudioPlayer: ChecklistAudioPlayback {}

@MainActor final class ChecklistSoundPlayer {
    static let shared = ChecklistSoundPlayer()
    private let defaults: UserDefaults
    private let makePlayer: (URL) throws -> any ChecklistAudioPlayback
    private let configureSession: () throws -> Void
    private var players: [ChecklistSound: any ChecklistAudioPlayback] = [:]

    init(defaults: UserDefaults = ChecklistSoundPreference.defaults(),
         makePlayer: @escaping (URL) throws -> any ChecklistAudioPlayback = { try AVAudioPlayer(contentsOf: $0) },
         configureSession: @escaping () throws -> Void = {
             // Optional UI sounds follow Silent mode and mix with the user's music.
             try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
         }) {
        self.defaults = defaults; self.makePlayer = makePlayer; self.configureSession = configureSession
    }

    @discardableResult
    func play(_ sound: ChecklistSound) -> Bool {
        guard ChecklistSoundPreference.isEnabled(in: defaults) else { stop(); return false }
        do {
            try configureSession()
            if players[sound] == nil, let url = sound.resourceURL {
                players[sound] = try makePlayer(url)
            }
            // Rapid choices replace the previous cue instead of stacking sounds.
            stop()
            return players[sound]?.play() ?? false
        } catch {
            // Audio is supplementary; an unavailable route must not block an answer.
            return false
        }
    }

    func stop() {
        for player in players.values { player.stop(); player.currentTime = 0 }
    }
}
