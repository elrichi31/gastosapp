import Foundation

/// Nombres de meses y días en español, compartidos por toda la app.
enum SpanishCalendar {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter
    }()

    static let monthSymbols: [String] = formatter.monthSymbols
    static let shortMonthSymbols: [String] = formatter.shortMonthSymbols ?? formatter.monthSymbols ?? []
    static let weekdaySymbols: [String] = formatter.weekdaySymbols
}
