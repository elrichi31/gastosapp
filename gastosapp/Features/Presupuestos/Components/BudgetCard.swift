import SwiftUI

struct BudgetCard: View {
    let budget: BudgetMonthly
    private static let shortMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.shortMonthSymbols ?? formatter.monthSymbols ?? []
    }()

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            monthBadge

            VStack(alignment: .leading, spacing: 5) {
                titleRow
                metaRow
            }
        }
        .padding(16)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(budget.monthTitle)
                .font(AppTheme.number(17, .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)

            Spacer(minLength: 4)

            Text(budget.total, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(AppTheme.number(17, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 5, height: 5)
            Text(budget.statusLabel)
                .foregroundStyle(statusColor)
            Text(verbatim: "·")
                .foregroundStyle(AppTheme.tertiaryText)
            Text(expenseCountLabel)
            Text(verbatim: "·")
                .foregroundStyle(AppTheme.tertiaryText)
            Text("Prom. \(budget.averageExpense.budgetCurrency)")
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if isCurrentMonth {
                Text("Actual")
                    .font(AppTheme.label(10))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.14)))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(AppTheme.secondaryText)
    }

    private var monthBadge: some View {
        VStack(spacing: 1) {
            Text(monthAbbreviation)
                .font(AppTheme.number(14, .semibold))
                .foregroundStyle(isCurrentMonth ? AppTheme.accent : AppTheme.primaryText)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(verbatim: "\(budget.anio)")
                .font(AppTheme.number(10, .medium))
                .foregroundStyle(AppTheme.tertiaryText)
                .monospacedDigit()
        }
        .frame(width: 52, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(isCurrentMonth ? AppTheme.accent.opacity(0.13) : AppTheme.insetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(isCurrentMonth ? AppTheme.accent.opacity(0.30) : AppTheme.border, lineWidth: 1)
                )
        )
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(isCurrentMonth ? AppTheme.accent.opacity(0.35) : AppTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 14, y: 6)
    }

    private var monthAbbreviation: String {
        let idx = max(min(budget.mes - 1, Self.shortMonthSymbols.count - 1), 0)
        return Self.shortMonthSymbols.indices.contains(idx) ? String(Self.shortMonthSymbols[idx].prefix(3)) : "—"
    }

    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == budget.anio && now.month == budget.mes
    }

    private var isPastMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let nowYear = now.year, let nowMonth = now.month else { return false }
        if budget.anio < nowYear { return true }
        if budget.anio > nowYear { return false }
        return budget.mes < nowMonth
    }

    private var relativeLabel: String {
        if isCurrentMonth { return "Mes actual" }
        return isPastMonth ? "Pasado" : "Próximo"
    }

    private var relativeIcon: String {
        if isCurrentMonth { return "dot.circle.fill" }
        return isPastMonth ? "checkmark.circle.fill" : "hourglass"
    }

    private var expenseCountLabel: String {
        budget.gastosRegistrados == 1 ? "1 gasto" : "\(budget.gastosRegistrados) gastos"
    }

    private var accent: Color {
        if isCurrentMonth { return AppTheme.accent }
        return isPastMonth ? AppTheme.secondaryText : AppTheme.secondaryAccent
    }

    private var statusColor: Color {
        switch budget.statusLabel.normalizedLookupKey {
        case let value where value.contains("completado"):
            return AppTheme.accent
        case let value where value.contains("progreso"):
            return AppTheme.secondaryAccent
        default:
            return AppTheme.secondaryText
        }
    }
}
