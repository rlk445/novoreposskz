import SwiftUI

// MARK: - registro de alvos (posição na tela de cada botão, para a pinça acertar)

struct FrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Registra este elemento como alvo da pinça com o id dado.
    func target(_ id: String) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: FrameKey.self, value: [id: g.frame(in: .global)])
        })
    }

    func hoverFX(_ menu: MenuModel, _ id: String, _ theme: Theme, _ radius: CGFloat = 14) -> some View {
        modifier(HoverFX(menu: menu, id: id, theme: theme, radius: radius))
    }
}

struct HoverFX: ViewModifier {
    @ObservedObject var menu: MenuModel
    let id: String
    let theme: Theme
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: radius)
                .fill(menu.hoverId == id ? theme.hover : Color.clear)
                .allowsHitTesting(false)
        )
    }
}

// MARK: - raiz

struct MenuOverlay: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel

    var body: some View {
        GeometryReader { geo in
            content(geo.size)
        }
        .onPreferenceChange(FrameKey.self) { f in
            menu.frames = f
        }
    }

    private func content(_ size: CGSize) -> some View {
        let w = min(size.width - 20, 380)
        let theme = menu.theme
        return VStack(spacing: 10) {
            Spacer(minLength: 0)
            if let page = menu.stack.last {
                MainPanel(menu: menu, app: app, page: page, theme: theme)
                    .frame(width: w, height: min(size.height * 0.56, 480))
                    .transition(AnyTransition.scale(scale: 0.94).combined(with: .opacity))
            }
            if menu.isOpen {
                VStack(spacing: 6) {
                    DockBar(menu: menu, theme: theme)
                    GrabHandle(menu: menu, theme: theme)
                }
                .frame(width: w)
                .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
            } else {
                OpenButton(menu: menu)
            }
        }
        .padding(.bottom, 34)
        .frame(width: size.width, height: size.height)
        .offset(menu.offset)
        .animation(.easeOut(duration: 0.2), value: menu.stack)
        .animation(.easeOut(duration: 0.2), value: menu.isOpen)
    }
}

// MARK: - botão que abre o menu

struct OpenButton: View {
    @ObservedObject var menu: MenuModel

    var body: some View {
        let hot = menu.hoverId == "b:toggle"
        return Button(action: { menu.activate("b:toggle") }) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(Color.black.opacity(0.55)))
                .overlay(Circle().stroke(Color.white.opacity(hot ? 0.95 : 0.35), lineWidth: hot ? 2 : 1))
        }
        .buttonStyle(PlainButtonStyle())
        .target("b:toggle")
    }
}

// MARK: - dock

struct DockBar: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        VStack(spacing: 6) {
            if let t = menu.toast {
                Text(t)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(theme.text)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
                    .transition(.opacity)
            }
            HStack(spacing: 4) {
                quickChip
                Rectangle().fill(theme.div).frame(width: 1, height: 44)
                DockTile(menu: menu, theme: theme, id: "b:envs", label: "Ambientes", icon: "mountain.2.fill",
                         grad: 2, active: menu.stack.first == .environments)
                DockTile(menu: menu, theme: theme, id: "b:settings", label: "Config.", icon: "gearshape.fill",
                         grad: 5, active: isSettingsOpen)
                DockTile(menu: menu, theme: theme, id: "b:about", label: "Sobre", icon: "info.circle.fill",
                         grad: 8, active: menu.stack.first == .about)
                DockTile(menu: menu, theme: theme, id: "b:toggle", label: "Fechar", icon: "xmark",
                         grad: nil, active: false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 24).fill(theme.panel.opacity(0.96)))
            .target("p:dock")
        }
        .animation(.easeOut(duration: 0.15), value: menu.toast)
    }

    private var isSettingsOpen: Bool {
        guard let first = menu.stack.first else { return false }
        return first == .settings
    }

    private var quickChip: some View {
        Button(action: { menu.activate("b:quick") }) {
            VStack(spacing: 6) {
                Text(menu.timeText)
                    .font(.system(size: 19, weight: .regular))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                HStack(spacing: 6) {
                    Image(systemName: menu.batterySymbol)
                    Image(systemName: menu.wifi ? "wifi" : "wifi.slash")
                }
                .font(.system(size: 15))
                .foregroundColor(theme.text)
            }
            .frame(width: 84, height: 62)
            .background(RoundedRectangle(cornerRadius: 12).fill(menu.stack.first == .quick ? theme.hover : Color.clear))
            .hoverFX(menu, "b:quick", theme, 12)
        }
        .buttonStyle(PlainButtonStyle())
        .target("b:quick")
    }
}

