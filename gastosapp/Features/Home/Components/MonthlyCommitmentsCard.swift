import SwiftUI

struct MonthlyCommitmentsCard: View {
    @Environment(ExpenseStore.self) private var session
    @Environment(BudgetStore.self) private var budgets
    @State private var model = ExpenseForecastStore()
    @State private var showDetails = false
    private var budget: BudgetMonthly? {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return budgets.budgets.first { $0.anio == now.year && $0.mes == now.month }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disponible del mes").font(.headline)
            if model.isLoading { ProgressView() }
            if let error = model.error { Text(error).font(.caption).foregroundStyle(AppTheme.negative); Button("Reintentar") { Task { await model.load(using: session) } } }
            if session.pendingExpenseCount > 0 { Text("Hay gastos locales por sincronizar; este cálculo usa los datos del servidor.").font(.caption).foregroundStyle(AppTheme.warning) }
            if let f = model.forecast {
                LabeledContent("Compromisos pendientes", value: f.committed.formatted(.currency(code: "USD")))
                if let budget {
                    let available = budget.total - f.floor
                    LabeledContent("Después de compromisos", value: available.formatted(.currency(code: "USD")))
                    let remainingDays = f.days - Calendar.current.component(.day, from: Date()) + 1
                    LabeledContent("Disponible por día", value: (max(0, available) / Double(max(1, remainingDays))).formatted(.currency(code: "USD")))
                    if available < 0 { Text("Los gastos y compromisos superan el presupuesto.").font(.caption).foregroundStyle(AppTheme.warning) }
                } else { Text("Crea un presupuesto para calcular lo disponible.").font(.caption) }
                Button("Ver proyección y próximos cobros") { showDetails = true }
            }
        }.padding(16).background(AppTheme.controlSurface, in: .rect(cornerRadius: 20))
            .onChange(of: session.recurringExpenses) { Task { await model.load(using: session) } }
            .task(id: session.gastos) { await model.load(using: session) }
            .sheet(isPresented: $showDetails) { NavigationStack { ExpenseForecastView().toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { showDetails = false } } } } }
    }
}
