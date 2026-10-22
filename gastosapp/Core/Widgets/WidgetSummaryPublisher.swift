import Foundation
import WidgetKit

/// Mantiene al día el resumen que leen los widgets y les pide redibujarse.
///
/// Sólo escribe (y recarga) cuando el resumen cambia de verdad: `gastos` se
/// toca a menudo y recargar los widgets sin motivo gasta su cupo diario.
@MainActor
enum WidgetSummaryPublisher {
    static func publish(expenses: [Expense], calendar: Calendar = .current, now: Date = Date()) {
        guard
            let month = calendar.dateInterval(of: .month, for: now),
            let start = calendar.date(byAdding: .month, value: -1, to: month.start)
        else { return }

        var totals: [String: Double] = [:]
        for expense in expenses where expense.fecha >= start && expense.fecha < month.end {
            totals[WidgetSummary.dayKey(expense.fecha, calendar: calendar), default: 0] += expense.monto
        }
        update { $0.dailyTotals = totals }
    }

    static func publish(budget amount: Double?, calendar: Calendar = .current, now: Date = Date()) {
        let parts = calendar.dateComponents([.year, .month], from: now)
        update { summary in
            summary.budget = amount.flatMap { amount in
                guard amount > 0, let year = parts.year, let month = parts.month else { return nil }
                return WidgetSummary.Budget(year: year, month: month, amount: amount)
            }
        }
    }

    /// Al cerrar sesión el widget no debe seguir mostrando los gastos de nadie.
    static func clear() {
        guard current != nil else { return }
        WidgetSummaryStore.save(nil)
        cache = .some(nil)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Copia en memoria de lo guardado: sólo esta app escribe el resumen, así
    /// que no hace falta leerlo y decodificarlo del disco a cada cambio.
    private static var cache: WidgetSummary??

    private static var current: WidgetSummary? {
        if let cache { return cache }
        let loaded = WidgetSummaryStore.load()
        cache = .some(loaded)
        return loaded
    }

    private static func update(_ change: (inout WidgetSummary) -> Void) {
        let current = current
        var next = current ?? .empty
        change(&next)
        guard next != current else { return }
        WidgetSummaryStore.save(next)
        cache = .some(next)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