struct DockTile: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let id: String
    let label: String
    let icon: String
    let grad: Int?
    let active: Bool

    var body: some View {
        Button(action: { menu.activate(id) }) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(fillStyle)
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(grad == nil ? theme.text : .white)
                }
                .hoverFX(menu, id, theme, 14)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(theme.sub)
                    .lineLimit(1)
                Capsule()
                    .fill(active ? theme.text : Color.clear)
                    .frame(width: 16, height: 3)
            }
            .frame(width: 58)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }

    private var fillStyle: LinearGradient {
        if let g = grad { return tileGradient(g) }
        return LinearGradient(colors: [theme.card, theme.card], startPoint: .top, endPoint: .bottom)
    }
}

struct GrabHandle: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        let hot = menu.hoverId == "g:grab"
        return Capsule()
            .fill(hot ? Color.white : Color.white.opacity(0.45))
            .frame(width: hot ? 120 : 96, height: 6)
            .frame(width: 180, height: 22)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in menu.touchDragMenu(v.translation) }
                    .onEnded { _ in menu.endTouchDragMenu() }
            )
            .target("g:grab")
    }
}

// MARK: - painel principal

struct MainPanel: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel
    let page: MenuPage
    let theme: Theme

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollPanel(menu: menu) {
                PageContent(menu: menu, app: app, page: page, theme: theme)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(RoundedRectangle(cornerRadius: 24).fill(theme.panel.opacity(0.96)))
        .target("p:main")
    }

    private var header: some View {
        HStack(spacing: 8) {
            if menu.stack.count > 1 {
                roundButton("b:back", "chevron.left")
            }
            Text(page.title)
                .font(.system(size: 18 * menu.ts, weight: .semibold))
                .foregroundColor(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            roundButton("b:close", "xmark")
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
    }

    private func roundButton(_ id: String, _ icon: String) -> some View {
        Button(action: { menu.activate(id) }) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(theme.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(theme.card))
                .overlay(Circle().fill(menu.hoverId == id ? theme.hover : Color.clear))
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

/// Área rolável própria (a pinça precisa controlar o deslocamento).
struct ScrollPanel<Content: View>: View {
    @ObservedObject var menu: MenuModel
    let content: Content

    init(menu: MenuModel, @ViewBuilder content: () -> Content) {
        self.menu = menu
        self.content = content()
    }

    var body: some View {
        GeometryReader { vp in
            content
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: vp.size.width, alignment: .top)
                .background(GeometryReader { g in
                    Color.clear.preference(key: ContentHeightKey.self, value: g.size.height)
                })
                .offset(y: -menu.scroll)
                .frame(width: vp.size.width, height: vp.size.height, alignment: .top)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { v in menu.touchScroll(v.translation.height) }
                        .onEnded { _ in menu.endTouchScroll() }
                )
                .onPreferenceChange(ContentHeightKey.self) { h in
                    let vh = vp.size.height
                    DispatchQueue.main.async {
                        menu.contentHeight = h
                        menu.viewportHeight = vh
                        menu.clampScroll()
                    }
                }
        }
        .target("p:scroll")
    }
}

// MARK: - componentes de linha

struct SwitchShape: View {
    let on: Bool
    let theme: Theme

    var body: some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule().fill(on ? theme.accent : theme.toggleOff).frame(width: 46, height: 26)
            Circle().fill(Color.white).frame(width: 20, height: 20).padding(3)
        }
        .animation(.easeOut(duration: 0.12), value: on)
    }
}

