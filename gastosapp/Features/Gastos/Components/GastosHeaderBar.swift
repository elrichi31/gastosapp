import SwiftUI

enum GastosSectionMode: Hashable, CaseIterable {
    case movimientos
    case recurrentes
    case calendario
    case correo

    var title: String {
        switch self {
        case .movimientos:
            return "Gastos"
        case .recurrentes:
            return "Recurrentes"
        case .calendario: return "Calendario"
        case .correo:
            return "Correo"
        }
    }

    var icon: String {
        switch self {
        case .movimientos:
            return "list.bullet"
        case .recurrentes:
            return "repeat"
        case .calendario: return "calendar"
        case .correo:
            return "envelope"
        }
    }
}

/// Encabezado de Gastos: título grande y accesos circulares.
///
/// En Movimientos los círculos abren Recurrentes, Calendario y Correo; dentro
/// de una de ellas un botón de volver ocupa su lugar. El «+» sólo aparece si
/// no hay barra superior compartida que ya lo ofrezca.
struct GastosHeaderBar: View {
    @Binding var sectionMode: GastosSectionMode

    /// `nil` cuando la barra superior compartida ya ofrece el «+».
    var onAddTap: (() -> Void)?

    private let shortcuts: [GastosSectionMode] = [.recurrentes, .calendario, .correo]

    var body: some View {
        HStack(spacing: 8) {
            if sectionMode != .movimientos {
                AppCircleButton(icon: "chevron.left", label: "Volver a Gastos") { select(.movimientos) }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Text(sectionMode.title)
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            if sectionMode == .movimientos {
                ForEach(shortcuts, id: \.self) { mode in
                    AppCircleButton(icon: mode.icon, label: mode.title) { select(mode) }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }

            if let onAddTap {
                AppCircleButton(icon: "plus", label: "Nuevo gasto", action: onAddTap)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func select(_ mode: GastosSectionMode) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            sectionMode = mode
        }
    }
}

struct GastosCapsuleBackground: View {
    var body: some View {
        AppTheme.chromeBackground(Capsule())
    }
}
