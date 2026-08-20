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

struct Subscription: Identifiable, Hashable {
    let id: UUID
    var provider: Provider
    var monto: Double
    var ciclo: CicloFacturacion
    var proximaFecha: Date
    var metodoPago: MetodoPago

    init(
        id: UUID = UUID(),
        provider: Provider,
        monto: Double,
        ciclo: CicloFacturacion,
        proximaFecha: Date,
        metodoPago: MetodoPago
    ) {
        self.id = id
        self.provider = provider
        self.monto = monto
        self.ciclo = ciclo
        self.proximaFecha = proximaFecha
        self.metodoPago = metodoPago
    }

    var costoMensualEquivalente: Double {
        monto * ciclo.factorMensual
    }
}
