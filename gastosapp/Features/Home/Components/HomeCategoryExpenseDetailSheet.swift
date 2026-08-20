import SwiftUI

struct HomeCategoryExpenseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Categoria
    let expenses: [Expense]
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()
    private static let spanishWeekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.weekdaySymbols
    }()

    private var groups: [CategoryExpenseDayGroup] {
        Dictionary(grouping: expenses) { Calendar.current.startOfDay(for: $0.fecha) }
            .map { date, expenses in
                CategoryExpenseDayGroup(date: date, expenses: expenses.sorted { $0.fecha > $1.fecha })
            }
            .sorted { $0.date > $1.date }
    }

    private var total: Double {
        expenses.reduce(0) { $0 + $1.monto }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    sheetHint
                    ForEach(groups) { group in
                        daySection(group)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 34)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icono)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 42, height: 42)
                .background(category.color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            titleBlock
            Spacer()
            closeButton
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.nombre)
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("\(expenses.count) registros · \(total.budgetCurrency)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.50))
        }
    }

    private var closeButton: some View {
        Button(action: dismiss.callAsFunction) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.72))
                .frame(width: 36, height: 36)
                .background(Circle().fill(AppTheme.primaryText.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cerrar")
    }

    private var sheetHint: some View {
        HStack(spacing: 9) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption.weight(.bold))
                .foregroundStyle(category.color)
            Text("Agrupado por fecha con total diario")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.58))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(AppTheme.primaryText.opacity(0.055)))
    }

    private func daySection(_ group: CategoryExpenseDayGroup) -> some View {
        VStack(spacing: 10) {
            dayHeader(group)
            VStack(spacing: 8) {
                ForEach(group.expenses) { expense in
                    expenseRow(expense)
                }
            }
        }
    }

    private func dayHeader(_ group: CategoryExpenseDayGroup) -> some View {
        HStack(spacing: 10) {
            Text(dayTitle(group.date))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.80))
            Rectangle()
                .fill(AppTheme.primaryText.opacity(0.07))
                .frame(height: 1)
            Text(group.total.budgetCurrency)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText.opacity(0.58))
        }
    }

    private func expenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(expense.descripcion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(expense.metodoPago.shortLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.46))
            }
            Spacer()
            Text(expense.monto.budgetCurrency)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(14)
        .background(AppTheme.cardBackground(cornerRadius: 18))
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        let components = calendar.dateComponents([.weekday, .day, .month], from: date)
        guard
            let weekday = components.weekday,
            let day = components.day,
            let month = components.month,
            Self.spanishWeekdaySymbols.indices.contains(weekday - 1),
            Self.spanishMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(Self.spanishWeekdaySymbols[weekday - 1]), \(day) de \(Self.spanishMonthSymbols[month - 1])".capitalized
    }
}

private struct CategoryExpenseDayGroup: Identifiable {
    let date: Date
    let expenses: [Expense]

    var id: Date { date }
    var total: Double { expenses.reduce(0) { $0 + $1.monto } }
}
