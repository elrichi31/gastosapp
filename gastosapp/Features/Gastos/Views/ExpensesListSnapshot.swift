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

    init(
        expenses: [Expense],
        monthStart: Date,
        calendar: Calendar = .current,
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

        feedItems = groups.flatMap { group in
            let dayTotal = group.expenses.reduce(0) { $0 + $1.monto }
            let rows = group.expenses.map(ExpensesListRowItem.expense)
            return [ExpensesListRowItem.day(group.date, dayTotal)] + rows
        }
        total = monthExpenses.reduce(0) { $0 + $1.monto }
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
