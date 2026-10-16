import Foundation
import Testing
@testable import Zenlor

struct ExpenseSearchTests {
    private let food = Categoria(id: 1, nombre: "Alimentación")
    private let transport = Categoria(id: 2, nombre: "Transporte")
    private let card = ExpensePaymentMethod(id: 1, nombre: "Tarjeta de crédito")

    @Test func matchesCategoryTagsAndPaymentIgnoringAccents() {
        let expense = Expense(descripcion: "Supermaxi", monto: 42.3, fecha: Date(), categoria: food, metodoPago: card, tags: ["casa"])
        #expect(ExpenseSearch.matches(expense, query: "alimentacion"))
        #expect(ExpenseSearch.matches(expense, query: "#casa"))
        #expect(ExpenseSearch.matches(expense, query: "credito"))
        #expect(ExpenseSearch.matches(expense, query: "42.30"))
        #expect(!ExpenseSearch.matches(expense, query: "uber"))
    }

    @Test func suggestionsComeFromCatalogEvenWithoutExpenses() {
        #expect(ExpenseSearch.suggestedCategories(catalog: [transport, food], expenses: []).map(\.id) == [1, 2])
        let ride = Expense(descripcion: "Uber", monto: 5, fecha: Date(), categoria: transport, metodoPago: card)
        #expect(ExpenseSearch.suggestedCategories(catalog: [food, transport], expenses: [ride]).first?.id == 2)
    }
}
