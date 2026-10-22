import SwiftUI
import UIKit

/// Sistema de diseño de la app.
///
/// Valores tomados del canvas «Control de Gastos — Inicio iOS»: fondo casi
/// negro (o gris muy claro), tarjetas planas sin borde ni sombra, un acento
/// verde y semánticos separados para subir/bajar. Todas las pantallas leen sus
/// colores, radios y tipografías desde aquí.
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

    static let backgroundTop = adaptive(dark: hex(0x0C0C0D), light: hex(0xF4F4F6))

    /// Color liso: el degradado que había iba de un color a sí mismo y sólo
    /// sumaba trabajo de dibujo en cada pantalla.
    static var screenBackground: some View {
        backgroundTop
    }

    // MARK: - Superficies

    /// Tarjeta principal sobre el fondo.
    static let surface = adaptive(dark: hex(0x151517), light: hex(0xFFFFFF))
    /// Superficie anidada dentro de una tarjeta; también el riel de las barras.
    static let insetSurface = adaptive(dark: hex(0x232326), light: hex(0xF4F4F6))
    /// Controles (segmentos, campos, botones secundarios).
    static let controlSurface = adaptive(dark: hex(0x232326), light: hex(0xECECF0))
    /// Riel vacío de barras de progreso.
    static let track = adaptive(dark: hex(0x232326), light: hex(0xE8E8EC))
    /// Paneles emergentes (búsqueda, bandeja) sobre el contenido.
    static let popoverSurface = adaptive(dark: hex(0x1C1C1E), light: hex(0xFFFFFF))
    /// Barras flotantes (tab bar, encabezados, toasts).
    static let chromeSurface = adaptive(dark: hex(0x1E1E20, 0.88), light: hex(0xFFFFFF, 0.92))
    /// Botones circulares flotantes del encabezado.
    static let chromeButtonSurface = adaptive(dark: hex(0x242428, 0.94), light: hex(0xFFFFFF, 0.96))
    /// Tinte del velo de encabezado, sobre el material desenfocado.
    ///
    /// En oscuro va casi opaco a propósito: `ultraThinMaterial` sube la
    /// luminancia y sobre un fondo negro el velo se lee gris, que es justo lo
    /// que no queremos. Tapándolo con el mismo negro del fondo queda un cristal
    /// oscuro —sigue desenfocando lo que pasa por debajo, pero no aclara la
    /// franja—. En claro el material ya casa con el fondo, así que ahí el tinte
    /// se queda suave.
    static let headerScrimTint = adaptive(dark: hex(0x0C0C0D, 0.62), light: hex(0xF4F4F6, 0.26))

    // MARK: - Bordes

    static let border = adaptive(dark: hex(0xFFFFFF, 0.08), light: hex(0x000000, 0.06))
    static let strongBorder = adaptive(dark: hex(0xFFFFFF, 0.12), light: hex(0x000000, 0.10))
    /// Separador opaco entre filas dentro de una tarjeta.
    static let separator = adaptive(dark: hex(0x232326), light: hex(0xE8E8EC))

    // MARK: - Texto

    static let primaryText = adaptive(dark: hex(0xF5F5F5), light: hex(0x111114))
    static let secondaryText = adaptive(dark: hex(0xA0A0AA), light: hex(0x5F5F69))
    static let tertiaryText = adaptive(dark: hex(0x8A8A94), light: hex(0x6B6B75))
    /// Marcadores de posición, controles deshabilitados y glifos de estado vacío.
    ///
    /// Es el nivel más tenue de la escala: debe insinuar, no competir con el
    /// contenido real. No lo uses para texto que el usuario tenga que leer.
    static let placeholderText = adaptive(dark: hex(0xFFFFFF, 0.26), light: hex(0x000000, 0.26))

    // MARK: - Acentos y semánticos

    /// Verde de marca (#3FA663).
    ///
    /// Mismo valor en claro y en oscuro: es identidad, no un token que deba
    /// adaptarse. Los botones sólidos llevan `onAccent` encima (≈6.3:1).
    static let accent = Color(uiColor: hex(0x3FA663))
    /// Violeta: recurrentes, proyecciones y datos secundarios.
    static let secondaryAccent = adaptive(dark: hex(0xA78FF7), light: hex(0x7A5AE8))
    /// Azul informativo (p. ej. el ritmo de hoy).
    static let info = adaptive(dark: hex(0x6AA6F5), light: hex(0x2F7AE0))
    static let warning = adaptive(dark: hex(0xE8A82A), light: hex(0xB7791F))
    /// Gastar más / pasarse del límite.
    static let negative = adaptive(dark: hex(0xF4607F), light: hex(0xD93A5E))
    /// Gastar menos / dentro del límite.
    static let positive = adaptive(dark: hex(0x3DD68C), light: hex(0x1F9D5C))
    /// Color de texto/iconos que van encima de un acento sólido.
    static let onAccent = Color(uiColor: hex(0x0C0C0D))
    /// Bloque protagonista: tarjeta teñida con el acento, en los dos modos.
    static let statementSurface = accent.opacity(0.12)
    static let onStatement = primaryText
    static let statementSecondary = secondaryText
    /// Separadores dentro del bloque.
    static let onStatementFaint = adaptive(dark: hex(0xFFFFFF, 0.10), light: hex(0x000000, 0.08))

    /// Colores fijos para distinguir categorías en barras, puntos y leyendas.
    static let categoryPalette: [Color] = [
        Color(uiColor: hex(0x3F8CF0)),
        Color(uiColor: hex(0xC98400)),
        Color(uiColor: hex(0x9170F5)),
        Color(uiColor: hex(0x12A37A)),
        Color(uiColor: hex(0xE0607E)),
        Color(uiColor: hex(0x5FA8B8)),
        Color(uiColor: hex(0xE07B39)),
        Color(uiColor: hex(0x7FA83A)),
        Color(uiColor: hex(0xC062C9)),
        Color(uiColor: hex(0x8A93A6))
    ]

    static func categoryColor(at index: Int) -> Color {
        categoryPalette[((index % categoryPalette.count) + categoryPalette.count) % categoryPalette.count]
    }

    static func delta(_ value: Double, positiveIsGood: Bool = true) -> Color {
        if value == 0 { return secondaryText }
        return (value > 0) == positiveIsGood ? positive : negative
    }

    // MARK: - Radios

    enum Radius {
        static let card: CGFloat = 22
        static let control: CGFloat = 16
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

    /// Tarjeta plana: el contraste con el fondo basta, sin borde ni sombra.
    static func cardBackground(cornerRadius: CGFloat = Radius.card) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(surface)
    }

    /// Fondo del bloque protagonista: el acento al 12 % sobre el fondo.
    static func statementBackground(cornerRadius: CGFloat = Radius.card) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(statementSurface)
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
    }

    /// Fondo de barra flotante: material difuso + hairline + sombra profunda.
    static func chromeBackground<S: InsettableShape>(_ shape: S) -> some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay(shape.fill(chromeSurface))
            .overlay(shape.strokeBorder(strongBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 16, y: 8)
    }
}

