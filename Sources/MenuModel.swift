import SwiftUI
import UIKit
import Network

enum MenuPage: Hashable {
    case quick, settings, environments, system, personal, hands, access, storage, about

    var title: String {
        switch self {
        case .quick: return "Configurações rápidas"
        case .settings: return "Configurações"
        case .environments: return "Ambientes"
        case .system: return "Sistema"
        case .personal: return "Personalização"
        case .hands: return "Mãos e Controles"
        case .access: return "Acessibilidade"
        case .storage: return "Armazenamento"
        case .about: return "Sobre"
        }
    }
}

struct PointerDot: Identifiable {
    let id: String
    let point: CGPoint
    let pinching: Bool
}

/// Posição dos cursores das mãos na tela. Fica separado do menu para que só o cursor redesenhe a cada quadro.
final class PointerModel: ObservableObject {
    @Published var dots: [PointerDot] = []
}

/// O que uma pinça começou a fazer (decidido no instante em que a pinça fecha).
enum PressKind {
    case scene                       // arrastar o cenário
    case blocked                     // pinça sobre o painel, sem efeito
    case slider(String)              // arrastar um controle deslizante (id bruto)
    case scroll                      // rolar a lista
    case grab                        // mover o menu
    case pendingTap(String, CGPoint) // botão dentro da lista: vira clique só se não arrastar
}

struct EnvInfo {
    let id: String
    let name: String
    let grad: Int
}

final class MenuModel: ObservableObject {
    /// Os 7 ambientes do shell original (ENV_IDS / ENV_NAMES).
    static let environments: [EnvInfo] = [
        EnvInfo(id: "winterlodge", name: "Winter Lodge", grad: 1),
        EnvInfo(id: "desert", name: "Desert Terrace", grad: 0),
        EnvInfo(id: "bubbles", name: "Bubbles", grad: 2),
        EnvInfo(id: "ryokan", name: "Ryokan Retreat", grad: 3),
        EnvInfo(id: "dome", name: "Quest Dome", grad: 4),
        EnvInfo(id: "spacestation", name: "Space Station", grad: 5),
        EnvInfo(id: "cybercity", name: "Cyber City", grad: 8)
    ]

    static func isAvailable(_ id: String) -> Bool {
        return Bundle.main.url(forResource: "scene", withExtension: "bin", subdirectory: id) != nil
    }

    static func envName(_ id: String) -> String {
        return environments.first(where: { $0.id == id })?.name ?? id
    }

    weak var app: AppModel?

    // estado de navegação
    @Published var isOpen = false
    @Published var stack: [MenuPage] = []
    @Published var hoverId: String?
    @Published var offset: CGSize = .zero
    @Published var scroll: CGFloat = 0
    @Published var toast: String?
    @Published var loadingEnv: String?

    // estado do sistema
    @Published var now = Date()
    @Published var battery = -1
    @Published var charging = false
    @Published var wifi = false

    // preferências (salvas em UserDefaults)
    @Published var themeLight: Bool { didSet { UserDefaults.standard.set(themeLight, forKey: "theme_light") } }
    @Published var night: Bool { didSet { UserDefaults.standard.set(night, forKey: "night") } }
    @Published var sounds: Bool {
        didSet { UserDefaults.standard.set(sounds, forKey: "sounds"); app?.applyPrefs() }
    }
    @Published var envSounds: Bool {
        didSet { UserDefaults.standard.set(envSounds, forKey: "env_sounds"); app?.applyPrefs() }
    }
    @Published var hoverSounds: Bool {
        didSet { UserDefaults.standard.set(hoverSounds, forKey: "hover_sounds"); app?.applyPrefs() }
    }
    @Published var handTracking: Bool {
        didSet { UserDefaults.standard.set(handTracking, forKey: "hand_tracking"); app?.applyPrefs() }
    }
    @Published var volume: Double {
        didSet { UserDefaults.standard.set(volume, forKey: "volume"); app?.applyPrefs() }
    }
    @Published var textScaleIdx: Int { didSet { UserDefaults.standard.set(textScaleIdx, forKey: "text_scale") } }
    @Published var homeEnv: String { didSet { UserDefaults.standard.set(homeEnv, forKey: "home_env") } }
    @Published var brightness: Double

    // posições dos alvos (preenchido pelo SwiftUI; não precisa redesenhar nada)
    var frames: [String: CGRect] = [:]
    var contentHeight: CGFloat = 0
    var viewportHeight: CGFloat = 0

    private var dragBase: CGSize?
    private var touchScrollBase: CGFloat?
    private var toastWork: DispatchWorkItem?
    private var timer: Timer?
    private var monitoring = false
    private let pathMonitor = NWPathMonitor()

