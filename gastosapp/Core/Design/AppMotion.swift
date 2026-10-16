import SwiftUI

/// Animaciones compartidas de la app.
///
/// Antes cada pantalla elegía su propio resorte o fundido y unas cosas se
/// movían y otras saltaban. Usar siempre estos valores hace que un mismo tipo
/// de cambio se sienta igual en toda la app.
enum AppMotion {
    /// Cambios de estado: pestañas, selección, filtros, cambiar de sección.
    static let standard: Animation = .spring(response: 0.32, dampingFraction: 0.86)

    /// Desplegables y paneles que se abren en línea dentro de una lista.
    static let expand: Animation = .spring(response: 0.38, dampingFraction: 0.88)

    /// Fundidos breves: mensajes, interruptores, pasar del esqueleto a los datos.
    static let fade: Animation = .easeOut(duration: 0.2)

    /// Respuesta al pulsar un control.
    static let press: Animation = .spring(response: 0.28, dampingFraction: 0.7)

    /// Lo que aparece debajo de algo, como un desplegable: baja un poco y se funde.
    static let reveal: AnyTransition = .opacity.combined(with: .offset(y: -8))

    /// Avisos que suben desde el pie de la pantalla.
    static let toast: AnyTransition = .move(edge: .bottom).combined(with: .opacity)

    /// Botones y pastillas que aparecen o desaparecen en su sitio.
    static let pop: AnyTransition = .opacity.combined(with: .scale(scale: 0.9))
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
