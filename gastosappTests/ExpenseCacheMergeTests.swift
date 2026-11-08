import Foundation
import Testing
@testable import Zenlor

/// La caché de gastos se lee en segundo plano al arrancar y se junta con lo
/// que ya haya en pantalla; la lista del servidor se arma fuera del hilo
/// principal. Si esto falla, reaparecen gastos borrados o se duplican.
struct ExpenseCacheMergeTests {
    private static let comida = Categoria(id: 1, nombre: "Comida")
    private static let efectivo = ExpensePaymentMethod(id: 1, nombre: "Efectivo")

    private static func expense(_ id: Int, _ name: String, daysAgo: Int, amount: Double = 10) -> Expense {
        Expense(
            id: id, descripcion: name, monto: amount,
            fecha: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            categoria: comida, metodoPago: efectivo
        )
    }

    @Test func currentVersionWinsOverCachedOne() {
        let cached = [Self.expense(1, "Viejo", daysAgo: 3, amount: 5)]
        let current = [Self.expense(1, "Editado", daysAgo: 3, amount: 8)]
        let merged = ExpenseStore.mergeCachedExpenses(cached, into: current, excluding: [])
        #expect(merged.count == 1)
        #expect(merged.first?.descripcion == "Editado")
        #expect(merged.first?.monto == 8)
    }

    @Test func removedExpensesDoNotComeBack() {
        let cached = [Self.expense(1, "Borrado", daysAgo: 1), Self.expense(2, "Pendiente de borrar", daysAgo: 2),
                      Self.expense(3, "Queda", daysAgo: 3)]
        let merged = ExpenseStore.mergeCachedExpenses(cached, into: [], excluding: [1, 2])
        #expect(merged.map(\.id) == [3])
    }

    @Test func mergedListIsNewestFirst() {
        let cached = [Self.expense(1, "Hace 5", daysAgo: 5), Self.expense(2, "Hace 1", daysAgo: 1)]
        let current = [Self.expense(-7, "Nuevo sin sincronizar", daysAgo: 0), Self.expense(3, "Hace 3", daysAgo: 3)]
        let merged = ExpenseStore.mergeCachedExpenses(cached, into: current, excluding: [])
        #expect(merged.map(\.id) == [-7, 2, 3, 1])
    }

    @Test func buildExpensesSkipsPendingDeletionsAndAddsDrafts() async throws {
        let json = """
        [
          {"id": 10, "descripcion": "Café", "monto": 2.5, "fecha": "2026-11-05", "categoria_id": 1, "metodo_pago_id": 1},
          {"id": 11, "descripcion": "Borrado sin conexión", "monto": 9, "fecha": "2026-11-06", "categoria_id": 1, "metodo_pago_id": 1},
          {"id": 12, "descripcion": "Taxi", "monto": 4, "fecha": "2026-11-01", "categoria_id": 99, "metodo_pago_id": 1}
        ]
        """
        let remote = try JSONDecoder().decode([RemoteExpense].self, from: Data(json.utf8))
        let draft = PendingExpenseDraft(
            id: "draft", localExpenseID: -5, descripcion: "Sin conexión", monto: 3,
            fecha: try #require(AppDateCodec.dateOnly(from: "2026-11-07")), categoriaId: 1, metodoPagoId: 1
        )

        let built = await ExpenseStore.buildExpenses(
            remote: remote, pending: [draft], excluding: [11],
            categorias: [Self.comida], metodosPago: [Self.efectivo]
        )

        #expect(built.map(\.id) == [-5, 10, 12])
        #expect(built.first { $0.id == 10 }?.categoria.nombre == "Comida")
        // Categoría que no está en el catálogo: no se pierde el gasto.
        #expect(built.first { $0.id == 12 }?.categoria.nombre == "Otros")
    }
}
