import Foundation

/// Same stored contract and cent rounding as the web backend.
struct ForeignTax: Codable, Hashable {
    var base: Double
    var selected: [String]
    var customRate: String

    var isValid: Bool {
        base.isFinite && base > 0 && base <= 999_999_999 && !selected.isEmpty &&
        selected.allSatisfy { ["isd", "iva_digital", "custom"].contains($0) } &&
        (!selected.contains("custom") || (customPercentage.map { $0 > 0 && $0 <= 100 } ?? false))
    }

    var customPercentage: Double? {
        guard let value = Double(customRate.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")), value.isFinite else { return nil }
        return Self.cents(value)
    }
    static func cents(_ value: Double) -> Double { (value * 100).rounded() / 100 }
    var taxAmount: Double {
        let rates = [("isd", 5.0), ("iva_digital", 15.0), ("custom", customPercentage ?? 0)]
        return Self.cents(rates.filter { selected.contains($0.0) }.reduce(0) { $0 + Self.cents(base * $1.1 / 100) })
    }
    var total: Double { Self.cents(Self.cents(base) + taxAmount) }
}
