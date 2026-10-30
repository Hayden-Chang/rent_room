import AVFAudio

enum ChecklistSound: String, CaseIterable {
    case problem, positive

    var resourceURL: URL? { Bundle.main.url(forResource: "checklist-" + rawValue, withExtension: "wav") }

    @MainActor func play() { ChecklistSoundPlayer.shared.play(self) }
}

@MainActor private final class ChecklistSoundPlayer {
    static let shared = ChecklistSoundPlayer()
    private var players: [ChecklistSound: AVAudioPlayer] = [:]

    func play(_ sound: ChecklistSound) {
        do {
            // Optional UI sounds follow Silent mode and mix with the user's music.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            if players[sound] == nil, let url = sound.resourceURL {
                players[sound] = try AVAudioPlayer(contentsOf: url)
            }
            // Rapid choices replace the previous cue instead of stacking sounds.
            for player in players.values { player.stop(); player.currentTime = 0 }
            players[sound]?.play()
        } catch {
            // Audio is supplementary; an unavailable route must not block an answer.
        }
    }
}
