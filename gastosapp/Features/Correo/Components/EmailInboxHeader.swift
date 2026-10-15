import SwiftUI

struct EmailInboxHeader: View {
    let counts: [String: Int]
    let selectedTab: EmailReviewTab
    let isSyncing: Bool
    let canSync: Bool
    let onSync: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var countSize = 48

    private var total: Int { counts.values.reduce(0, +) }
    var body: some View {
        VStack(spacing: 12) {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionLabel(text: "DEL CORREO A TUS GASTOS")
                    syncButton
                }.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack {
                    AppSectionLabel(text: "DEL CORREO A TUS GASTOS")
                    Spacer()
                    syncButton
                }
            }
            Text(counts.isEmpty ? "—" : total.formatted())
                .font(AppTheme.number(countSize, .bold))
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
            Text(counts.isEmpty ? "Consultando pendientes" : total == 1 ? "movimiento por revisar" : "movimientos por revisar")
                .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.secondaryText)
            Text(selectedTab.help)
                .font(.caption).foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
    private var syncButton: some View {
        Button(action: onSync) {
            HStack(spacing: 6) {
                if isSyncing { ProgressView().controlSize(.mini) }
                else { Image(systemName: "arrow.triangle.2.circlepath") }
                Text(isSyncing ? "Buscando…" : "Sincronizar").lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 12).padding(.vertical, 9).frame(minHeight: 38)
            .background(AppTheme.accent.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(!canSync || isSyncing)
        .accessibilityLabel("Buscar nuevos movimientos en el correo")
    }
}
