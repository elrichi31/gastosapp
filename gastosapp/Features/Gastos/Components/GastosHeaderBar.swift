import SwiftUI

enum GastosSectionMode: Hashable, CaseIterable {
    case movimientos
    case recurrentes
    case correo

    var title: String {
        switch self {
        case .movimientos:
            return "Gastos"
        case .recurrentes:
            return "Recurrentes"
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
        case .correo:
            return "envelope"
        }
    }
}

/// Encabezado de Gastos: título grande y, como en el canvas, una sola
/// pastilla «Recurrentes». Correo se abre desde la bandeja de la barra
/// superior. Dentro de una sección, un botón de volver ocupa su lugar. El «+»
/// sólo aparece si no hay barra superior compartida que ya lo ofrezca.
struct GastosHeaderBar: View {
    @Binding var sectionMode: GastosSectionMode

    /// `nil` cuando la barra superior compartida ya ofrece el «+».
    var onAddTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            if sectionMode != .movimientos {
                AppCircleButton(icon: "chevron.left", label: "Volver a Gastos") { select(.movimientos) }
                    .transition(AppMotion.pop)
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
                Button {
                    select(.recurrentes)
                } label: {
                    Label(GastosSectionMode.recurrentes.title, systemImage: GastosSectionMode.recurrentes.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(
                            Capsule()
                                .fill(AppTheme.popoverSurface)
                                .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
                        )
                }
                .buttonStyle(.pressable(scale: 0.95))
                .transition(AppMotion.pop)
            }

            if let onAddTap {
                AppCircleButton(icon: "plus", label: "Nuevo gasto", action: onAddTap)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func select(_ mode: GastosSectionMode) {
        withAnimation(AppMotion.standard) {
            sectionMode = mode
        }
    }
}

struct GastosCapsuleBackground: View {
    var body: some View {
        AppTheme.chromeBackground(Capsule())
    }
}
