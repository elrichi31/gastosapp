import SwiftUI

struct EmailMovementRow: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    let row: EmailMovement
    let category: Categoria?
    let onReview: () -> Void
    let onDiscard: () -> Void
    private var isRefund: Bool { row.tipo == "ingreso" }
    private var tint: Color { isRefund ? AppTheme.secondaryAccent : AppTheme.accent }

    var body: some View {
        Button(action: onReview) {
            HStack(alignment: .top, spacing: 12) {
                ExpenseIconBadge(systemName: isRefund ? "arrow.down.left" : (category?.icono ?? "envelope"), color: tint)
                    .padding(.top, 2).accessibilityHidden(true)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 10) {
                        details
                        amount
                    }
                    Spacer(minLength: 0)
                } else {
                    details
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 10) {
                        amount
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.tertiaryText).accessibilityHidden(true)
                    }
                }
            }
            .padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre la revisión del movimiento")
        .contextMenu { Button("Descartar movimiento", systemImage: "trash", role: .destructive, action: onDiscard) }
    }
    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(row.descripcion).font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Text([row.origen, dateLabel].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption).foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if isRefund || !row.coincidencias.isEmpty {
                Label(isRefund ? "Devolución" : "Posible duplicado", systemImage: isRefund ? "arrow.uturn.backward" : "square.on.square")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isRefund ? AppTheme.secondaryAccent : AppTheme.warning)
            }
        }
    }
    private var amount: some View {
        Text(row.monto, format: .currency(code: "USD"))
            .font(.subheadline.weight(.bold)).monospacedDigit()
            .foregroundStyle(AppTheme.primaryText).fixedSize(horizontal: true, vertical: false)
    }
    private var dateLabel: String {
        AppDateCodec.dateOnly(from: row.fecha)?.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))) ?? row.fecha
    }
}