struct SectionTitle: View {
    let text: String
    let theme: Theme
    let scale: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: 13 * scale, weight: .semibold))
            .foregroundColor(theme.sub)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.leading, 4)
    }
}

struct InfoRow: View {
    let theme: Theme
    let scale: CGFloat
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title)
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundColor(theme.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 14 * scale))
                .foregroundColor(theme.sub)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
    }
}

struct ToggleRow: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let action: String
    let title: String
    let subtitle: String
    let isOn: Bool

    var body: some View {
        let s = menu.ts
        let id = "s:" + action
        return Button(action: { menu.activate(id) }) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15 * s, weight: .medium))
                        .foregroundColor(theme.text)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12 * s))
                            .foregroundColor(theme.sub)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                SwitchShape(on: isOn, theme: theme)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
            .hoverFX(menu, id, theme)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

struct ActionRow: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let action: String
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        let s = menu.ts
        let id = "s:" + action
        return Button(action: { menu.activate(id) }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(theme.text)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15 * s, weight: .medium))
                        .foregroundColor(theme.text)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12 * s))
                            .foregroundColor(theme.sub)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.sub)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
            .hoverFX(menu, id, theme)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

struct SliderRow: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let name: String
    let icon: String
    let value: Double

    var body: some View {
        let id = "s:sl:" + name
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(theme.text)
                .frame(width: 28)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.track).frame(height: 8)
                    Capsule().fill(theme.accent)
                        .frame(width: max(8, g.size.width * CGFloat(value)), height: 8)
                    Circle().fill(Color.white)
                        .frame(width: 22, height: 22)
                        .offset(x: max(0, min(g.size.width - 22, g.size.width * CGFloat(value) - 11)))
                }
                .frame(height: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { v in
                        let f = Double(v.location.x / max(g.size.width, 1))
                        menu.applySlider("sl:" + name, f)
                    }
                )
            }
            .frame(height: 30)
            .target(id)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
        .hoverFX(menu, id, theme)
    }
}

