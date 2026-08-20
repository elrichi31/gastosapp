import Foundation

enum AppDateCodec {
    static func apiDateString(from date: Date) -> String {
        apiDateFormatter.string(from: date)
    }

    static func dateOnly(from value: String) -> Date? {
        let normalized = String(value.prefix(10))
        guard normalized.count == 10 else { return nil }
        guard let date = apiDateFormatter.date(from: normalized) else { return nil }
        return normalizedDateOnly(date)
    }

    static func flexibleDate(from value: String) -> Date? {
        dateOnly(from: value) ?? isoFormatter.date(from: value)
    }

    static func normalizedDateOnly(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return Calendar.current.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 12
        )) ?? date
    }

    static func repairedCachedDateOnly(_ date: Date) -> Date {
        guard let utcDate = utcDateIfLegacyMidnight(date) else {
            return normalizedDateOnly(date)
        }
        return localNoon(year: utcDate.year, month: utcDate.month, day: utcDate.day) ?? normalizedDateOnly(date)
    }

    private static let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoFormatter = ISO8601DateFormatter()

    private static func utcDateIfLegacyMidnight(_ date: Date) -> DateComponents? {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let utc = utcCalendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let local = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard utc.hour == 0, utc.minute == 0, utc.second == 0 else { return nil }
        guard utc.year != local.year || utc.month != local.month || utc.day != local.day else { return nil }
        return utc
    }

    private static func localNoon(year: Int?, month: Int?, day: Int?) -> Date? {
        guard let year, let month, let day else { return nil }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
}
