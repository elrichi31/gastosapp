import SwiftUI

/// Fila de la bandeja: nombre, banco y fecha, monto y una marca si parece
/// duplicado o es una devolución. Al tocarla se abre la revisión.
struct EmailMovementRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let row: EmailMovement
    let category: Categoria?
    let onReview: () -> Void
    let onDiscard: () -> Void
    private var isRefund: Bool { row.tipo == "ingreso" }

    var body: some View {
        Button(action: onReview) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.descripcion)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    Text([row.origen, dateLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                    if isRefund || !row.coincidencias.isEmpty {
                        Label(isRefund ? "Devolución" : "Posible duplicado", systemImage: isRefund ? "arrow.uturn.backward" : "square.on.square")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(isRefund ? AppTheme.secondaryAccent : AppTheme.warning)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 8)
                Text((isRefund ? "+" : "") + row.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isRefund ? AppTheme.positive : AppTheme.primaryText)
                    .fixedSize()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 64)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre la revisión del movimiento")
        .contextMenu { Button("Descartar movimiento", systemImage: "trash", role: .destructive, action: onDiscard) }
    }

    private var dateLabel: String {
        AppDateCodec.dateOnly(from: row.fecha)?.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))) ?? row.fecha
    }
}
