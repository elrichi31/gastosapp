import Foundation

struct RecurringExpense: Identifiable, Hashable, Codable {
    private static let spanishShortMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.shortMonthSymbols ?? formatter.monthSymbols ?? []
    }()

    let id: Int
    var descripcion: String
    var monto: Double
    var frecuencia: RecurringFrequency
    var diaMes: Int?
    var diaSemana: Int?
    var fechaInicio: Date
    var fechaFin: Date?
    var activo: Bool
    var categoriaId: Int
    var metodoPagoId: Int
    var categoria: Categoria
    var annualMonth: Int? = nil
    var foreignTax: ForeignTax? = nil
    var scheduledNextDate: String? = nil
    var metodoPago: ExpensePaymentMethod

    var isSubscriptionLike: Bool {
        categoria.nombre.normalizedLookupKey.contains("suscrip")
    }

    var scheduleLabel: String {
        guard activo else { return "Pausado" }
        guard let nextChargeDate else { return "Finalizado" }
        return "Próximo cobro: \(Self.dateLabel(for: nextChargeDate))"
    }

    var nextChargeDate: Date? { nextChargeDate(referenceDate: Date()) }

    func nextChargeDate(referenceDate: Date) -> Date? {
        guard activo else { return nil }
        if let scheduledNextDate, let candidate = AppDateCodec.flexibleDate(from: scheduledNextDate) {
            return candidateWithinEndDate(candidate, calendar: .current)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let firstAllowedDate = max(today, calendar.startOfDay(for: fechaInicio))

        switch frecuencia {
        case .anual:
            for year in calendar.component(.year, from: firstAllowedDate)...(calendar.component(.year, from: firstAllowedDate) + 3) {
                let month = annualMonth ?? calendar.component(.month, from: fechaInicio)
                guard let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
                      let range = calendar.range(of: .day, in: .month, for: start),
                      let candidate = calendar.date(from: DateComponents(year: year, month: month, day: min(diaMes ?? 1, range.count))) else { continue }
                if candidate >= firstAllowedDate { return candidateWithinEndDate(candidate, calendar: calendar) }
            }
            return nil
        case .mensual:
            return nextMonthlyChargeDate(from: firstAllowedDate, calendar: calendar)
        case .semanal:
            return nextWeeklyChargeDate(from: firstAllowedDate, calendar: calendar)
        }
    }

    var cadenceLabel: String {
        switch frecuencia {
        case .anual:
            return "Cada año • mes \(annualMonth ?? 1), día \(diaMes ?? 1)"
        case .mensual:
            return "Cada mes\(diaMes.map { " • día \($0)" } ?? "")"
        case .semanal:
            if let diaSemana {
                return "Cada semana • \(RecurringExpense.weekdayLabel(for: diaSemana))"
            }
            return "Cada semana"
        }
    }

    private func nextMonthlyChargeDate(from date: Date, calendar: Calendar) -> Date? {
        let desiredDay = min(max(diaMes ?? calendar.component(.day, from: fechaInicio), 1), 31)
        var cursor = date

        for _ in 0..<36 {
            let components = calendar.dateComponents([.year, .month], from: cursor)
            if let year = components.year,
               let month = components.month,
               let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
               let days = calendar.range(of: .day, in: .month, for: monthStart),
               let candidate = calendar.date(from: DateComponents(year: year, month: month, day: min(desiredDay, days.count))),
               candidate >= date {
                return candidateWithinEndDate(candidate, calendar: calendar)
            }
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: cursor) else { return nil }
            cursor = nextMonth
        }

        return nil
    }

    private func nextWeeklyChargeDate(from date: Date, calendar: Calendar) -> Date? {
        let desiredWeekday = diaSemana ?? Self.weekdayNumber(for: fechaInicio, calendar: calendar)
        let currentWeekday = Self.weekdayNumber(for: date, calendar: calendar)
        let daysUntilNext = (desiredWeekday - currentWeekday + 7) % 7

        guard let candidate = calendar.date(byAdding: .day, value: daysUntilNext, to: date) else {
            return nil
        }

        return candidateWithinEndDate(candidate, calendar: calendar)
    }

    private func candidateWithinEndDate(_ candidate: Date, calendar: Calendar) -> Date? {
        guard let fechaFin else { return candidate }
        return candidate <= calendar.startOfDay(for: fechaFin) ? candidate : nil
    }

    private static func dateLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "hoy"
        }

        let components = Calendar.current.dateComponents([.day, .month], from: date)
        guard
            let day = components.day,
            let month = components.month,
            Self.spanishShortMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(day) \(Self.spanishShortMonthSymbols[month - 1])"
    }

    private static func weekdayNumber(for date: Date, calendar: Calendar) -> Int {
        let current = calendar.component(.weekday, from: date)
        return current == 1 ? 7 : current - 1
    }

    static func weekdayLabel(for value: Int) -> String {
        switch value {
        case 1: return "Lunes"
        case 2: return "Martes"
        case 3: return "Miércoles"
        case 4: return "Jueves"
        case 5: return "Viernes"
        case 6: return "Sábado"
        case 7: return "Domingo"
        default: return "Lunes"
        }
    }
}
