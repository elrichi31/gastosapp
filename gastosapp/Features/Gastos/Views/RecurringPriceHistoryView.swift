import SwiftUI

struct RecurringPriceHistoryView: View {
    @Environment(ExpenseStore.self) private var store
    @State private var changes: [RecurringPriceChange] = []
    @State private var loading = true
    @State private var error: String?
    var body: some View {
        List {
            if loading { ProgressView("Cargando precios…") }
            if let error { Text(error).foregroundStyle(AppTheme.negative); Button("Reintentar") { Task { await load() } } }
            if !loading && error == nil && changes.isEmpty { ContentUnavailableView("Sin cambios de precio", systemImage: "clock") }
            ForEach(changes) { change in
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.recurringExpenses.first { $0.id == change.gasto_recurrente_id }?.descripcion ?? "Recurrente #\(change.gasto_recurrente_id)").font(.headline)
                    Text("\(MoneyInput.format(change.monto_anterior)) → \(MoneyInput.format(change.monto_nuevo)) USD")
                    Text(change.cambiado_en.prefix(10)).font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("Historial de precios").floatingTabBarInset()
            .task { await load() }.refreshable { await load() }
    }
    private func load() async {
        loading = true; error = nil
        defer { loading = false }
        do { changes = try await store.request([RecurringPriceChange].self, path: "/api/gastos-recurrentes/precios", requiresAuth: true) }
        catch { if !isCancellationError(error) { self.error = error.localizedDescription } }
    }
}
