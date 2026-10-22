import Foundation

enum ExpensesListRowItem: Identifiable {
    case day(Date, Double)
    case expense(Expense)

    var id: String {
        switch self {
        case let .day(date, _):
            return "day-\(date.timeIntervalSince1970)"
        case let .expense(expense):
            return "expense-\(expense.id)"
        }
    }
}

struct ExpensesListSnapshot {
    let monthExpensesBase: [Expense]
    let monthExpenses: [Expense]
    let feedItems: [ExpensesListRowItem]
    let total: Double
    /// Total y número de gastos filtrados por día del mes, para las barras.
    let dayTotals: [Int: Double]
    let dayCounts: [Int: Int]
    /// Categorías del mes ordenadas por gasto, para los chips.
    let categories: [Categoria]
    let tags: [String]
    /// Gasto del tramo comparable del mes anterior.
    let previousTotal: Double

    /// Todo lo que la vista necesita se calcula aquí una vez: el `body` se
    /// reevalúa a cada arrastre sobre el gráfico y no debe reagrupar gastos.
    init(
        expenses: [Expense],
        monthStart: Date,
        previousRange: Range<Date>? = nil,
        calendar: Calendar = .current,
        visibleTags: (Expense) -> [String] = { $0.tags ?? [] },
        recurrenceMatches: (Expense) -> Bool,
        paymentMatches: (Expense) -> Bool,
        searchMatches: (Expense) -> Bool
    ) {
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
        monthExpensesBase = expenses.filter { $0.fecha >= monthStart && $0.fecha < monthEnd }
        monthExpenses = monthExpensesBase.filter { expense in
            recurrenceMatches(expense) && paymentMatches(expense) && searchMatches(expense)
        }

        let groups = Dictionary(grouping: monthExpenses) { calendar.startOfDay(for: $0.fecha) }
            .map { (date: $0.key, expenses: $0.value.sorted { $0.fecha > $1.fecha }) }
            .sorted { $0.date > $1.date }

        var feed: [ExpensesListRowItem] = []
        feed.reserveCapacity(groups.count + monthExpenses.count)
        var dayTotals: [Int: Double] = [:]
        var dayCounts: [Int: Int] = [:]
        var total = 0.0
        for group in groups {
            let dayTotal = group.expenses.reduce(0) { $0 + $1.monto }
            let day = calendar.component(.day, from: group.date)
            dayTotals[day] = dayTotal
            dayCounts[day] = group.expenses.count
            total += dayTotal
            feed.append(.day(group.date, dayTotal))
            feed.append(contentsOf: group.expenses.map(ExpensesListRowItem.expense))
        }
        feedItems = feed
        self.dayTotals = dayTotals
        self.dayCounts = dayCounts
        self.total = total

        var categoryTotals: [Categoria: Double] = [:]
        var tagSet: Set<String> = []
        for expense in monthExpensesBase {
            categoryTotals[expense.categoria, default: 0] += expense.monto
            tagSet.formUnion(visibleTags(expense))
        }
        categories = categoryTotals.sorted { $0.value > $1.value }.map(\.key)
        tags = tagSet.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        previousTotal = previousRange.map { range in
            expenses.reduce(0) { range.contains($1.fecha) ? $0 + $1.monto : $0 }
        } ?? 0
    }

    static func placeholder(monthStart: Date) -> ExpensesListSnapshot {
        ExpensesListSnapshot(
            expenses: [],
            monthStart: monthStart,
            recurrenceMatches: { _ in true },
            paymentMatches: { _ in true },
            searchMatches: { _ in true }
        )
    }
}
