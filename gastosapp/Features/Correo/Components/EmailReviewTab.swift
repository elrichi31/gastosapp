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
        case .duplicados: "Sin duplicados por revisar"
        case .recibidos: "Sin devoluciones pendientes"
        }
    }
    var help: String {
        switch self {
        case .nuevos: "Revisa los consumos antes de guardarlos en tus gastos."
        case .duplicados: "Comprueba si estos consumos ya están registrados."
        case .recibidos: "Vincula una devolución para descontarla del gasto original."
        }
    }
}
