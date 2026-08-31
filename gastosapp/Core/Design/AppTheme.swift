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

    static let backgroundTop = adaptive(dark: hex(0x080908), light: hex(0xF7F8F7))
    static let backgroundBottom = adaptive(dark: hex(0x080908), light: hex(0xECEFEC))

    static var screenBackground: some View {
        LinearGradient(
            colors: [backgroundTop, backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Superficies

    /// Tarjeta principal sobre el fondo.
    static let surface = adaptive(dark: hex(0x171817), light: hex(0xFFFFFF))
    /// Superficie anidada dentro de una tarjeta.
    static let insetSurface = adaptive(dark: hex(0x202120), light: hex(0xF3F4F3))
    /// Controles (segmentos, campos, botones secundarios).
    static let controlSurface = adaptive(dark: hex(0x202120), light: hex(0xEDEFED))
    /// Barras flotantes (tab bar, encabezados, toasts).
    static let chromeSurface = adaptive(dark: hex(0x151615, 0.90), light: hex(0xFFFFFF, 0.88))

    // MARK: - Bordes

    static let border = adaptive(dark: hex(0xFFFFFF, 0.07), light: hex(0x000000, 0.06))
    static let strongBorder = adaptive(dark: hex(0xFFFFFF, 0.13), light: hex(0x000000, 0.10))

    // MARK: - Texto

    static let primaryText = adaptive(dark: hex(0xF5F5F3), light: hex(0x0B0C0B))
    static let secondaryText = adaptive(dark: hex(0xFFFFFF, 0.60), light: hex(0x000000, 0.55))
    static let tertiaryText = adaptive(dark: hex(0xFFFFFF, 0.38), light: hex(0x000000, 0.36))
    /// Marcadores de posición, controles deshabilitados y glifos de estado vacío.
    ///
    /// Es el nivel más tenue de la escala: debe insinuar, no competir con el
    /// contenido real. No lo uses para texto que el usuario tenga que leer.
    static let placeholderText = adaptive(dark: hex(0xFFFFFF, 0.26), light: hex(0x000000, 0.26))

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
    /// Bloque protagonista del dashboard: negro con matiz verde.
    ///
    /// No es adaptativo: en claro y en oscuro es el mismo bloque oscuro, igual
    /// que el acento. Es identidad de marca, no un token de superficie.
    static let statementSurface = Color(uiColor: hex(0x0F1712))
    private static let statementSurfaceDeep = Color(uiColor: hex(0x070A08))
    static let onStatement = Color(uiColor: hex(0xF2F5F2))
    static let statementSecondary = Color(uiColor: hex(0xFFFFFF, 0.58))
    /// Filo y separadores dentro del bloque.
    static let onStatementFaint = Color(uiColor: hex(0xFFFFFF, 0.12))
    /// Relleno de un control primario deshabilitado.
    static let disabledFill = adaptive(dark: hex(0x24261F), light: hex(0xD5D9D3))

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
            .fill(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.14), border, border],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
    }

    /// Fondo del bloque protagonista: negro verdoso, halo de acento y filo verde.
    static func statementBackground(cornerRadius: CGFloat = 30) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [statementSurface, statementSurfaceDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                shape.fill(
                    RadialGradient(
                        colors: [accent.opacity(0.20), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [accent.opacity(0.38), onStatementFaint, onStatementFaint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.85
                )
            )
            .shadow(color: .black.opacity(0.34), radius: 26, y: 14)
    }

    /// Separador dentro del bloque protagonista.
    static var statementHairline: some View {
        Rectangle()
            .fill(onStatementFaint)
            .frame(height: 1)
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
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), strongBorder, border],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.75
                )
            )
            .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.24), radius: 26, y: 12)
    }
}

// MARK: - Métricas de pantalla

/// Retícula compartida por todas las pantallas con encabezado propio.
enum AppScreenMetrics {
    static let horizontalPadding: CGFloat = 24
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 18
    static let sectionSpacing: CGFloat = 30
}

// MARK: - Componentes compartidos

/// Encabezado de pantalla: antetítulo, título grande y acciones a la derecha.
///
/// Sustituye a las barras flotantes con cápsula: el título vive sobre el fondo,
/// como en las apps de banca, y las acciones son círculos sueltos.
struct AppScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 8)

            trailing
        }
        .frame(maxWidth: .infinity)
    }
}

extension AppScreenHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

/// Botón circular de acción para los encabezados.
struct AppCircleButton: View {
    let icon: String
    var prominent: Bool = false
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: prominent ? 16 : 15, weight: .bold))
                .foregroundStyle(prominent ? AppTheme.onAccent : AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(prominent ? AnyShapeStyle(AppTheme.accent) : AnyShapeStyle(AppTheme.controlSurface))
                        .overlay(Circle().strokeBorder(AppTheme.border, lineWidth: prominent ? 0 : 1))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Selector de periodo con flechas, usado en Estadísticas y Presupuestos.
struct AppPeriodStepper: View {
    let label: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    var previousLabel: String = "Anterior"
    var nextLabel: String = "Siguiente"

    var body: some View {
        HStack(spacing: 2) {
            stepButton(icon: "chevron.left", action: onPrevious, label: previousLabel)
            Text(label)
                .font(AppTheme.number(14, .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
                .frame(minWidth: 46)
            stepButton(icon: "chevron.right", action: onNext, label: nextLabel)
        }
        .padding(4)
        .background(
            Capsule()
                .fill(AppTheme.controlSurface)
                .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
        )
        .accessibilityElement(children: .contain)
    }

    private func stepButton(icon: String, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.85))
                .frame(width: 32, height: 32)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Título de sección para el contenido plano entre bloques.
struct AppSectionTitle: View {
    let title: String
    var trailingText: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppTheme.primaryText)
            Spacer(minLength: 8)
            if let trailingText {
                Text(trailingText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}

/// Ficha de categoría: símbolo dedicado o, si no lo hay, la inicial del nombre.
///
/// El monograma evita que todas las categorías creadas por el usuario compartan
/// el mismo icono genérico, que es lo que hacía ilegible la lista.
struct CategoryGlyph: View {
    let categoria: Categoria
    var size: CGFloat = 44
    var tint: Color = AppTheme.primaryText
    var background: Color = AppTheme.controlSurface
    var borderColor: Color?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)

        return Group {
            if let symbolName = categoria.symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.38, weight: .semibold))
            } else {
                Text(categoria.monogram)
                    .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(tint)
        .frame(width: size, height: size)
        .background(shape.fill(background))
        .overlay {
            if let borderColor {
                shape.strokeBorder(borderColor, lineWidth: 1)
            }
        }
        .accessibilityHidden(true)
    }
}

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
