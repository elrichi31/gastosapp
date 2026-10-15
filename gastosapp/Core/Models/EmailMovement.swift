import Foundation

struct EmailMovement: Decodable, Identifiable {
    let id: Int
    let tipo: String
    let origen: String
    let fecha: String
    var descripcion: String
    let monto: Double
    let categoria_id: Int?
    let metodo_pago_id: Int?
    let destinatario: String?
    var alias: String?
    var descripcion_original: String? = nil
    let coincidencias: [EmailCandidate]
    var canHaveAlias: Bool {
        tipo == "gasto" && destinatario?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func updatingAlias(_ value: String) -> EmailMovement {
        var updated = self
        if updated.descripcion_original == nil && (alias ?? "").isEmpty {
            updated.descripcion_original = descripcion
        }
        updated.alias = value
        updated.descripcion = value.isEmpty ? updated.descripcion_original ?? descripcion : value
        return updated
    }
}
