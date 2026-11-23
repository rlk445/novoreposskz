import SwiftUI

extension Color {
    /// Cor a partir de um inteiro 0xAARRGGBB (o mesmo formato do Shell.java original).
    init(argb: UInt32) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// Paleta do menu. Valores convertidos de `applyTheme()` do Shell.java.
struct Theme {
    let panel: Color
    let card: Color
    let text: Color
    let sub: Color
    let accent: Color
    let div: Color
    let hover: Color
    let track: Color
    let toggleOff: Color

    static let dark = Theme(
        panel: Color(argb: 0xFF2D2D2D),
        card: Color(argb: 0xFF3B3B3B),
        text: Color(argb: 0xFFF0F0F0),
        sub: Color(argb: 0x99FFFFFF),
        accent: Color(argb: 0xFF317CF2),
        div: Color(argb: 0x26FFFFFF),
        hover: Color(argb: 0x33FFFFFF),
        track: Color(argb: 0x30FFFFFF),
        toggleOff: Color(argb: 0xFF515151))

    static let light = Theme(
        panel: Color(argb: 0xFFD2D2D2),
        card: Color(argb: 0xFFE0E0E0),
        text: Color(argb: 0xFF232323),
        sub: Color(argb: 0x99000000),
        accent: Color(argb: 0xFF1364E7),
        div: Color(argb: 0x26000000),
        hover: Color(argb: 0x33000000),
        track: Color(argb: 0x26000000),
        toggleOff: Color(argb: 0xFFAFAFAF))
}

/// Gradientes dos ícones do dock (tabela GRAD do Shell.java).
private let tileColors: [[UInt32]] = [
    [0xFFC9940D, 0xFFB55211],
    [0xFFC09ADA, 0xFF356EC7],
    [0xFF519EB7, 0xFF2A62B4],
    [0xFF6EB89D, 0xFF276EC2],
    [0xFFAAA850, 0xFF3B8C80],
    [0xFF7BB051, 0xFF078597],
    [0xFFD37BB0, 0xFFBD3A3A],
    [0xFFCF7D1C, 0xFFB535A0],
    [0xFFD37E9D, 0xFF5543C0]
]

func tileGradient(_ index: Int) -> LinearGradient {
    let c = tileColors[max(0, min(index, tileColors.count - 1))]
    return LinearGradient(colors: [Color(argb: c[0]), Color(argb: c[1])],
                          startPoint: .topLeading, endPoint: .bottomTrailing)
}
