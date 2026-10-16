import Foundation

/// Reglas de búsqueda de gastos, las mismas en toda la app.
///
/// Antes el panel de Resumen, Plan y Análisis buscaba sólo por comercio,
/// categoría y monto, y el de Gastos además por pago, etiquetas y fecha: una
/// misma palabra daba resultados distintos según la pestaña.
enum ExpenseSearch {
    static let hint = "Busca por comercio, categoría, etiqueta, forma de pago o monto."

    /// Sin distinguir mayúsculas ni tildes.
    static func matches(_ expense: Expense, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        return tokens(for: expense).contains { $0.localizedStandardContains(query) }
    }

    static func matches(_ category: Categoria, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !query.isEmpty && category.nombre.localizedStandardContains(query)
    }

    private static func tokens(for expense: Expense) -> [String] {
        [
            expense.descripcion,
            expense.categoria.nombre,
            expense.metodoPago.nombre,
            expense.metodoPago.shortLabel,
            MoneyInput.format(expense.monto),
            expense.fecha.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es")))
        ] + (expense.tags ?? []).flatMap { [$0, "#" + $0] }
    }

    /// Categorías para sugerir: las del catálogo, primero las más usadas.
    ///
    /// Sale del catálogo y no de los gastos cargados, así que aparecen también
    /// en una pestaña que todavía no ha cargado gastos.
    static func suggestedCategories(catalog: [Categoria], expenses: [Expense], limit: Int = 8) -> [Categoria] {
        var usage: [Int: Int] = [:]
        for expense in expenses { usage[expense.categoriaId, default: 0] += 1 }
        let source = catalog.isEmpty ? Array(Set(expenses.map(\.categoria))) : catalog
        return source
            .sorted {
                let left = usage[$0.id] ?? 0, right = usage[$1.id] ?? 0
                return left != right ? left > right : $0.nombre.localizedCompare($1.nombre) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
