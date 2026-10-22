import Foundation

/// Comparativas del mes en curso para la pantalla Resumen.
///
/// Cada cifra se compara con el mismo tramo del mes anterior (del día 1 al día
/// de hoy) y no con el mes anterior entero, que todavía no es comparable.
struct HomeMonthPulse {
    struct BudgetCategoryLine: Identifiable {
        let id: Int
        let name: String
        let metrics: BudgetCategoryMetrics
    }

    struct CalendarDay: Identifiable {
        let date: Date
        let day: Int
        let total: Double
        let count: Int
        let isFuture: Bool

        var id: Date { date }
    }

    let monthTotal: Double
    let dayOfMonth: Int
    let daysInMonth: Int
    let monthTitle: String

    let todayTotal: Double
    let todayCount: Int
    let yesterdayTotal: Double

    let monthCount: Int
    let previousPeriodTotal: Double
    let previousPeriodCount: Int
    /// «1–12 sep»: el tramo del mes anterior que se compara.
    let previousPeriodLabel: String

    let pacePerDay: Double
    let projectedClose: Double
    let previousMonthTotal: Double
    /// «sep»
    let previousMonthShortName: String

    let budgetLines: [BudgetCategoryLine]
    /// Días del mes en curso, con un hueco inicial para alinear el lunes.
    let calendarLeadingBlanks: Int
    let calendarDays: [CalendarDay]
    /// Se consulta por cada celda del calendario: va calculado de antemano.
    let maxDailyTotal: Double

    init(
        expenses: [Expense],
        monthTotal: Double,
        budget: BudgetMonthly?,
        budgetCategories: [BudgetCategoryDetail],
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.monthTotal = monthTotal
        let startOfToday = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let previousMonthStart = calendar.date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) ?? now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? now

        dayOfMonth = calendar.component(.day, from: now)
        daysInMonth = calendar.range(of: .day, in: .month, for: now)?.count ?? 30
        let previousMonthDays = calendar.range(of: .day, in: .month, for: previousMonthStart)?.count ?? 30
        let comparableDays = min(dayOfMonth, previousMonthDays)
        let previousPeriodEnd = calendar.date(byAdding: .day, value: comparableDays, to: previousMonthStart) ?? monthStart

        func sum(_ items: [Expense]) -> Double { items.reduce(0) { $0 + $1.monto } }
        // Todo lo que sigue cae del mes anterior en adelante: se filtra ese
        // tramo una vez en lugar de recorrer el historial entero en cada cifra.
        let recent = expenses.filter { $0.fecha >= previousMonthStart }
        func within(_ start: Date, _ end: Date) -> [Expense] { recent.filter { $0.fecha >= start && $0.fecha < end } }

        let today = within(startOfToday, tomorrow)
        todayTotal = sum(today)
        todayCount = today.count
        yesterdayTotal = sum(within(yesterday, startOfToday))

        let month = within(monthStart, tomorrow)
        monthCount = month.count
        let previousPeriod = within(previousMonthStart, previousPeriodEnd)
        previousPeriodTotal = sum(previousPeriod)
        previousPeriodCount = previousPeriod.count
        previousMonthTotal = sum(within(previousMonthStart, monthStart))

        let shortMonth = Self.shortMonthFormatter.string(from: previousMonthStart).replacingOccurrences(of: ".", with: "")
        previousMonthShortName = shortMonth
        previousPeriodLabel = comparableDays == 1 ? "1 \(shortMonth)" : "1–\(comparableDays) \(shortMonth)"
        monthTitle = Self.monthTitleFormatter.string(from: now).capitalized

        pacePerDay = monthTotal / Double(max(dayOfMonth, 1))
        projectedClose = pacePerDay * Double(daysInMonth)

        if let budget {
            let spent = BudgetCategoryDetail.spentByCategory(expenses: expenses, year: budget.anio, month: budget.mes)
            budgetLines = budgetCategories
                .map {
                    BudgetCategoryLine(
                        id: $0.id,
                        name: $0.displayCategory.nombre,
                        metrics: $0.metrics(spentByCategory: spent)
                    )
                }
                .filter { $0.metrics.budgeted > 0 }
                .sorted { $0.metrics.progressPercentage > $1.metrics.progressPercentage }
        } else {
            budgetLines = []
        }

        let weekday = calendar.component(.weekday, from: monthStart)
        calendarLeadingBlanks = (weekday + 5) % 7
        let byDay = Dictionary(grouping: within(monthStart, calendar.date(byAdding: .month, value: 1, to: monthStart) ?? tomorrow)) {
            calendar.component(.day, from: $0.fecha)
        }
        calendarDays = (1...daysInMonth).compactMap { day in
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) else { return nil }
            let items = byDay[day] ?? []
            return CalendarDay(date: date, day: day, total: sum(items), count: items.count, isFuture: date > startOfToday)
        }
        maxDailyTotal = calendarDays.map(\.total).max() ?? 0
    }

    var monthDelta: Double? { Self.change(from: previousPeriodTotal, to: monthTotal) }
    var todayDelta: Double? { Self.change(from: yesterdayTotal, to: todayTotal) }
    var countDelta: Double? { Self.change(from: Double(previousPeriodCount), to: Double(monthCount)) }
    var projectionDelta: Double? { Self.change(from: previousMonthTotal, to: projectedClose) }

    var averageTicket: Double {
        monthCount > 0 ? monthTotal / Double(monthCount) : 0
    }

    var daysWithSpending: Int { calendarDays.filter { $0.total > 0 }.count }

    /// Variación porcentual, o `nil` cuando no hay base para comparar.
    static func change(from base: Double, to value: Double) -> Double? {
        guard base > 0 else { return nil }
        return (value - base) / base * 100
    }

    static func placeholder() -> HomeMonthPulse {
        HomeMonthPulse(expenses: [], monthTotal: 0, budget: nil, budgetCategories: [])
    }

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let monthTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()
}
