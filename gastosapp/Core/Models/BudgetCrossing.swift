import Foundation

enum BudgetCrossing {
    static func message(before: Double, after: Double, limit: Double, category: String) -> String? {
        let b = ForeignTax.cents(before), a = ForeignTax.cents(after), p = ForeignTax.cents(limit)
        if b <= p && a > p { return "Superaste el presupuesto de \(category)." }
        if p > 0 && b < p * 0.8 && a >= p * 0.8 && a <= p {
            return "Llegaste al 80% del presupuesto de \(category)."
        }
        return nil
    }
}
