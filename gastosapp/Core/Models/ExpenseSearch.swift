import Foundation

/// Reglas de búsqueda de gastos, las mismas en toda la app.
///
/// Antes el panel de Resumen, Plan y Análisis buscaba sólo por comercio,
/// categoría y monto, y el de Gastos además por pago, etiquetas y fecha: una
/// misma palabra daba resultados distintos según la pestaña.
enum ExpenseSearch {
    static let hint = "Busca por comercio, categoría, etiqueta, forma de pago o monto."

    /// Sin distinguir mayúsculas ni tildes.
    ///
    /// Se mira campo a campo y se para en el primero que coincide: el monto y
    /// la fecha, que hay que formatear, van al final porque son lo más caro y
    /// esto corre sobre todos los gastos a cada tecla.
    static func matches(_ expense: Expense, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        func has(_ text: String) -> Bool { text.localizedStandardContains(query) }
        if has(expense.descripcion) || has(expense.categoria.nombre)
            || has(expense.metodoPago.nombre) || has(expense.metodoPago.shortLabel) {
            return true
        }
        if let tags = expense.tags, tags.contains(where: { has($0) || has("#" + $0) }) {
            return true
        }
        return has(MoneyInput.format(expense.monto)) || has(expense.fecha.formatted(dayMonthStyle))
    }

    private static let dayMonthStyle = Date.FormatStyle.dateTime.day().month(.wide).locale(Locale(identifier: "es"))

    static func matches(_ category: Categoria, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return !query.isEmpty && category.nombre.localizedStandardContains(query)
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