// MARK: - Métricas de pantalla

/// Retícula compartida por todas las pantallas con encabezado propio.
enum AppScreenMetrics {
    static let horizontalPadding: CGFloat = 24
    static let headerTopPadding: CGFloat = 12
    static let headerBottomPadding: CGFloat = 18
    /// Aire tras el último bloque. Va *encima* del espacio que reserva la barra
    /// flotante, así que no hay que sumarle el alto de la barra a mano.
    static let contentBottomPadding: CGFloat = 24
    /// Separación de un toast respecto a la barra flotante.
    static var toastBottomPadding: CGFloat {
        FloatingTabBarMetrics.reservedHeight + 12
    }
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

extension View {
    /// Fondo de los controles flotantes de la barra superior y los encabezados.
    ///
    /// En iOS 26 es Liquid Glass; antes, la superficie translúcida con borde
    /// y sombra de siempre. `tint` tiñe el cristal (o rellena la forma, antes
    /// de iOS 26) para los botones destacados.
    ///
    /// Sin `.interactive()`: va dentro de la etiqueta de un `Button` y el
    /// cristal interactivo se quedaba con el primer toque, así que había que
    /// tocar dos veces para abrir Notificaciones o Nuevo gasto. La respuesta
    /// al pulsar ya la da `.pressable`.
    @ViewBuilder
    func chromeGlass<S: InsettableShape>(_ shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(tint), in: shape)
        } else {
            background(
                shape
                    .fill(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(AppTheme.chromeButtonSurface))
                    .overlay(shape.strokeBorder(AppTheme.strongBorder, lineWidth: tint == nil ? 1 : 0))
                    .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
            )
        }
    }

    /// Agrupa controles de cristal para que se fundan y se transformen entre
    /// sí al aparecer o desaparecer. Antes de iOS 26 no hace nada.
    @ViewBuilder
    func chromeGlassGroup(spacing: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { self }
        } else {
            self
        }
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
                .chromeGlass(Circle(), tint: prominent ? AppTheme.accent : nil)
        }
        .buttonStyle(.pressable)
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

