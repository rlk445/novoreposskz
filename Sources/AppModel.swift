import SwiftUI

final class AppModel: ObservableObject {
    let tracker = HandTracker()
    let motion = MotionController()
    let audio = AudioManager()
    let menu = MenuModel()
    let pointer = PointerModel()
    weak var renderer: Renderer?

    @Published var gyroEnabled = true {
        didSet { motion.enabled = gyroEnabled }
    }
    @Published var showCamera = true
    @Published var renderInfo = "renderer: iniciando…"
    private var started = false

    init() {
        menu.app = self
        applyPrefs()
    }

    /// Aplica as preferências do menu nos módulos de áudio e de mãos.
    func applyPrefs() {
        audio.sfxEnabled = menu.sounds
        audio.hoverEnabled = menu.hoverSounds
        audio.envSoundsEnabled = menu.envSounds
        audio.volume = Float(menu.volume)
        tracker.handsEnabled = menu.handTracking
    }

    func start() {
        if started { return }
        started = true
        motion.start()
        tracker.start()
        menu.startMonitoring()
    }

    func recenter() {
        renderer?.recenter()
    }
}
