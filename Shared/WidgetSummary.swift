import Foundation

/// Resumen de gastos que la app deja en el App Group para los widgets.
///
/// El widget no puede leer la caché de `ExpenseStore`, así que la app le pasa
/// sólo lo que necesita: el gasto de cada día del mes en curso y del anterior,
/// y el presupuesto del mes. Con eso el widget calcula «hoy», «este mes» y la
/// comparación aunque cambie el día sin que se abra la app.
struct WidgetSummary: Codable, Equatable {
    struct Budget: Codable, Equatable {
        let year: Int
        let month: Int
        let amount: Double
    }

    /// Gasto por día, con clave `aaaa-MM-dd` en el calendario del usuario.
    var dailyTotals: [String: Double]
    var budget: Budget?

    static let empty = WidgetSummary(dailyTotals: [:], budget: nil)

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func total(on date: Date, calendar: Calendar = .current) -> Double {
        dailyTotals[Self.dayKey(date, calendar: calendar)] ?? 0
    }

    /// Todo el mes de `date`, también lo fechado más adelante (igual que Resumen).
    func monthTotal(containing date: Date, calendar: Calendar = .current) -> Double {
        let prefix = String(Self.dayKey(date, calendar: calendar).prefix(8))
        return dailyTotals.reduce(0) { $1.key.hasPrefix(prefix) ? $0 + $1.value : $0 }
    }

    /// Del día 1 hasta `date` inclusive.
    func monthToDate(_ date: Date, calendar: Calendar = .current) -> Double {
        let day = calendar.component(.day, from: date)
        return total(ofMonthContaining: date, throughDay: day, calendar: calendar)
    }

    /// El mes anterior, del día 1 al mismo día que hoy: compara a igual altura.
    func previousMonthToDate(_ date: Date, calendar: Calendar = .current) -> Double {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: date) else { return 0 }
        let day = calendar.component(.day, from: date)
        return total(ofMonthContaining: previous, throughDay: day, calendar: calendar)
    }

    func budgetAmount(for date: Date, calendar: Calendar = .current) -> Double? {
        let parts = calendar.dateComponents([.year, .month], from: date)
        guard let budget, budget.year == parts.year, budget.month == parts.month, budget.amount > 0 else {
            return nil
        }
        return budget.amount
    }

    private func total(ofMonthContaining date: Date, throughDay day: Int, calendar: Calendar) -> Double {
        let prefix = String(Self.dayKey(date, calendar: calendar).prefix(8))
        return dailyTotals.reduce(0) { sum, item in
            guard item.key.hasPrefix(prefix), let itemDay = Int(item.key.suffix(2)), itemDay <= day else {
                return sum
            }
            return sum + item.value
        }
    }
}

/// Lectura y escritura del resumen en el contenedor compartido app ↔ widget.
enum WidgetSummaryStore {
    static let appGroupID = "group.zenlor.gastosapp"
    static let widgetURL = URL(string: "zenlor://resumen")!
    private static let key = "widget.summary"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func load() -> WidgetSummary? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }

    static func save(_ summary: WidgetSummary?) {
        guard let summary else {
            defaults?.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(summary) else { return }
        defaults?.set(data, forKey: key)
    }
}
