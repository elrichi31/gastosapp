import SwiftUI

enum HomeDashboardScope: String, CaseIterable, Identifiable {
    case today
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Hoy"
        case .week: return "Semana"
        case .month: return "Mes"
        }
    }
}

struct HomeDashboardSnapshot {
    let monthExpenses: [Expense]
    let monthTotal: Double
    let monthAveragePerDay: Double
    let monthMaxExpense: Double
    let monthCategoryTotals: [(Categoria, Double)]
    let todayExpenses: [Expense]
    let calendarWeekExpenses: [Expense]
    let trailingWeekExpenses: [Expense]
    let previousTrailingWeekExpenses: [Expense]
    let scopedExpenses: [Expense]
    let scopedTotal: Double
    let scopedHighestExpense: Double
    let scopedAverageAmount: Double
    let scopedDailyAverage: Double
    let scopedCategoryTotals: [(Categoria, Double)]
    let currentBudget: BudgetMonthly?
    let budgetMetrics: BudgetMonthlyMetrics?
    let budgetCategoryAlert: HomeBudgetCategoryAlert?
    let monthlyBudgetTarget: Double?
    let currentMonthExpenseByDay: [Date: Double]
    let recent30DayBars: [DailyExpenseBar]
    let nextRecurringPreview: HomeRecurringPreview?
    let upcomingRecurringItems: [HomeRecurringPreview]
    let monthlyRecurringEstimate: Double
    let recurringDueSoonTotal: Double

    let scope: HomeDashboardScope

    init(
        expenses: [Expense],
        recurringExpenses: [RecurringExpense],
        budget: BudgetMonthly?,
        budgetCategories: [BudgetCategoryDetail],
        scope: HomeDashboardScope,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.scope = scope

        let startOfToday = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? now

        monthExpenses = expenses
            .filter { $0.fecha >= monthStart && $0.fecha < monthEnd }
            .sorted { $0.fecha > $1.fecha }
        monthTotal = monthExpenses.reduce(0) { $0 + $1.monto }
        monthAveragePerDay = monthTotal / Double(max(calendar.component(.day, from: now), 1))
        monthMaxExpense = monthExpenses.map(\.monto).max() ?? 0
        monthCategoryTotals = Self.categoryTotals(for: monthExpenses)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        todayExpenses = expenses
            .filter { $0.fecha >= startOfToday && $0.fecha < tomorrow }
            .sorted { $0.fecha > $1.fecha }

        let weekday = calendar.component(.weekday, from: startOfToday)
        let offsetToMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -offsetToMonday, to: startOfToday) ?? startOfToday
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? tomorrow
        calendarWeekExpenses = expenses
            .filter { $0.fecha >= weekStart && $0.fecha < weekEnd }
            .sorted { $0.fecha > $1.fecha }

        trailingWeekExpenses = Self.expenses(inDaysAgoRange: 6, to: 0, expenses: expenses, calendar: calendar, today: startOfToday)
        previousTrailingWeekExpenses = Self.expenses(inDaysAgoRange: 13, to: 7, expenses: expenses, calendar: calendar, today: startOfToday)

        scopedExpenses = switch scope {
        case .today: todayExpenses
        case .week: calendarWeekExpenses
        case .month: monthExpenses
        }
        scopedTotal = scopedExpenses.reduce(0) { $0 + $1.monto }
        scopedHighestExpense = scopedExpenses.map(\.monto).max() ?? 0
        scopedAverageAmount = scopedExpenses.isEmpty ? 0 : scopedTotal / Double(scopedExpenses.count)
        scopedDailyAverage = switch scope {
        case .today:
            scopedTotal
        case .week:
            scopedTotal / 7
        case .month:
            scopedTotal / Double(max(calendar.component(.day, from: now), 1))
        }
        scopedCategoryTotals = Self.categoryTotals(for: scopedExpenses)

        currentBudget = budget
        if let budget {
            budgetMetrics = BudgetMonthlyMetrics(
                categories: budgetCategories,
                expenses: expenses,
                year: budget.anio,
                month: budget.mes
            )
            budgetCategoryAlert = budgetCategories
                .map { category in
                    HomeBudgetCategoryAlert(
                        category: category,
                        metrics: category.metrics(expenses: expenses, year: budget.anio, month: budget.mes)
                    )
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

        currentMonthExpenseByDay = Dictionary(grouping: monthExpenses) { calendar.startOfDay(for: $0.fecha) }
            .mapValues { $0.reduce(0) { $0 + $1.monto } }

        recent30DayBars = DailyExpenseBar.recentBars(from: expenses, endingAt: now, calendar: calendar)

        let activeRecurring = recurringExpenses
            .filter { $0.activo && $0.nextChargeDate != nil }
            .sorted { ($0.nextChargeDate ?? .distantFuture) < ($1.nextChargeDate ?? .distantFuture) }
        upcomingRecurringItems = activeRecurring.prefix(3).compactMap { recurring in
            guard let date = recurring.nextChargeDate else { return nil }
            return HomeRecurringPreview(expense: recurring, date: date)
        }
        nextRecurringPreview = upcomingRecurringItems.first
        monthlyRecurringEstimate = activeRecurring.reduce(0) { $0 + $1.estimatedMonthlyAmount }
        let nextSevenDays = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? now
        recurringDueSoonTotal = activeRecurring.reduce(0) { partial, recurring in
            guard let nextChargeDate = recurring.nextChargeDate else { return partial }
            return (nextChargeDate >= startOfToday && nextChargeDate < nextSevenDays) ? partial + recurring.monto : partial
        }
    }

    static func placeholder(scope: HomeDashboardScope = .month) -> HomeDashboardSnapshot {
        HomeDashboardSnapshot(
            expenses: [],
            recurringExpenses: [],
            budget: nil,
            budgetCategories: [],
            scope: scope
        )
    }

    var scopedSummaryTitle: String {
        switch scope {
        case .today: return "Gastado hoy"
        case .week: return "Gastado esta semana"
        case .month: return "Gastado este mes"
        }
    }

    var scopedMetricTitle: String {
        switch scope {
        case .today: return "Ticket prom."
        case .week, .month: return "Promedio/día"
        }
    }

    var scopedCategoryTitle: String {
        switch scope {
        case .today: return "hoy"
        case .week: return "esta semana"
        case .month: return "este mes"
        }
    }

    var currentWeekTotal: Double {
        trailingWeekExpenses.reduce(0) { $0 + $1.monto }
    }

    var previousWeekTotal: Double {
        previousTrailingWeekExpenses.reduce(0) { $0 + $1.monto }
    }

    func expenses(for category: Categoria) -> [Expense] {
        scopedExpenses
            .filter { $0.categoriaId == category.id }
            .sorted { $0.fecha > $1.fecha }
    }

    private static func expenses(
        inDaysAgoRange startOffset: Int,
        to endOffset: Int,
        expenses: [Expense],
        calendar: Calendar,
        today: Date
    ) -> [Expense] {
        guard
            let start = calendar.date(byAdding: .day, value: -startOffset, to: today),
            let endStart = calendar.date(byAdding: .day, value: -endOffset, to: today),
            let end = calendar.date(byAdding: .day, value: 1, to: endStart)
        else {
            return []
        }
        return expenses.filter { $0.fecha >= start && $0.fecha < end }
    }

    private static func categoryTotals(for expenses: [Expense]) -> [(Categoria, Double)] {
        Dictionary(grouping: expenses, by: \.categoria)
            .mapValues { $0.reduce(0) { $0 + $1.monto } }
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