/// Velo de encabezado: desenfoque que se apaga hacia abajo.
///
/// Tres capas, cada una resolviendo un problema distinto:
///
/// 1. `ultraThinMaterial` da el desenfoque, pero sobre un fondo casi negro
///    aporta luminancia y se ve gris. `headerScrimTint` se la quita: en oscuro
///    tapa el material con el negro del fondo y deja sólo el desenfoque.
/// 2. La franja de desvanecido tiene alto **fijo**, no un porcentaje: con un
///    porcentaje cambia de grosor según el área segura del modelo y en unos
///    aparece un corte y en otros no.
/// 3. La rampa no es lineal. Un degradado lineal deja ver el punto donde
///    empieza — el ojo detecta el cambio brusco de pendiente — así que la
///    máscara usa varias paradas que imitan una curva suave por los dos
///    extremos, y así no hay línea.
struct AppHeaderScrim: View {
    var fadeHeight: CGFloat = 64

    private var fadeStops: [Gradient.Stop] {
        [
            .init(color: .black, location: 0),
            .init(color: .black.opacity(0.97), location: 0.14),
            .init(color: .black.opacity(0.86), location: 0.30),
            .init(color: .black.opacity(0.62), location: 0.48),
            .init(color: .black.opacity(0.34), location: 0.66),
            .init(color: .black.opacity(0.12), location: 0.84),
            .init(color: .clear, location: 1)
        ]
    }

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(AppTheme.headerScrimTint)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(stops: fadeStops, startPoint: .top, endPoint: .bottom)
                        .frame(height: fadeHeight)
                }
            }
            .padding(.bottom, -fadeHeight * 0.75)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

/// Velo de encabezado que aparece al desplazar.
///
/// Lee `TabBarChrome` por su cuenta: si la pantalla lo leyera en su `body`,
/// cada vez que el velo aparece o desaparece se recalcularía la pantalla
/// entera. Y sólo dibuja el desenfoque cuando se ve; con opacidad 0 el
/// material se seguía componiendo en cada fotograma.
struct ScrollAwareHeaderScrim: View {
    @Environment(TabBarChrome.self) private var chrome: TabBarChrome?

    var body: some View {
        ZStack {
            if chrome?.isScrolled == true {
                AppHeaderScrim()
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Velo inferior: el mismo cristal que `AppHeaderScrim`, fundido hacia arriba.
///
/// Va detrás de las acciones fijas al pie (como «Guardar gasto») para que el
/// contenido pase por debajo desenfocado en lugar de cortarse en seco.
struct AppFooterScrim: View {
    var fadeHeight: CGFloat = 48

    private var fadeStops: [Gradient.Stop] {
        [
            .init(color: .clear, location: 0),
            .init(color: .black.opacity(0.12), location: 0.16),
            .init(color: .black.opacity(0.34), location: 0.34),
            .init(color: .black.opacity(0.62), location: 0.52),
            .init(color: .black.opacity(0.86), location: 0.70),
            .init(color: .black.opacity(0.97), location: 0.86),
            .init(color: .black, location: 1)
        ]
    }

    var body: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(AppTheme.headerScrimTint)
            .mask {
                VStack(spacing: 0) {
                    LinearGradient(stops: fadeStops, startPoint: .top, endPoint: .bottom)
                        .frame(height: fadeHeight)
                    Rectangle()
                }
            }
            .padding(.top, -fadeHeight * 0.5)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
    }
}

extension View {
}

/// Respuesta táctil al pulsar: el control se hunde ligeramente.
///
/// SwiftUI no da realimentación visual a `.buttonStyle(.plain)`, así que sin
/// esto los botones de la app parecen etiquetas muertas al tocarlos.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle {
        PressableButtonStyle(scale: scale)
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
    /// Círculo en lugar de cuadrado redondeado, como en las filas de Gastos.
    var isCircular = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isCircular ? size / 2 : size * 0.32, style: .continuous)

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

/// Separador de 1px alineado con la retícula de las tarjetas.
struct AppHairline: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.separator)
            .frame(height: 1)
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

/// Bloque de esqueleto con un brillo que lo recorre, mientras llegan los datos.
///
/// Con «Reducir movimiento» se queda quieto: el brillo es decoración, no
/// información.
struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.insetSurface)
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(
                            colors: [.clear, AppTheme.primaryText.opacity(0.07), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: proxy.size.width)
                        .offset(x: phase * proxy.size.width)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            }
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}
