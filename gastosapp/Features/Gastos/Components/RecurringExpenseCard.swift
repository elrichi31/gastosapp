import SwiftUI

struct RecurringExpenseCard: View {
    let item: RecurringExpense

    var body: some View {
        HStack(spacing: 14) {
            icon
            details
            Spacer(minLength: 10)
            amountPill
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Desliza hacia la izquierda para editar o eliminar")
    }

    private var icon: some View {
        CategoryGlyph(categoria: item.categoria, size: 42)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            Text(item.scheduleLabel)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            metadataRow
        }
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(item.descripcion)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
            typePill
        }
    }

    private var metadataRow: some View {
        HStack(spacing: 8) {
            metaPill(
                icon: item.categoria.icono,
                text: item.categoria.nombre,
                tint: AppTheme.controlSurface,
                foreground: AppTheme.primaryText
            )
            metaPill(
                icon: item.metodoPago.icono,
                text: item.metodoPago.shortLabel,
                tint: AppTheme.surface,
                foreground: AppTheme.secondaryText
            )
        }
    }

    private var amountPill: some View {
        Text("$\(MoneyInput.format(item.monto))")
            .font(.system(size: 15, weight: .bold, design: .default))
            .foregroundStyle(AppTheme.primaryText)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var typePill: some View {
        let color = item.isSubscriptionLike ? AppTheme.secondaryAccent : AppTheme.accent
        return Text(item.isSubscriptionLike ? "Suscripción" : "Recurrente")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .frame(height: 22)
            .background(AppTheme.capsuleBackground(color.opacity(0.14)))
    }

    private func metaPill(icon: String, text: String, tint: Color, foreground: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(AppTheme.capsuleBackground(tint))
    }
}
