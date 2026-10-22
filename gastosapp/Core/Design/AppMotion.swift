import SwiftUI

/// Animaciones compartidas de la app.
///
/// Antes cada pantalla elegía su propio resorte o fundido y unas cosas se
/// movían y otras saltaban. Usar siempre estos valores hace que un mismo tipo
/// de cambio se sienta igual en toda la app.
///
/// Con «Reducir movimiento» activado, resortes y desplazamientos pasan a ser
/// fundidos: el cambio se sigue viendo, pero nada se mueve por la pantalla.
enum AppMotion {
    private static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

    /// Cambios de estado: pestañas, selección, filtros, cambiar de sección.
    static var standard: Animation {
        reduceMotion ? fade : .spring(response: 0.32, dampingFraction: 0.86)
    }

    /// Desplegables y paneles que se abren en línea dentro de una lista.
    static var expand: Animation {
        reduceMotion ? fade : .spring(response: 0.38, dampingFraction: 0.88)
    }

    /// Fundidos breves: mensajes, interruptores, pasar del esqueleto a los datos.
    static let fade: Animation = .easeOut(duration: 0.2)

    /// Entrada de una pantalla nueva al cambiar de pestaña o de sección.
    static let screen: Animation = .easeOut(duration: 0.18)

    /// Respuesta al pulsar un control.
    static var press: Animation {
        reduceMotion ? fade : .spring(response: 0.28, dampingFraction: 0.7)
    }

    /// Lo que aparece debajo de algo, como un desplegable: baja un poco y se funde.
    static var reveal: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .offset(y: -8))
    }

    /// Avisos que suben desde el pie de la pantalla.
    static var toast: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// Botones y pastillas que aparecen o desaparecen en su sitio.
    static var pop: AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.9))
    }
}

extension View {
    /// Cambio de pantalla de la app: la anterior se va al instante y la nueva
    /// entra ya colocada con un fundido corto.
    ///
    /// No es un `.transition(.opacity)` dentro de `withAnimation`: con eso iOS
    /// animaba también el ajuste del scroll a las barras y la pantalla nueva
    /// subía y bajaba, y durante el fundido cruzado se veían las dos encimadas.
    /// Aquí el cambio va sin animación y sólo se anima la opacidad de la nueva,
    /// cuando ya tiene su sitio.
    func screenSwap<Value: Hashable>(_ value: Value) -> some View {
        modifier(FadeInOnAppear())
            .id(value)
            .transaction(value: value) { $0.animation = nil }
    }
}

private struct FadeInOnAppear: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(AppMotion.screen) { isVisible = true }
            }
    }
}

/// Esqueleto de una lista de movimientos dentro de una tarjeta: icono, dos
/// líneas y el monto. Sustituye a la ruedita de carga para que todas las
/// pantallas carguen igual.
struct ListRowsSkeleton: View {
    var rows = 4
    var label = "Cargando"

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { index in
                HStack(spacing: 14) {
                    SkeletonBlock(width: 40, height: 40, cornerRadius: 20)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 13)
                        SkeletonBlock(width: 96, height: 10)
                    }
                    Spacer(minLength: 0)
                    SkeletonBlock(width: 60, height: 15)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                if index < rows - 1 { AppHairline() }
            }
        }
        .background(AppTheme.cardBackground())
        .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
