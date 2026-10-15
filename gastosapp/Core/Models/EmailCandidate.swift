import Foundation

struct EmailCandidate: Decodable, Identifiable {
    struct ExistingExpense: Decodable {
        let id: Int
        let descripcion: String
        let monto: Double
        let fecha: String
    }
    let gasto: ExistingExpense
    let kind: String
    let dias: Int
    let veredicto: String?
    let probabilidad: Double?
    var id: Int { gasto.id }
}
