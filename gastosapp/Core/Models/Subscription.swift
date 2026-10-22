import Foundation

enum CicloFacturacion: String, CaseIterable, Identifiable, Hashable {
    case semanal = "Semanal"
    case mensual = "Mensual"
    case trimestral = "Trimestral"
    case anual = "Anual"

    var id: String { rawValue }

    /// Cuánto representa un cobro de este ciclo en términos mensuales.
    var factorMensual: Double {
        switch self {
        case .semanal: return 4.345
        case .mensual: return 1
        case .trimestral: return 1.0 / 3.0
        case .anual: return 1.0 / 12.0
        }
    }
}
