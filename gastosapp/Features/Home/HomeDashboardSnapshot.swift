import SwiftUI

struct HomeDashboardSnapshot {
    /// Gastos del mes en curso, del más reciente al más antiguo.
    let monthExpenses: [Expense]
    let monthTotal: Double
    let monthCategoryTotals: [(Categoria, Double)]
    let monthCategoryCounts: [Int: Int]
    /// Gasto de los últimos 7 días y de los 7 anteriores.
    let currentWeekTotal: Double
    let previousWeekTotal: Double
    let currentBudget: BudgetMonthly?
    let budgetMetrics: BudgetMonthlyMetrics?
    let budgetCategoryAlert: HomeBudgetCategoryAlert?
    let monthlyBudgetTarget: Double?
    let recent30DayBars: [DailyExpenseBar]
    let upcomingRecurringItems: [HomeRecurringPreview]
    let monthlyRecurringEstimate: Double
    let recurringDueSoonTotal: Double
    /// Recurrentes cuyo próximo cobro cae de hoy a fin de mes.
    let monthUpcomingRecurring: [HomeRecurringPreview]
    let monthUpcomingRecurringTotal: Double

    init(
        expenses: [Expense],
        recurringExpenses: [RecurringExpense],
        budget: BudgetMonthly?,
        budgetCategories: [BudgetCategoryDetail],
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        let startOfToday = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now

        monthExpenses = expenses
            .filter { $0.fecha >= monthStart && $0.fecha < monthEnd }
            .sorted { $0.fecha > $1.fecha }
        monthTotal = monthExpenses.reduce(0) { $0 + $1.monto }
        monthCategoryTotals = Self.categoryTotals(for: monthExpenses)
        monthCategoryCounts = monthExpenses.reduce(into: [:]) { $0[$1.categoriaId, default: 0] += 1 }

        currentWeekTotal = Self.total(inDaysAgoRange: 6, to: 0, expenses: expenses, calendar: calendar, today: startOfToday)
        previousWeekTotal = Self.total(inDaysAgoRange: 13, to: 7, expenses: expenses, calendar: calendar, today: startOfToday)

        currentBudget = budget
        if let budget {
            budgetMetrics = BudgetMonthlyMetrics(
                categories: budgetCategories,
                expenses: expenses,
                year: budget.anio,
                month: budget.mes
            )
            let spent = BudgetCategoryDetail.spentByCategory(expenses: expenses, year: budget.anio, month: budget.mes)
            budgetCategoryAlert = budgetCategories
                .map { category in
                    HomeBudgetCategoryAlert(category: category, metrics: category.metrics(spentByCategory: spent))
                }
                .filter { $0.metrics.budgeted > 0 }
                .max(by: { $0.metrics.progressPercentage < $1.metrics.progressPercentage })
        } else {
            budgetMetrics = nil
            budgetCategoryAlert = nil
        }

        if let budgetMetrics, budgetMetrics.budgeted > 0 {
            monthlyBudgetTarget = budgetMetrics.budgeted
        } else if let budget, budget.total > 0 {
            monthlyBudgetTarget = budget.total
        } else {
            monthlyBudgetTarget = nil
        }

        recent30DayBars = DailyExpenseBar.recentBars(from: expenses, endingAt: now, calendar: calendar)

        // `nextChargeDate` hace cálculos de calendario: se pide una sola vez
        // por recurrente, no en cada comparación del `sort`.
        let scheduled = recurringExpenses
            .compactMap { recurring -> HomeRecurringPreview? in
                guard recurring.activo, let date = recurring.nextChargeDate(referenceDate: now) else { return nil }
                return HomeRecurringPreview(expense: recurring, date: date)
            }
            .sorted { $0.date < $1.date }
        upcomingRecurringItems = Array(scheduled.prefix(3))
        monthlyRecurringEstimate = scheduled.reduce(0) { $0 + $1.expense.estimatedMonthlyAmount }
        let nextSevenDays = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
        recurringDueSoonTotal = scheduled.reduce(0) { partial, item in
            (item.date >= startOfToday && item.date < nextSevenDays) ? partial + item.expense.monto : partial
        }
        let inMonth = scheduled.filter { $0.date >= startOfToday && $0.date < monthEnd }
        monthUpcomingRecurring = Array(inMonth.prefix(4))
        monthUpcomingRecurringTotal = inMonth.reduce(0) { $0 + $1.expense.monto }
    }

