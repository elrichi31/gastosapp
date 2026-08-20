import Foundation

enum MoneyInput {
    static func parse(_ rawValue: String) -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let sanitized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: "$", with: "")

        let normalized: String
        if sanitized.contains(",") && sanitized.contains(".") {
            let commaIndex = sanitized.lastIndex(of: ",")
            let dotIndex = sanitized.lastIndex(of: ".")
            if let commaIndex, let dotIndex, commaIndex > dotIndex {
                normalized = sanitized
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = sanitized.replacingOccurrences(of: ",", with: "")
            }
        } else if sanitized.contains(",") {
            normalized = normalizeSingleSeparator(sanitized, separator: ",", groupingSeparator: ".")
        } else {
            normalized = normalizeSingleSeparator(sanitized, separator: ".", groupingSeparator: ",")
        }

        return Double(normalized)
    }

    private static func normalizeSingleSeparator(_ value: String, separator: Character, groupingSeparator: Character) -> String {
        guard let separatorIndex = value.lastIndex(of: separator) else {
            return value.replacingOccurrences(of: String(groupingSeparator), with: "")
        }

        let fractionDigits = value.distance(from: value.index(after: separatorIndex), to: value.endIndex)
        if fractionDigits == 1 || fractionDigits == 2 {
            return value
                .replacingOccurrences(of: String(groupingSeparator), with: "")
                .replacingOccurrences(of: String(separator), with: ".")
        }

        return value
            .replacingOccurrences(of: String(separator), with: "")
            .replacingOccurrences(of: String(groupingSeparator), with: "")
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US_POSIX")))
    }
}
