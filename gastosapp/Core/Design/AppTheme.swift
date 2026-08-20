import SwiftUI
import UIKit

/// Sistema de diseño de la app.
///
/// Paleta oscura por defecto (negro real + superficies sólidas elevadas),
/// modo claro neutro, un único acento de señal y semánticos para variación.
/// Todas las pantallas leen sus colores, radios y tipografías desde aquí.
enum AppTheme {

    // MARK: - Primitivas

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

    // MARK: - Fondo

    static let backgroundTop = adaptive(dark: hex(0x0B0C0F), light: hex(0xFFFFFF))
    static let backgroundBottom = adaptive(dark: hex(0x000000), light: hex(0xF1F2F5))

    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Superficies

    /// Tarjeta principal sobre el fondo.
    static let surface = adaptive(dark: hex(0x15171C), light: hex(0xFFFFFF))
    /// Superficie anidada dentro de una tarjeta.
    static let insetSurface = adaptive(dark: hex(0x1E212A), light: hex(0xF3F4F8))
    /// Controles (segmentos, campos, botones secundarios).
    static let controlSurface = adaptive(dark: hex(0x1A1D24), light: hex(0xEDEEF3))
    /// Barras flotantes (tab bar, encabezados, toasts).
    static let chromeSurface = adaptive(dark: hex(0x101217, 0.86), light: hex(0xFFFFFF, 0.90))

    // MARK: - Bordes

    static let border = adaptive(dark: hex(0xFFFFFF, 0.07), light: hex(0x000000, 0.06))
    static let strongBorder = adaptive(dark: hex(0xFFFFFF, 0.13), light: hex(0x000000, 0.10))

    // MARK: - Texto

    static let primaryText = adaptive(dark: hex(0xF5F6F8), light: hex(0x0B0C0F))
    static let secondaryText = adaptive(dark: hex(0xFFFFFF, 0.60), light: hex(0x000000, 0.55))
    static let tertiaryText = adaptive(dark: hex(0xFFFFFF, 0.38), light: hex(0x000000, 0.36))

    // MARK: - Acentos y semánticos

    /// Verde de marca, tomado del ícono de la app (#37965C).
    ///
    /// Es el mismo valor en claro y en oscuro: es identidad, no un token que
    /// deba adaptarse. Contraste: 5.68:1 con texto negro encima (los botones
    /// sólidos usan `onAccent`) y 5.29:1 como texto sobre el fondo oscuro.
    static let accent = Color(uiColor: hex(0x37965C))
    /// Índigo eléctrico: recurrentes, proyecciones y datos secundarios.
    static let secondaryAccent = adaptive(dark: hex(0x7B8CFF), light: hex(0x4A5FF0))
    static let warning = adaptive(dark: hex(0xFFB340), light: hex(0xE08300))
    static let negative = adaptive(dark: hex(0xFF5A52), light: hex(0xE03A31))
    static let positive = accent
    /// Color de texto/iconos que van encima de un acento sólido.
    static let onAccent = Color.black
    /// Relleno de un control primario deshabilitado.
    static let disabledFill = adaptive(dark: hex(0x2A2E37), light: hex(0xD3D6DD))

    static func delta(_ value: Double, positiveIsGood: Bool = true) -> Color {
        if value == 0 { return secondaryText }
        return (value > 0) == positiveIsGood ? positive : negative
    }

    // MARK: - Radios

    enum Radius {
        static let card: CGFloat = 24
        static let control: CGFloat = 16
        static let chip: CGFloat = 11
    }

    // MARK: - Tipografía

    /// Cifras y titulares: grotesca neutra con dígitos de ancho fijo.
    static func number(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    /// Etiqueta de sección en versalitas.
    static func label(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    // MARK: - Fondos reutilizables

    static func cardBackground(cornerRadius: CGFloat = Radius.card) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 20, y: 8)
    }

    static func insetBackground(cornerRadius: CGFloat = Radius.control) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(insetSurface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }

    static func capsuleBackground(_ color: Color = surface) -> some View {
        Capsule().fill(color)
    }

    /// Fondo de barra flotante: material difuso + hairline + sombra profunda.
    static func chromeBackground<S: InsettableShape>(_ shape: S) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(chromeSurface))
            .overlay(shape.strokeBorder(strongBorder, lineWidth: 0.75))
            .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
    }
}

// MARK: - Componentes compartidos

/// Etiqueta de sección: versalitas, tracking amplio, color terciario.
struct AppSectionLabel: View {
    let text: String
    var size: CGFloat = 11

    var body: some View {
        Text(text)
            .font(AppTheme.label(size))
            .textCase(.uppercase)
            .tracking(1.3)
            .foregroundStyle(AppTheme.tertiaryText)
    }
}

/// Píldora de variación con flecha, al estilo de un ticker.
struct AppDeltaChip: View {
    let text: String
    var isPositive: Bool
    var showsArrow: Bool = true

    private var tint: Color { isPositive ? AppTheme.positive : AppTheme.negative }

    var body: some View {
        HStack(spacing: 4) {
            if showsArrow {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 10, weight: .bold))
            }
            Text(text)
                .font(AppTheme.number(12, .bold))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

/// Separador de 1px alineado con la retícula de las tarjetas.
struct AppHairline: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.border)
            .frame(height: 1)
    }
}

/// Icono con halo suave en lugar de un cuadro sólido de color.
struct AppGlyph: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var size: CGFloat = 34
    var solid: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(solid ? AppTheme.onAccent : tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(solid ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)))
            )
    }
}

struct TransientStatusToast: View {
    let text: String
    let tint: Color
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(AppTheme.chromeBackground(Capsule()))
    }
}
