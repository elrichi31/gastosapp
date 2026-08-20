import Foundation

struct BudgetMonthly: Identifiable, Hashable, Codable {
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

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
        guard Self.spanishMonthSymbols.indices.contains(index) else { return "Mes" }
        return Self.spanishMonthSymbols[index].capitalized
    }

    var monthYearTitle: String {
        "\(monthTitle) \(anio)"
    }

    var totalLabel: String {
        total.budgetCurrency
    }

    var statusLabel: String {
        mappedStatus.label
    }

    var averageExpense: Double {
        gastosRegistrados > 0 ? total / Double(gastosRegistrados) : 0
    }

    var previousMonthTotal: Double {
        0
    }

    var trendPercentage: Double {
        previousMonthTotal > 0 ? round(((total - previousMonthTotal) / previousMonthTotal) * 100) : 0
    }

    var trendLabel: String {
        switch tendencia?.lowercased() {
        case "up":
            return "Subiendo"
        case "down":
            return "Bajando"
        default:
            return "Estable"
        }
    }

    var mappedStatus: BudgetMonthStatus {
        BudgetMonthStatus(rawStatus: estado, year: anio, month: mes)
    }

    var trendSymbol: String {
        switch tendencia?.lowercased() {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "arrow.right"
        }
    }
}

struct BudgetMonthStatus: Hashable {
    let label: String
    let icon: String

    init(rawStatus: String?, year: Int, month: Int, calendar: Calendar = .current) {
        let trimmed = rawStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty {
            label = trimmed
        } else if Self.isPast(year: year, month: month, calendar: calendar) {
            label = "Completado"
        } else {
            label = "En progreso"
        }

        switch label.normalizedLookupKey {
        case let value where value.contains("completado"):
            icon = "checkmark.circle.fill"
        case let value where value.contains("progreso"):
            icon = "dot.circle.fill"
        default:
            icon = "circle.fill"
        }
    }

    private static func isPast(year: Int, month: Int, calendar: Calendar) -> Bool {
        let now = calendar.dateComponents([.year, .month], from: Date())
        guard let currentYear = now.year, let currentMonth = now.month else { return false }
        if year < currentYear { return true }
        if year > currentYear { return false }
        return month < currentMonth
    }
}

extension Double {
    var budgetCurrency: String {
        formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
