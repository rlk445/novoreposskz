import AVFoundation

final class AudioManager {
    private var ambient: AVAudioPlayer?
    private var effects: [String: AVAudioPlayer] = [:]

    func startAmbient() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        if let url = Bundle.main.url(forResource: "ambient", withExtension: "m4a", subdirectory: "desert") {
            ambient = try? AVAudioPlayer(contentsOf: url)
            ambient?.numberOfLoops = -1
            ambient?.volume = 0.6
            ambient?.prepareToPlay()
            ambient?.play()
        }
    }

    func play(_ name: String) {
        if effects[name] == nil {
            if let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "sfx") {
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.prepareToPlay()
                effects[name] = p
            }
        }
        if let p = effects[name] {
            p.currentTime = 0
            p.play()
        }
    }
}
