import SwiftUI

enum EmailReviewTab: String, CaseIterable, Identifiable {
    case nuevos, duplicados, recibidos
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nuevos: "Nuevos"
        case .duplicados: "Duplicados"
        case .recibidos: "Recibidos"
        }
    }
    var emptyTitle: String {
        switch self {
        case .nuevos: "Todo al día"
        case .duplicados: "Sin duplicados"
        case .recibidos: "Sin devoluciones"
        }
    }
    var emptyMessage: String {
        switch self {
        case .nuevos: "Te avisaremos cuando llegue un movimiento nuevo."
        case .duplicados: "Aquí verás movimientos que ya registraste."
        case .recibidos: "Aquí verás reembolsos y transferencias recibidas."
        }
    }
}