struct ChoiceRow: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let title: String
    let options: [(String, String)]   // (ação, rótulo)
    let selected: Int

    var body: some View {
        let s = menu.ts
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15 * s, weight: .medium))
                .foregroundColor(theme.text)
            HStack(spacing: 8) {
                ForEach(0..<options.count, id: \.self) { i in
                    let id = "s:" + options[i].0
                    Button(action: { menu.activate(id) }) {
                        Text(options[i].1)
                            .font(.system(size: 14 * s, weight: .medium))
                            .foregroundColor(i == selected ? Color.white : theme.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(i == selected ? theme.accent : theme.toggleOff))
                            .hoverFX(menu, id, theme, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .target(id)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
    }
}

struct IconToggle: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let action: String
    let icon: String
    let title: String
    let isOn: Bool

    var body: some View {
        let s = menu.ts
        let id = "s:" + action
        return Button(action: { menu.activate(id) }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 13 * s, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .foregroundColor(isOn ? Color.white : theme.text)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 14).fill(isOn ? theme.accent : theme.card))
            .hoverFX(menu, id, theme)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

struct InfoTile: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let action: String
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        let s = menu.ts
        let id = "s:" + action
        return Button(action: { menu.activate(id) }) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(theme.text)
                Text(title)
                    .font(.system(size: 15 * s, weight: .semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 12 * s))
                    .foregroundColor(theme.sub)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
            .hoverFX(menu, id, theme)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

// MARK: - páginas

struct PageContent: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel
    let page: MenuPage
    let theme: Theme

    var body: some View {
        switch page {
        case .quick: QuickPage(menu: menu, app: app, theme: theme)
        case .settings: SettingsPage(menu: menu, theme: theme)
        case .environments: EnvironmentsPage(menu: menu, theme: theme)
        case .system: SystemPage(menu: menu, theme: theme)
        case .personal: PersonalPage(menu: menu, theme: theme)
        case .hands: HandsPage(menu: menu, app: app, tracker: app.tracker, theme: theme)
        case .access: AccessPage(menu: menu, theme: theme)
        case .storage: StoragePage(menu: menu, theme: theme)
        case .about: AboutPage(menu: menu, app: app, tracker: app.tracker, theme: theme)
        }
    }
}

private let twoColumns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

struct QuickPage: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel
    let theme: Theme

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: menu.batterySymbol).font(.system(size: 18))
                Text(menu.batteryText).font(.system(size: 15 * s))
                Spacer()
                Text(menu.dateText).font(.system(size: 15 * s))
            }
            .foregroundColor(theme.text)
            .padding(.horizontal, 4)

            SliderRow(menu: menu, theme: theme, name: "volume",
                      icon: menu.volume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill", value: menu.volume)
            SliderRow(menu: menu, theme: theme, name: "brightness", icon: "sun.max.fill", value: menu.brightness)

            LazyVGrid(columns: twoColumns, spacing: 10) {
                InfoTile(menu: menu, theme: theme, action: "b:wifi", icon: menu.wifi ? "wifi" : "wifi.slash",
                         title: "Wi-Fi", subtitle: menu.wifi ? "Conectado" : "Sem conexão")
                InfoTile(menu: menu, theme: theme, action: "b:card:hands", icon: "hand.raised.fill",
                         title: "Mãos", subtitle: menu.handTracking ? "Rastreio ligado" : "Rastreio desligado")
            }

            LazyVGrid(columns: twoColumns, spacing: 10) {
                IconToggle(menu: menu, theme: theme, action: "b:reset", icon: "scope", title: "Centralizar", isOn: false)
                IconToggle(menu: menu, theme: theme, action: "b:tog:camera", icon: "camera.fill",
                           title: "Câmera", isOn: app.showCamera)
                IconToggle(menu: menu, theme: theme, action: "b:tog:night", icon: "moon.fill",
                           title: "Modo noturno", isOn: menu.night)
                IconToggle(menu: menu, theme: theme, action: "b:tog:sounds", icon: "speaker.wave.2.fill",
                           title: "Sons", isOn: menu.sounds)
                IconToggle(menu: menu, theme: theme, action: "b:tog:hands", icon: "hand.point.up.left.fill",
                           title: "Rastrear mãos", isOn: menu.handTracking)
                IconToggle(menu: menu, theme: theme, action: "b:tog:gyro", icon: "rotate.3d",
                           title: "Giroscópio", isOn: app.gyroEnabled)
            }

            ActionRow(menu: menu, theme: theme, action: "b:settings", title: "Configurações",
                      subtitle: "", icon: "gearshape.fill")
        }
    }
}

struct SettingsPage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        LazyVGrid(columns: twoColumns, spacing: 10) {
            InfoTile(menu: menu, theme: theme, action: "b:card:system", icon: "display",
                     title: "Sistema", subtitle: "Tela, som, data e hora")
            InfoTile(menu: menu, theme: theme, action: "b:card:personal", icon: "paintbrush.fill",
                     title: "Personalização", subtitle: "Ambiente virtual e tema")
            InfoTile(menu: menu, theme: theme, action: "b:card:hands", icon: "hand.raised.fill",
                     title: "Mãos e Controles", subtitle: "Rastreio de mãos e giroscópio")
            InfoTile(menu: menu, theme: theme, action: "b:card:access", icon: "accessibility",
                     title: "Acessibilidade", subtitle: "Tamanho do texto")
            InfoTile(menu: menu, theme: theme, action: "b:card:storage", icon: "internaldrive.fill",
                     title: "Armazenamento", subtitle: menu.storageText)
            InfoTile(menu: menu, theme: theme, action: "b:card:about", icon: "info.circle.fill",
                     title: "Sobre", subtitle: "Versão e diagnóstico")
        }
    }
}

