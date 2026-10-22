import Foundation

struct BudgetMonthly: Identifiable, Hashable, Codable {
    let id: Int
    let anio: Int
    let mes: Int
    var total: Double
    var gastosRegistrados: Int
    var tendencia: String?
    var estado: String?
    var userId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case anio
        case mes
        case total
        case gastosRegistrados = "gastos_registrados"
        case tendencia
        case estado
        case userId = "user_id"
    }

    var monthTitle: String {
        let index = max(mes - 1, 0)
        guard SpanishCalendar.monthSymbols.indices.contains(index) else { return "Mes" }
        return SpanishCalendar.monthSymbols[index].capitalized
    }

    var monthYearTitle: String {
        "\(monthTitle) \(anio)"
    }

    var totalLabel: String {
        total.budgetCurrency
    }

}

extension Double {
    var budgetCurrency: String {
        formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
