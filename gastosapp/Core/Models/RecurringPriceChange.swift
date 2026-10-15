import Foundation

struct RecurringPriceChange: Decodable, Identifiable {
    let gasto_recurrente_id: Int
    let monto_anterior: Double
    let monto_nuevo: Double
    let cambiado_en: String
    var id: String { "\(gasto_recurrente_id)-\(cambiado_en)" }
}
