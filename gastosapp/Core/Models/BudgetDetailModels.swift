import Foundation

struct BudgetCategoryDetail: Identifiable, Hashable, Codable {
    let id: Int
    let categoriaId: Int
    let totalCategoria: Double
    let cantidadGastos: Int
    let categoria: BudgetCategoryInfo
    let movimientos: [BudgetMovement]

    enum CodingKeys: String, CodingKey {
        case id
        case categoriaId = "categoria_id"
        case totalCategoria = "total_categoria"
        case cantidadGastos = "cantidad_gastos"
        case categoria
        case movimientos
    }

    var displayCategory: Categoria {
        Categoria(id: categoriaId, nombre: categoria.nombre)
    }

    var budgetedAmount: Double {
        movimientos.reduce(0) { $0 + $1.monto }
    }

    func spentAmount(expenses: [Expense], year: Int, month: Int) -> Double {
        expenses
            .filter { expense in
                expense.categoriaId == categoriaId &&
                expense.fecha.matchesBudgetMonth(year: year, month: month)
            }
            .reduce(0) { $0 + $1.monto }
    }

    func metrics(expenses: [Expense], year: Int, month: Int) -> BudgetCategoryMetrics {
        let spent = spentAmount(expenses: expenses, year: year, month: month)
        return BudgetCategoryMetrics(budgeted: budgetedAmount, spent: spent)
    }
}

struct BudgetCategoryMetrics: Hashable {
    let budgeted: Double
    let spent: Double

    var remaining: Double {
        max(0, budgeted - spent)
    }

    var difference: Double {
        budgeted - spent
    }

    var progressPercentage: Double {
        guard budgeted > 0 else { return 0 }
        return (spent / budgeted) * 100
    }

    var progressValue: Double {
        min(progressPercentage / 100, 1)
    }

    var isOverBudget: Bool {
        spent > budgeted
    }

    var status: String {
        if budgeted == 0 {
            return "Sin presupuesto"
        }
        if difference > 0 {
            return "Bajo presupuesto"
        }
        if difference == 0 {
            return "En presupuesto"
        }
        return "Sobre presupuesto"
    }
}

struct BudgetMonthlyMetrics: Hashable {
    let budgeted: Double
    let spent: Double

    init(categories: [BudgetCategoryDetail], expenses: [Expense], year: Int, month: Int) {
        budgeted = categories.reduce(0) { $0 + $1.budgetedAmount }
        spent = expenses
            .filter { $0.fecha.matchesBudgetMonth(year: year, month: month) }
            .reduce(0) { $0 + $1.monto }
    }

    var remaining: Double {
        max(0, budgeted - spent)
    }

    var difference: Double {
        budgeted - spent
    }

    var progressPercentage: Double {
        guard budgeted > 0 else { return 0 }
        return (spent / budgeted) * 100
    }

    var progressValue: Double {
        min(progressPercentage / 100, 1)
    }

    var isOverBudget: Bool {
        spent > budgeted
    }

    var status: String {
        if budgeted == 0 {
            return "Sin presupuesto"
        }
        if difference > 0 {
            return "Bajo presupuesto"
        }
        if difference == 0 {
            return "En presupuesto"
        }
        return "Sobre presupuesto"
    }
}

struct BudgetCategoryInfo: Hashable, Codable {
    let nombre: String
}

struct BudgetMovement: Identifiable, Hashable, Codable {
    let id: Int
    let presupuestoCategoriaId: Int?
    var descripcion: String
    var monto: Double
    var fecha: String
    var metodoPagoId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case presupuestoCategoriaId = "presupuesto_categoria_id"
        case descripcion
        case monto
        case fecha
        case metodoPagoId = "metodo_pago_id"
    }

    var parsedDate: Date {
        AppDateCodec.dateOnly(from: fecha) ?? Date()
    }

    var dateLabel: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: parsedDate)
        guard let day = components.day, let month = components.month, let year = components.year else { return "" }
        return String(format: "%02d/%02d/%04d", day, month, year)
    }

}

private extension Date {
    func matchesBudgetMonth(year: Int, month: Int, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.year, .month], from: self)
        return components.year == year && components.month == month
    }
}
