import Foundation

/// Período que analiza la pestaña Análisis: un mes concreto o todo el historial.
enum StatsPeriod: Hashable, Identifiable {
    case month(year: Int, month: Int)
    case all

    var id: String {
        switch self {
        case let .month(year, month): return "\(year)-\(month)"
        case .all: return "all"
        }
    }
}

/// Cifras de un período de gasto para la pestaña Análisis.
///
/// Un mes en curso se compara con el mismo tramo del mes anterior; un mes
/// cerrado, con el mes anterior completo. «Todo el historial» no se compara.
struct StatsPeriodAnalysis {
    struct Point: Identifiable {
        /// Día del mes (1…31) o, en el historial, índice del mes (0…).
        let index: Int
        let label: String
        let total: Double
        let count: Int
        let isFuture: Bool

        var id: Int { index }
    }

    struct CumulativePoint {
        let index: Int
        let total: Double
    }

    struct CategoryLine: Identifiable {
        let category: Categoria
        let total: Double
        let count: Int
        let share: Double
        /// Diferencia en dinero contra el período anterior, si lo hay.
        let previousTotal: Double?

        var id: Int { category.id }
        var delta: Double? { previousTotal.flatMap { HomeMonthPulse.change(from: $0, to: total) } }
    }

    struct Bucket: Identifiable {
        let label: String
        let total: Double
        let count: Int

        var id: String { label }
    }

    struct WeekLine: Identifiable {
        let label: String
        let total: Double
        let count: Int
        let days: Int

        var id: String { label }
    }

    /// Partes de calendario de una fecha, con claves numéricas para agrupar.
    struct DayParts {
        let year: Int
        let month: Int
        let day: Int
        let weekday: Int

        var monthKey: Int { year * 12 + month }
        var dayKey: Int { (year * 12 + month) * 32 + day }
    }

    struct PaymentLine: Identifiable {
        let name: String
        let total: Double
        let count: Int

        var id: String { name }
    }

    let period: StatsPeriod
    let title: String
    let shortTitle: String

    let expenses: [Expense]
    let previous: [Expense]?
    let previousLabel: String?

    let total: Double
    let previousTotal: Double?
    let isRange: Bool
    let isInProgress: Bool
    /// Días transcurridos del período (hoy incluido en un mes en curso).
    let elapsedDays: Int

    let points: [Point]
    let previousPoints: [Point]
    /// Acumulados para el modo «Acumulado» del gráfico, calculados una vez.
    let cumulative: [CumulativePoint]
    let previousCumulative: [CumulativePoint]
    let categories: [CategoryLine]
    let weekdayTotals: [Double]
    let weekdayDays: [Int]
    let weeks: [WeekLine]
    let buckets: [Bucket]
    let payments: [PaymentLine]

    // Cifras que antes se recalculaban en cada `body`; ahora una vez por período.
    let concentration: Double
    let daysWithSpending: Int
    let median: Double
    let recurring: (total: Double, count: Int)
    let biggestChange: CategoryLine?
    let peakDay: (date: Date, total: Double, count: Int)?
    let topExpenses: [Expense]

