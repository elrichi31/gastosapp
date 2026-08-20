import Foundation

extension RecurringExpense {
    var estimatedMonthlyAmount: Double {
        switch frecuencia {
        case .mensual:
            return monto
        case .semanal:
            return monto * 52 / 12
        }
    }

    func relativeNextChargeLabel(calendar: Calendar = .current, referenceDate: Date = Date()) -> String {
        guard let nextChargeDate else { return "Sin próximo cobro" }

        let today = calendar.startOfDay(for: referenceDate)
        let target = calendar.startOfDay(for: nextChargeDate)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0

        if days == 0 { return "Hoy" }
        if days == 1 { return "Mañana" }
        return "En \(days) días"
    }
}
