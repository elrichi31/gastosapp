import SwiftUI

/// Barra superior de Correo: cuántos movimientos esperan y las acciones de
/// buscar y sincronizar, como círculos a la derecha.
struct EmailInboxHeader: View {
    let counts: [String: Int]
    @Binding var isSearching: Bool
    let isSyncing: Bool
    let canSync: Bool
    let onSync: () -> Void

    private var total: Int { counts.values.reduce(0, +) }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(counts.isEmpty ? "—" : total.formatted())
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .contentTransition(.numericText())
                Text(counts.isEmpty ? "Consultando pendientes" : total == 1 ? "movimiento por revisar" : "movimientos por revisar")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            circleButton(icon: "magnifyingglass", label: isSearching ? "Cerrar búsqueda" : "Buscar", isOn: isSearching) {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { isSearching.toggle() }
            }
            Button(action: onSync) {
                Group {
                    if isSyncing {
                        ProgressView().controlSize(.small).tint(AppTheme.primaryText)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.popoverSurface))
            }
            .buttonStyle(.pressable)
            .disabled(!canSync || isSyncing)
            .opacity(canSync || isSyncing ? 1 : 0.5)
            .accessibilityLabel(isSyncing ? "Buscando movimientos" : "Sincronizar correo")
        }
    }

    private func circleButton(icon: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isOn ? AppTheme.backgroundTop : AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(isOn ? AppTheme.primaryText : AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
