import Foundation

enum RecurringFrequency: String, CaseIterable, Identifiable, Codable {
    case mensual
    case semanal
    case anual

    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch rawValue {
        case "mensual", "monthly":
            self = .mensual
        case "semanal", "weekly":
            self = .semanal
        case "anual", "yearly":
            self = .anual
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Frecuencia recurrente no soportada: \(rawValue)"
            )
        }
    }

    var title: String {
        switch self {
        case .mensual:
            return "Mensual"
        case .semanal:
            return "Semanal"
        case .anual:
            return "Anual"
        }
    }
}