struct EnvironmentsPage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        LazyVGrid(columns: twoColumns, spacing: 10) {
            ForEach(MenuModel.environments, id: \.id) { env in
                EnvTile(menu: menu, theme: theme, env: env)
            }
        }
    }
}

struct EnvTile: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme
    let env: EnvInfo

    var body: some View {
        let s = menu.ts
        let id = "s:b:env:" + env.id
        let available = MenuModel.isAvailable(env.id)
        let active = menu.homeEnv == env.id
        let loading = menu.loadingEnv == env.id
        let status: String = loading ? "Carregando…" : (active ? "Ativo" : (available ? "Disponível" : "Não incluído"))
        return Button(action: { menu.activate(id) }) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tileGradient(env.grad))
                        .frame(height: 78)
                    if loading {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: active ? "checkmark.circle.fill" : "mountain.2.fill")
                            .font(.system(size: 26))
                            .foregroundColor(Color.white.opacity(0.9))
                    }
                }
                Text(env.name)
                    .font(.system(size: 14 * s, weight: .semibold))
                    .foregroundColor(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(status)
                    .font(.system(size: 12 * s))
                    .foregroundColor(active ? theme.accent : theme.sub)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.card))
            .opacity(available ? 1 : 0.55)
            .hoverFX(menu, id, theme)
        }
        .buttonStyle(PlainButtonStyle())
        .target(id)
    }
}

struct SystemPage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            SectionTitle(text: "Tela", theme: theme, scale: s)
            SliderRow(menu: menu, theme: theme, name: "brightness", icon: "sun.max.fill", value: menu.brightness)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:night", title: "Modo noturno",
                      subtitle: "Cores mais quentes para o menu e o ambiente", isOn: menu.night)

            SectionTitle(text: "Som", theme: theme, scale: s)
            SliderRow(menu: menu, theme: theme, name: "volume",
                      icon: menu.volume < 0.01 ? "speaker.slash.fill" : "speaker.wave.2.fill", value: menu.volume)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:sounds", title: "Sons da interface",
                      subtitle: "Cliques e efeitos dos botões", isOn: menu.sounds)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:envsounds", title: "Sons do ambiente",
                      subtitle: "Toca o som de fundo do seu ambiente", isOn: menu.envSounds)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:hover", title: "Sons ao apontar",
                      subtitle: "Um tique quando o cursor passa por um botão", isOn: menu.hoverSounds)

            SectionTitle(text: "Data e hora", theme: theme, scale: s)
            InfoRow(theme: theme, scale: s, title: "Data", value: menu.dateText)
            InfoRow(theme: theme, scale: s, title: "Hora", value: menu.timeText)
            InfoRow(theme: theme, scale: s, title: "Fuso horário", value: TimeZone.current.identifier)

            SectionTitle(text: "Idioma e região", theme: theme, scale: s)
            InfoRow(theme: theme, scale: s, title: "Idioma", value: Locale.current.identifier)

            SectionTitle(text: "Energia", theme: theme, scale: s)
            ActionRow(menu: menu, theme: theme, action: "b:reset", title: "Centralizar vista",
                      subtitle: "Traz a câmera de volta para a frente", icon: "scope")
        }
    }
}

struct PersonalPage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            SectionTitle(text: "Ambiente virtual", theme: theme, scale: s)
            ActionRow(menu: menu, theme: theme, action: "b:card:envs", title: "Escolher ambiente",
                      subtitle: MenuModel.envName(menu.homeEnv), icon: "mountain.2.fill")
            SectionTitle(text: "Tema", theme: theme, scale: s)
            ChoiceRow(menu: menu, theme: theme, title: "Aparência do menu",
                      options: [("b:theme:dark", "Escuro"), ("b:theme:light", "Claro")],
                      selected: menu.themeLight ? 1 : 0)
        }
    }
}