    init(period: StatsPeriod, allExpenses: [Expense], calendar: Calendar = .current, now: Date = Date()) {
        self.period = period
        let startOfToday = calendar.startOfDay(for: now)

        func sum(_ items: [Expense]) -> Double { items.reduce(0) { $0 + $1.monto } }
        func within(_ start: Date, _ end: Date) -> [Expense] {
            allExpenses.filter { $0.fecha >= start && $0.fecha < end }
        }

        // Año, mes, día y día de la semana de cada fecha, calculados una vez
        // por fecha distinta: con miles de gastos, pedirle al calendario cada
        // dato por gasto era casi todo el coste de «Todo el historial».
        var partsCache: [Date: DayParts] = [:]
        func parts(_ date: Date) -> DayParts {
            if let cached = partsCache[date] { return cached }
            let components = calendar.dateComponents([.year, .month, .day, .weekday], from: date)
            let resolved = DayParts(
                year: components.year ?? 0,
                month: components.month ?? 0,
                day: components.day ?? 0,
                weekday: components.weekday ?? 1
            )
            partsCache[date] = resolved
            return resolved
        }

        switch period {
        case let .month(year, month):
            let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? now
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? now
            let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            let inProgress = start <= now && now < end
            let elapsed = inProgress ? calendar.component(.day, from: now) : days
            let previousStart = calendar.date(byAdding: .month, value: -1, to: start) ?? start
            let previousDays = calendar.range(of: .day, in: .month, for: previousStart)?.count ?? 30
            let previousEnd = inProgress
                ? calendar.date(byAdding: .day, value: min(elapsed, previousDays), to: previousStart) ?? start
                : start
            let monthName = Self.monthFormatter.string(from: start).capitalized
            let previousName = Self.monthFormatter.string(from: previousStart).capitalized

            title = "\(monthName) \(year)"
            shortTitle = "\(monthName.prefix(3)) \(year)"
            isRange = true
            isInProgress = inProgress
            elapsedDays = elapsed
            expenses = within(start, end)

            let previousItems = within(previousStart, previousEnd)
            let previousMonthItems = within(previousStart, start)
            let previousMonthHasData = !previousMonthItems.isEmpty
            previous = previousMonthHasData ? previousItems : nil
            previousLabel = previousMonthHasData ? previousName : nil

            let byDay = Dictionary(grouping: expenses) { parts($0.fecha).day }
            let short = Self.shortMonthFormatter.string(from: start).replacingOccurrences(of: ".", with: "")
            points = (1...days).map { day in
                let items = byDay[day] ?? []
                let date = calendar.date(byAdding: .day, value: day - 1, to: start) ?? start
                return Point(index: day, label: "\(day) \(short)", total: sum(items), count: items.count, isFuture: date > startOfToday)
            }
            let previousByDay = Dictionary(grouping: previousMonthItems) { parts($0.fecha).day }
            previousPoints = previousMonthHasData ? (1...previousDays).map { day in
                let items = previousByDay[day] ?? []
                return Point(index: day, label: "\(day)", total: sum(items), count: items.count, isFuture: false)
            } : []

            weeks = stride(from: 1, through: days, by: 7).map { first in
                let last = min(first + 6, days)
                let items = (first...last).flatMap { byDay[$0] ?? [] }
                let counted = inProgress ? max(0, min(last, elapsed) - first + 1) : last - first + 1
                return WeekLine(label: "\(first)–\(last) \(short)", total: sum(items), count: items.count, days: counted)
            }
            .filter { $0.days > 0 }

        case .all:
            // La tienda ya los guarda del más reciente al más antiguo: basta
            // con darles la vuelta. Ordenar miles de gastos era lo más caro.
            let isNewestFirst = zip(allExpenses, allExpenses.dropFirst()).allSatisfy { $0.fecha >= $1.fecha }
            let sorted = isNewestFirst ? Array(allExpenses.reversed()) : allExpenses.sorted { $0.fecha < $1.fecha }
            title = "Todo el historial"
            shortTitle = "Todo"
            isRange = false
            isInProgress = false
            expenses = sorted
            previous = nil
            previousLabel = nil
            previousPoints = []
            weeks = []

            if let first = sorted.first,
               let firstMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: first.fecha)) {
                let lastMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                let months = (calendar.dateComponents([.month], from: firstMonth, to: lastMonth).month ?? 0) + 1
                let byMonth = Dictionary(grouping: sorted) { parts($0.fecha).monthKey }
                points = (0..<max(months, 1)).compactMap { offset in
                    guard let date = calendar.date(byAdding: .month, value: offset, to: firstMonth) else { return nil }
                    let items = byMonth[parts(date).monthKey] ?? []
                    let label = Self.shortMonthFormatter.string(from: date).replacingOccurrences(of: ".", with: "")
                        + " " + String(calendar.component(.year, from: date) % 100)
                    return Point(index: offset, label: label, total: sum(items), count: items.count, isFuture: false)
                }
                elapsedDays = (calendar.dateComponents([.day], from: calendar.startOfDay(for: first.fecha), to: startOfToday).day ?? 0) + 1
            } else {
                points = []
                elapsedDays = 0
            }
        }

        total = sum(expenses)
        previousTotal = previous.map(sum)

        var running = 0.0
        cumulative = points.filter { !$0.isFuture }.map { point in
            running += point.total
            return CumulativePoint(index: point.index, total: running)
        }
        running = 0
        let lastIndex = points.last?.index ?? 0
        previousCumulative = previousPoints.filter { $0.index <= lastIndex }.map { point in
            running += point.total
            return CumulativePoint(index: point.index, total: running)
        }

        let previousByCategory = previous.map { items in
            Dictionary(grouping: items, by: \.categoriaId).mapValues(sum)
        }
        let totalAmount = total
        categories = Dictionary(grouping: expenses, by: \.categoria)
            .map { category, items in
                CategoryLine(
                    category: category,
                    total: sum(items),
                    count: items.count,
                    share: totalAmount > 0 ? sum(items) / totalAmount : 0,
                    previousTotal: previousByCategory.map { $0[category.id] ?? 0 }
                )
            }
            .sorted { $0.total > $1.total }

        // Lunes primero, como en el calendario de Resumen.
        var weekdayTotals = Array(repeating: 0.0, count: 7)
        for expense in expenses {
            weekdayTotals[(parts(expense.fecha).weekday + 5) % 7] += expense.monto
        }
        self.weekdayTotals = weekdayTotals
        var weekdayDays = Array(repeating: 0, count: 7)
        if case let .month(year, month) = period,
           let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
            for offset in 0..<elapsedDays {
                guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
                weekdayDays[(calendar.component(.weekday, from: date) + 5) % 7] += 1
            }
        }
        self.weekdayDays = weekdayDays

        let limits: [(String, Double)] = [("Hasta $10", 10), ("$10–$50", 50), ("$50–$100", 100), ("Más de $100", .infinity)]
        let periodExpenses = expenses
        var computedBuckets: [Bucket] = []
        var lower = -Double.infinity
        for (label, upper) in limits {
            let items = periodExpenses.filter { $0.monto > lower && $0.monto <= upper }
            computedBuckets.append(Bucket(label: label, total: sum(items), count: items.count))
            lower = upper
        }
        buckets = computedBuckets

        payments = Dictionary(grouping: expenses) { $0.metodoPago.shortLabel }
            .map { PaymentLine(name: $0.key, total: sum($0.value), count: $0.value.count) }
            .sorted { $0.total > $1.total }

        concentration = total > 0 ? categories.prefix(3).reduce(0) { $0 + $1.total } / total * 100 : 0
        let byDay = Dictionary(grouping: expenses) { parts($0.fecha).dayKey }
        daysWithSpending = byDay.count
        let amounts = expenses.map(\.monto).sorted()
        if amounts.isEmpty {
            median = 0
        } else {
            let middle = amounts.count / 2
            median = amounts.count.isMultiple(of: 2) ? (amounts[middle - 1] + amounts[middle]) / 2 : amounts[middle]
        }
        let recurringItems = expenses.filter(\.isRecurrent)
        recurring = (sum(recurringItems), recurringItems.count)
        biggestChange = previous == nil ? nil : categories
            .filter { ($0.previousTotal ?? 0) != $0.total }
            .max { abs($0.total - ($0.previousTotal ?? 0)) < abs($1.total - ($1.previousTotal ?? 0)) }
        peakDay = byDay.values
            .map { items in (items: items, total: sum(items)) }
            .max { $0.total < $1.total }
            .flatMap { peak in
                peak.items.first.map { (date: calendar.startOfDay(for: $0.fecha), total: peak.total, count: peak.items.count) }
            }
        // Los cinco mayores sin ordenar todo el período.
        var top: [Expense] = []
        for expense in expenses where top.count < 5 || expense.monto > top[top.count - 1].monto {
            let index = top.firstIndex { expense.monto > $0.monto } ?? top.endIndex
            top.insert(expense, at: index)
            if top.count > 5 { top.removeLast() }
        }
        topExpenses = top
    }

    // MARK: - Derivados

    var totalDelta: Double? { previousTotal.flatMap { HomeMonthPulse.change(from: $0, to: total) } }

    var comparisonText: String {
        guard let previousLabel else {
            return isRange ? "Sin período anterior comparable" : "Suma de todos los meses"
        }
        return isInProgress ? "que \(previousLabel.lowercased()) al día \(elapsedDays)" : "que \(previousLabel.lowercased())"
    }

    var dailyAverage: Double { elapsedDays > 0 ? total / Double(elapsedDays) : 0 }
    var averageTicket: Double { expenses.isEmpty ? 0 : total / Double(expenses.count) }

    var dailyAverageDelta: Double? {
        previousTotal.flatMap { HomeMonthPulse.change(from: $0 / Double(max(elapsedDays, 1)), to: dailyAverage) }
    }

    var countDelta: Double? {
        previous.flatMap { HomeMonthPulse.change(from: Double($0.count), to: Double(expenses.count)) }
    }

    var ticketDelta: Double? {
        guard let previous, !previous.isEmpty, let previousTotal else { return nil }
        return HomeMonthPulse.change(from: previousTotal / Double(previous.count), to: averageTicket)
    }

    /// Meses con gastos, del más reciente al más antiguo; el mes en curso siempre.
    static func availablePeriods(from expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) -> [StatsPeriod] {
        let current = calendar.dateComponents([.year, .month], from: now)
        var months = Set(expenses.map { calendar.dateComponents([.year, .month], from: $0.fecha) })
        months.insert(current)
        let sorted = months
            .compactMap { components -> (Int, Int)? in
                guard let year = components.year, let month = components.month else { return nil }
                return (year, month)
            }
            .filter { ($0.0, $0.1) <= (current.year ?? 0, current.month ?? 0) }
            .sorted { ($0.0, $0.1) > ($1.0, $1.1) }
        return sorted.prefix(24).map { StatsPeriod.month(year: $0.0, month: $0.1) } + [.all]
    }

    static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "LLLL"
        return formatter
    }()

    static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMM"
        return formatter
    }()
}
