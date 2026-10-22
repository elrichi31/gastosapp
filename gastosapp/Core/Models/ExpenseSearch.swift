import Foundation
import Synchronization

/// Reglas de búsqueda de gastos, las mismas en toda la app.
///
/// Antes el panel de Resumen, Plan y Análisis buscaba sólo por comercio,
/// categoría y monto, y el de Gastos además por pago, etiquetas y fecha: una
/// misma palabra daba resultados distintos según la pestaña.
enum ExpenseSearch {
    static let hint = "Busca por comercio, categoría, etiqueta, forma de pago o monto."

    /// Sin distinguir mayúsculas ni tildes.
    static func matches(_ expense: Expense, query: String) -> Bool {
        matcher(for: query)(expense)
    }

    /// Filtro para recorrer muchos gastos con la misma búsqueda: la consulta
    /// se normaliza una vez, no por cada gasto.
    static func matcher(for query: String) -> (Expense) -> Bool {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).normalizedLookupKey
        guard !needle.isEmpty else { return { _ in true } }
        return { haystack(for: $0).contains(needle) }
    }

    /// Todo lo buscable de un gasto, ya sin tildes ni mayúsculas, separado por
    /// saltos de línea para que una búsqueda no junte dos campos.
    ///
    /// Formatear el monto y la fecha y normalizar cada campo costaba más que
    /// la búsqueda en sí, y se hacía con todos los gastos a cada tecla. Se
    /// guarda por gasto: si el gasto cambia es otra clave y se vuelve a armar.
    private static let haystackCache = Mutex<[Expense: String]>([:])

    private static func haystack(for expense: Expense) -> String {
        if let cached = haystackCache.withLock({ $0[expense] }) { return cached }
        let fields = [
            expense.descripcion,
            expense.categoria.nombre,
            expense.metodoPago.nombre,
            expense.metodoPago.shortLabel,
            MoneyInput.format(expense.monto),
            expense.fecha.formatted(dayMonthStyle)
        ] + (expense.tags ?? []).flatMap { [$0, "#" + $0] }
        let text = fields.joined(separator: "\n").normalizedLookupKey
        haystackCache.withLock { cache in
            // Tope para que gastos editados o borrados no se acumulen sin fin.
            if cache.count > 20_000 { cache.removeAll(keepingCapacity: true) }
            cache[expense] = text
        }
        return text
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
