import WidgetKit

struct SpendingEntry: TimelineEntry {
    let date: Date
    /// `nil` cuando la app aún no dejó datos (no se abrió o no hay sesión).
    let summary: WidgetSummary?

    var calendar: Calendar { .current }

    var monthTotal: Double { summary?.monthTotal(containing: date, calendar: calendar) ?? 0 }
    var todayTotal: Double { summary?.total(on: date, calendar: calendar) ?? 0 }
    var budget: Double? { summary?.budgetAmount(for: date, calendar: calendar) }

    /// Variación del mes hasta hoy frente al mes pasado a la misma altura.
    /// `nil` si el mes pasado no hubo gastos con los que comparar.
    var monthChange: Double? {
        guard let summary else { return nil }
        let previous = summary.previousMonthToDate(date, calendar: calendar)
        guard previous > 0 else { return nil }
        return (summary.monthToDate(date, calendar: calendar) - previous) / previous
    }

    var monthName: String {
        date.formatted(.dateTime.month(.wide).locale(Locale(identifier: "es"))).capitalized
    }

    var previousMonthShortName: String {
        let previous = calendar.date(byAdding: .month, value: -1, to: date) ?? date
        return previous.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "es")))
    }

    static func sample(at date: Date = Date()) -> SpendingEntry {
        let calendar = Calendar.current
        var totals: [String: Double] = [:]
        let day = calendar.component(.day, from: date)
        for offset in 0..<day {
            if let current = calendar.date(byAdding: .day, value: -offset, to: date) {
                totals[WidgetSummary.dayKey(current, calendar: calendar)] = Double(18 + (offset * 7) % 40)
            }
            if let lastMonth = calendar.date(byAdding: .month, value: -1, to: date),
               let previous = calendar.date(byAdding: .day, value: -offset, to: lastMonth) {
                totals[WidgetSummary.dayKey(previous, calendar: calendar)] = Double(22 + (offset * 5) % 45)
            }
        }
        let parts = calendar.dateComponents([.year, .month], from: date)
        let budget = WidgetSummary.Budget(year: parts.year ?? 0, month: parts.month ?? 0, amount: 1_500)
        return SpendingEntry(date: date, summary: WidgetSummary(dailyTotals: totals, budget: budget))
    }
}

struct SpendingProvider: TimelineProvider {
    func placeholder(in context: Context) -> SpendingEntry {
        .sample()
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendingEntry) -> Void) {
        if context.isPreview, WidgetSummaryStore.load() == nil {
            completion(.sample())
        } else {
            completion(SpendingEntry(date: Date(), summary: WidgetSummaryStore.load()))
        }
    }

    /// Una entrada ahora y otra a medianoche: al cambiar el día «hoy» vuelve a
    /// cero (y el 1.º empieza mes) sin esperar a que se abra la app.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendingEntry>) -> Void) {
        let now = Date()
        let summary = WidgetSummaryStore.load()
        var entries = [SpendingEntry(date: now, summary: summary)]
        if let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) {
            entries.append(SpendingEntry(date: midnight, summary: summary))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
