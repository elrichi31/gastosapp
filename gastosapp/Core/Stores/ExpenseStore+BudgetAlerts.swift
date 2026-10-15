import Foundation

extension ExpenseStore {
    /// A failed alert lookup must never turn a successful expense write into a failure.
    func budgetCrossingMessage(before: [Expense]) async -> String? {
        let now = Date()
        let components = Calendar.current.dateComponents([.year, .month], from: now)
        let month = String(AppDateCodec.apiDateString(from: now).prefix(7))
        let old = before.filter { AppDateCodec.apiDateString(from: $0.fecha).hasPrefix(month) }
        let current = gastos.filter { AppDateCodec.apiDateString(from: $0.fecha).hasPrefix(month) }
        let oldTotals = Dictionary(grouping: old, by: \.categoriaId).mapValues { $0.reduce(0) { $0 + $1.monto } }
        let newTotals = Dictionary(grouping: current, by: \.categoriaId).mapValues { $0.reduce(0) { $0 + $1.monto } }
        guard newTotals.contains(where: { $0.value > (oldTotals[$0.key] ?? 0) }) else { return nil }
        do {
            let budgets = try await request([BudgetMonthly].self, path: "/api/presupuestos?anio=\(components.year ?? 0)", requiresAuth: true)
            guard let budget = budgets.first(where: { $0.mes == components.month }) else { return nil }
            let categories = try await request([BudgetCategoryDetail].self,
                path: "/api/presupuesto-mensual-detalle?presupuesto_mensual_id=\(budget.id)", requiresAuth: true)
            return categories.compactMap { category in
                BudgetCrossing.message(before: oldTotals[category.categoriaId] ?? 0,
                    after: newTotals[category.categoriaId] ?? 0, limit: category.budgetedAmount,
                    category: category.categoria.nombre)
            }.joined(separator: " ").nilIfEmpty
        } catch { return nil }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
