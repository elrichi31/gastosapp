import SwiftUI

enum MetodoPago: String, CaseIterable, Identifiable {
    case efectivo = "Efectivo"
    case debito = "Débito"
    case credito = "Crédito"
    case transferencia = "Transferencia"

    var id: String { rawValue }

    var icono: String {
        switch self {
        case .efectivo: return "banknote.fill"
        case .debito: return "creditcard.fill"
        case .credito: return "creditcard.and.123"
        case .transferencia: return "arrow.left.arrow.right"
        }
    }
}