    init() {
        let d = UserDefaults.standard
        func flag(_ key: String, _ def: Bool) -> Bool {
            return d.object(forKey: key) == nil ? def : d.bool(forKey: key)
        }
        themeLight = flag("theme_light", false)
        night = flag("night", false)
        sounds = flag("sounds", true)
        envSounds = flag("env_sounds", true)
        hoverSounds = flag("hover_sounds", true)
        handTracking = flag("hand_tracking", true)
        volume = d.object(forKey: "volume") == nil ? 0.8 : d.double(forKey: "volume")
        textScaleIdx = d.integer(forKey: "text_scale")
        homeEnv = d.string(forKey: "home_env") ?? "desert"
        brightness = Double(UIScreen.main.brightness)
    }

    // MARK: - aparência

    var theme: Theme { return themeLight ? Theme.light : Theme.dark }

    var ts: CGFloat {
        let scales: [CGFloat] = [1.0, 1.15, 1.3]
        return scales[max(0, min(textScaleIdx, scales.count - 1))]
    }

    // MARK: - status do sistema

    func startMonitoring() {
        if monitoring { return }
        monitoring = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        refreshStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.refreshStatus()
        }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied && path.usesInterfaceType(.wifi)
            DispatchQueue.main.async { self?.wifi = ok }
        }
        pathMonitor.start(queue: DispatchQueue(label: "metulas.net"))
    }

    private func refreshStatus() {
        now = Date()
        let level = UIDevice.current.batteryLevel
        battery = level < 0 ? -1 : Int((level * 100).rounded())
        let st = UIDevice.current.batteryState
        charging = (st == .charging || st == .full)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var timeText: String { return MenuModel.timeFormatter.string(from: now) }
    var dateText: String { return MenuModel.dateFormatter.string(from: now) }

    var batteryText: String {
        if battery < 0 { return "--" }
        return charging ? "\(battery)% ⚡" : "\(battery)%"
    }

    var batterySymbol: String {
        if battery < 0 { return "battery.100" }
        if battery < 15 { return "battery.0" }
        if battery < 60 { return "battery.25" }
        return "battery.100"
    }

    var storageText: String {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        if let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]),
           let free = v.volumeAvailableCapacityForImportantUsage,
           let total = v.volumeTotalCapacity {
            return String(format: "%.2f GB livres de %.2f GB", Double(free) / 1e9, Double(total) / 1e9)
        }
        return "indisponível"
    }

    // MARK: - navegação

    func toggleMenu() {
        if isOpen {
            isOpen = false
            stack = []
        } else {
            isOpen = true
        }
        scroll = 0
    }

    func show(_ page: MenuPage) {
        if stack == [page] {
            stack = []
        } else {
            stack = [page]
        }
        scroll = 0
        isOpen = true
    }

    func push(_ page: MenuPage) {
        stack.append(page)
        scroll = 0
    }

    func back() {
        if !stack.isEmpty { stack.removeLast() }
        scroll = 0
    }

    private func pushCard(_ key: String) {
        switch key {
        case "system": push(.system)
        case "personal": push(.personal)
        case "hands": push(.hands)
        case "access": push(.access)
        case "storage": push(.storage)
        case "about": push(.about)
        case "envs": push(.environments)
        default: break
        }
    }

    func showToast(_ text: String) {
        toast = text
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.toast = nil }
        toastWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4, execute: work)
    }

    // MARK: - ações (toque ou pinça passam pelo mesmo caminho)

    /// `rawId` é o id do alvo: "b:acao" ou "s:b:acao" (botão dentro da lista rolável).
    func activate(_ rawId: String) {
        var id = rawId
        if id.hasPrefix("s:") { id.removeFirst(2) }
        guard id.hasPrefix("b:") else { return }
        let a = String(id.dropFirst(2))
        app?.audio.play("sfx_press")
        switch a {
        case "toggle": toggleMenu()
        case "quick": show(.quick)
        case "envs": show(.environments)
        case "settings": show(.settings)
        case "about": show(.about)
        case "back": back()
        case "close":
            stack = []
            scroll = 0
        case "reset":
            app?.recenter()
            showToast("Vista centralizada")
        case "tog:camera": app?.showCamera.toggle()
        case "tog:gyro": app?.gyroEnabled.toggle()
        case "tog:night": night.toggle()
        case "tog:sounds": sounds.toggle()
        case "tog:envsounds": envSounds.toggle()
        case "tog:hover": hoverSounds.toggle()
        case "tog:hands": handTracking.toggle()
        case "theme:dark": themeLight = false
        case "theme:light": themeLight = true
        case "wifi": showToast(wifi ? "Wi-Fi conectado" : "Wi-Fi desconectado")
        case "opensettings":
            if let u = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(u)
            }
        default:
            if a.hasPrefix("card:") {
                pushCard(String(a.dropFirst(5)))
            } else if a.hasPrefix("env:") {
                selectEnv(String(a.dropFirst(4)))
            } else if a.hasPrefix("text:") {
                textScaleIdx = Int(a.dropFirst(5)) ?? 0
            }
        }
    }

    func selectEnv(_ id: String) {
        if loadingEnv != nil { return }
        if id == homeEnv { return }
        if !MenuModel.isAvailable(id) {
            showToast("Esse ambiente não está incluído no app")
            return
        }
        guard let r = app?.renderer else { return }
        loadingEnv = id
        r.switchEnvironment(id) { [weak self] ok, message in
            guard let self = self else { return }
            self.loadingEnv = nil
            if ok {
                self.homeEnv = id
                self.app?.audio.setEnvironment(id)
                self.showToast(MenuModel.envName(id))
            } else {
                self.showToast(message)
            }
        }
    }

    func applySlider(_ name: String, _ fraction: Double) {
        let f = min(max(fraction, 0), 1)
        switch name {
        case "sl:volume":
            volume = f
        case "sl:brightness":
            let v = max(0.05, f)
            brightness = v
            UIScreen.main.brightness = CGFloat(v)
        default:
            break
        }
    }

    // MARK: - rolagem e arrasto do menu (toque)

    var maxScroll: CGFloat { return max(0, contentHeight - viewportHeight) }

    func scrollBy(_ dy: CGFloat) {
        scroll = min(max(scroll + dy, 0), maxScroll)
    }

    func clampScroll() {
        let m = maxScroll
        if scroll > m { scroll = m }
    }

    func touchScroll(_ translation: CGFloat) {
        if touchScrollBase == nil { touchScrollBase = scroll }
        scroll = min(max((touchScrollBase ?? 0) - translation, 0), maxScroll)
    }

    func endTouchScroll() { touchScrollBase = nil }

    private func clampOffset(_ s: CGSize) -> CGSize {
        return CGSize(width: min(max(s.width, -140), 140), height: min(max(s.height, -320), 60))
    }

    func touchDragMenu(_ translation: CGSize) {
        if dragBase == nil { dragBase = offset }
        let b = dragBase ?? .zero
        offset = clampOffset(CGSize(width: b.width + translation.width, height: b.height + translation.height))
    }

    func endTouchDragMenu() { dragBase = nil }

    // MARK: - entrada por pinça

    func hitTest(_ p: CGPoint) -> String? {
        let viewport = frames["p:scroll"]
        var best: String?
        var bestArea = CGFloat.greatestFiniteMagnitude
        for (id, r) in frames where r.contains(p) {
            if id.hasPrefix("s:") {
                guard let v = viewport, v.contains(p) else { continue }
            }
            let area = r.width * r.height
            if area < bestArea {
                bestArea = area
                best = id
            }
        }
        return best
    }

    func setHover(_ p: CGPoint?) {
        var found: String?
        if let p = p, let id = hitTest(p) {
            let n = id.hasPrefix("s:") ? String(id.dropFirst(2)) : id
            if n.hasPrefix("b:") || n.hasPrefix("sl:") || n == "g:grab" { found = id }
        }
        if found != hoverId {
            hoverId = found
            if found != nil { app?.audio.play("sfx_hover", hover: true) }
        }
    }

    func pressBegan(at p: CGPoint) -> PressKind {
        guard let id = hitTest(p) else { return .scene }
        let scrolled = id.hasPrefix("s:")
        let n = scrolled ? String(id.dropFirst(2)) : id
        if n.hasPrefix("b:") {
            if scrolled { return .pendingTap(id, p) }
            activate(id)
            return .blocked
        }
        if n.hasPrefix("sl:") {
            setSlider(id, at: p)
            return .slider(id)
        }
        if n == "g:grab" { return .grab }
        if id == "p:scroll" { return .scroll }
        return .blocked
    }

    func pressMoved(_ kind: PressKind, to p: CGPoint, delta: CGPoint) -> PressKind {
        switch kind {
        case .slider(let id):
            setSlider(id, at: p)
        case .scroll:
            scrollBy(-delta.y)
        case .grab:
            offset = clampOffset(CGSize(width: offset.width + delta.x, height: offset.height + delta.y))
        case .pendingTap(_, let start):
            let dx = p.x - start.x
            let dy = p.y - start.y
            if sqrt(dx * dx + dy * dy) > 16 {
                scrollBy(-delta.y)
                return .scroll
            }
        default:
            break
        }
        return kind
    }

    func pressEnded(_ kind: PressKind) {
        if case .pendingTap(let id, _) = kind { activate(id) }
    }

    private func setSlider(_ rawId: String, at p: CGPoint) {
        guard let r = frames[rawId], r.width > 1 else { return }
        let f = Double((p.x - r.minX) / r.width)
        applySlider(rawId.hasPrefix("s:") ? String(rawId.dropFirst(2)) : rawId, f)
    }
}
