import SwiftUI

struct HomeCategoryExpenseDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Categoria
    let expenses: [Expense]
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
            CategoryGlyph(categoria: category, size: 42)
            titleBlock
            Spacer()
            closeButton
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(category.nombre)
                .font(.title3.bold())
                .foregroundStyle(AppTheme.primaryText)
            Text("\(expenses.count) registros · \(total.budgetCurrency)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var closeButton: some View {
        AppCircleButton(icon: "xmark", label: "Cerrar", action: dismiss.callAsFunction)
    }

    private var sheetHint: some View {
        HStack(spacing: 9) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.accent)
            Text("Agrupado por fecha con total diario")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(Capsule().fill(AppTheme.controlSurface))
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
                .foregroundStyle(AppTheme.primaryText)
            Rectangle()
                .fill(AppTheme.controlSurface)
                .frame(height: 1)
            Text(group.total.budgetCurrency)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
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
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            Spacer()
            Text(expense.monto.budgetCurrency)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(14)
        .background((
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            ))
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
            SpanishCalendar.weekdaySymbols.indices.contains(weekday - 1),
            SpanishCalendar.monthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(SpanishCalendar.weekdaySymbols[weekday - 1]), \(day) de \(SpanishCalendar.monthSymbols[month - 1])".capitalized
    }
}

private struct CategoryExpenseDayGroup: Identifiable {
    let date: Date
    let expenses: [Expense]

    var id: Date { date }
    var total: Double { expenses.reduce(0) { $0 + $1.monto } }
}
