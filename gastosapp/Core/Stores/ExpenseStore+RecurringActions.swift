import Foundation

extension ExpenseStore {
    func skipRecurringCharge(_ item: RecurringExpense) async -> Bool {
        guard !isSavingExpense else { return false }
        isSavingExpense = true
        defer { isSavingExpense = false }
        do {
            struct Result: Decodable { let omitida: String }
            let result = try await request(Result.self, path: "/api/gastos-recurrentes/\(item.id)/saltar", method: "POST", requiresAuth: true)
            await loadRecurringExpenses(force: true)
            syncStatusMessage = "Cobro del \(result.omitida) omitido"
            saveErrorMessage = nil
            return true
        } catch {
            if !isCancellationError(error) { saveErrorMessage = error.localizedDescription }
            return false
        }
    }

    func toggleRecurring(_ item: RecurringExpense) async -> Bool {
        await updateRecurringExpense(id: item.id, descripcion: item.descripcion, monto: item.monto,
            fechaInicio: item.fechaInicio, categoria: item.categoria, metodoPago: item.metodoPago,
            frecuencia: item.frecuencia, diaMes: item.diaMes, diaSemana: item.diaSemana, activo: !item.activo,
            fechaFin: item.fechaFin, annualMonth: item.annualMonth, foreignTax: item.foreignTax)
    }
}
