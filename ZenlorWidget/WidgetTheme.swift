import SwiftUI
import UIKit

/// Los tokens de `AppTheme` que usan los widgets, con los mismos valores.
///
/// `AppTheme` vive en el target de la app y arrastra componentes que aquí no
/// existen; si cambia un color allí, hay que cambiarlo también aquí.
enum WidgetTheme {
    private static func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func adaptive(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static let surface = adaptive(dark: hex(0x151517), light: hex(0xFFFFFF))
    static let track = adaptive(dark: hex(0x232326), light: hex(0xE8E8EC))
    static let primaryText = adaptive(dark: hex(0xF5F5F5), light: hex(0x111114))
    static let secondaryText = adaptive(dark: hex(0xA0A0AA), light: hex(0x5F5F69))
    static let accent = Color(uiColor: hex(0x3FA663))
    static let warning = adaptive(dark: hex(0xE8A82A), light: hex(0xB7791F))
    static let negative = adaptive(dark: hex(0xF4607F), light: hex(0xD93A5E))
    static let positive = adaptive(dark: hex(0x3DD68C), light: hex(0x1F9D5C))

    static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }
}

extension Double {
    var widgetCurrency: String {
        formatted(.currency(code: "USD"))
    }

    /// Sin centavos, para las cifras grandes que tienen poco ancho.
    var widgetCurrencyRounded: String {
        formatted(.currency(code: "USD").precision(.fractionLength(0)))
    }
}