    static func placeholder() -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            expenses: [],
            recurringExpenses: [],
            budget: nil,
            budgetCategories: []
        )
    }

    func expenses(for category: Categoria) -> [Expense] {
        monthExpenses.filter { $0.categoriaId == category.id }
    }

    private static func total(
        inDaysAgoRange startOffset: Int,
        to endOffset: Int,
        expenses: [Expense],
        calendar: Calendar,
        today: Date
    ) -> Double {
        guard
            let start = calendar.date(byAdding: .day, value: -startOffset, to: today),
            let endStart = calendar.date(byAdding: .day, value: -endOffset, to: today),
            let end = calendar.date(byAdding: .day, value: 1, to: endStart)
        else {
            return 0
        }
        return expenses.reduce(0) { $1.fecha >= start && $1.fecha < end ? $0 + $1.monto : $0 }
    }

    private static func categoryTotals(for expenses: [Expense]) -> [(Categoria, Double)] {
        expenses
            .reduce(into: [Categoria: Double]()) { $0[$1.categoria, default: 0] += $1.monto }
            .sorted { $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }
}

struct DailyExpenseBar: Identifiable {
    let date: Date
    let total: Double
    let segments: [DailyExpenseSegment]

    var id: Date { date }
}

struct DailyExpenseSegment: Identifiable {
    let id: Int
    let categoryName: String
    let amount: Double
    let fraction: Double
    let color: Color
}

struct HomeSmartInsight: Identifiable {
    let title: String
    let message: String
    let icon: String
    let tint: Color

    var id: String { title }
}

struct HomeBudgetCategoryAlert: Hashable {
    let category: BudgetCategoryDetail
    let metrics: BudgetCategoryMetrics
}

struct HomeRecurringPreview: Identifiable {
    let expense: RecurringExpense
    let date: Date

    var id: String {
        "\(expense.id)-\(date.timeIntervalSince1970)"
    }
}

extension DailyExpenseBar {
    /// Barras diarias de los últimos `days` días, de la más antigua a la más reciente.
    ///
    /// Vive aquí y no dentro de un snapshot concreto porque tanto Inicio como
    /// Análisis necesitan la misma serie.
    static func recentBars(
        from expenses: [Expense],
        days: Int = 30,
        endingAt end: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyExpenseBar] {
        let startOfEnd = calendar.startOfDay(for: end)
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: startOfEnd) else { return [] }

        let relevant = expenses.filter { $0.fecha >= start && $0.fecha <= end }
        let byDay = Dictionary(grouping: relevant) { calendar.startOfDay(for: $0.fecha) }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let dayExpenses = byDay[dayStart] ?? []
            let total = dayExpenses.reduce(0) { $0 + $1.monto }
            return DailyExpenseBar(date: dayStart, total: total, segments: segments(for: dayExpenses, total: total))
        }
    }

    private static func segments(for expenses: [Expense], total: Double) -> [DailyExpenseSegment] {
        guard total > 0 else { return [] }
        return Dictionary(grouping: expenses, by: \.categoria)
            .mapValues { $0.reduce(0) { $0 + $1.monto } }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.nombre.localizedCaseInsensitiveCompare($1.key.nombre) == .orderedAscending
            }
            .map { category, amount in
                DailyExpenseSegment(
                    id: category.id,
                    categoryName: category.nombre,
                    amount: amount,
                    fraction: amount / total,
                    color: category.color
                )
            }
    }
}