struct HandsPage: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel
    @ObservedObject var tracker: HandTracker
    let theme: Theme

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            SectionTitle(text: "Mãos", theme: theme, scale: s)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:hands", title: "Rastreio de mãos",
                      subtitle: "Usa a câmera frontal para detectar suas mãos", isOn: menu.handTracking)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:camera", title: "Mostrar a câmera",
                      subtitle: "Miniatura da câmera no canto da tela", isOn: app.showCamera)
            InfoRow(theme: theme, scale: s, title: "Estado", value: tracker.status)
            SectionTitle(text: "Movimento", theme: theme, scale: s)
            ToggleRow(menu: menu, theme: theme, action: "b:tog:gyro", title: "Giroscópio",
                      subtitle: "Gira a vista junto com o aparelho", isOn: app.gyroEnabled)
            ActionRow(menu: menu, theme: theme, action: "b:reset", title: "Centralizar vista",
                      subtitle: "", icon: "scope")
        }
    }
}

struct AccessPage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            SectionTitle(text: "Texto", theme: theme, scale: s)
            ChoiceRow(menu: menu, theme: theme, title: "Tamanho do texto do menu",
                      options: [("b:text:0", "Normal"), ("b:text:1", "Grande"), ("b:text:2", "Maior")],
                      selected: menu.textScaleIdx)
        }
    }
}

struct StoragePage: View {
    @ObservedObject var menu: MenuModel
    let theme: Theme

    var body: some View {
        VStack(spacing: 10) {
            InfoRow(theme: theme, scale: menu.ts, title: "Espaço", value: menu.storageText)
        }
    }
}

struct AboutPage: View {
    @ObservedObject var menu: MenuModel
    @ObservedObject var app: AppModel
    @ObservedObject var tracker: HandTracker
    let theme: Theme

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return v + " (" + b + ")"
    }

    var body: some View {
        let s = menu.ts
        return VStack(spacing: 10) {
            InfoRow(theme: theme, scale: s, title: "Aparelho", value: UIDevice.current.model)
            InfoRow(theme: theme, scale: s, title: "Versão", value: version)
            InfoRow(theme: theme, scale: s, title: "iOS", value: UIDevice.current.systemVersion)
            InfoRow(theme: theme, scale: s, title: "Ambiente", value: MenuModel.envName(menu.homeEnv))
            InfoRow(theme: theme, scale: s, title: "Cena", value: app.renderInfo)
            InfoRow(theme: theme, scale: s, title: "Mãos", value: tracker.status)
            InfoRow(theme: theme, scale: s, title: "Feito por", value: "Stormie (s.edits.storm no TikTok)")
            InfoRow(theme: theme, scale: s, title: "Metulas", value: "Port do shell v44 do Quest para iPhone")
            ActionRow(menu: menu, theme: theme, action: "b:opensettings", title: "Permissões do app",
                      subtitle: "Abre os Ajustes do iOS (câmera)", icon: "gearshape")
        }
    }
}

// MARK: - cursor das mãos

struct PointerOverlay: View {
    @ObservedObject var pointer: PointerModel

    var body: some View {
        ZStack {
            ForEach(pointer.dots) { d in
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .background(Circle().fill(d.pinching ? Color.yellow.opacity(0.9) : Color.white.opacity(0.15)))
                    .frame(width: d.pinching ? 18 : 28, height: d.pinching ? 18 : 28)
                    .position(d.point)
            }
        }
        .allowsHitTesting(false)
    }
}

struct NightOverlay: View {
    @ObservedObject var menu: MenuModel

    var body: some View {
        Group {
            if menu.night {
                Color(red: 1.0, green: 0.55, blue: 0.15).opacity(0.2)
            }
        }
        .allowsHitTesting(false)
    }
}
