import Foundation

/// Lo que el usuario va ajustando en la tarjeta de un movimiento nuevo antes de
/// registrarlo. Vive en la bandeja (no en la tarjeta) para que «Registrar
/// todos» use lo que se eligió en cada una.
struct EmailDraft: Equatable {
    var name: String
    var categoryID: Int
    var paymentID: Int?
    var half = false
    var foreign = false
    var taxes = ["isd"]
    var customRate = ""

    init(row: EmailMovement, categories: [Categoria]) {
        name = row.descripcion
        categoryID = row.categoria_id ?? categories.first?.id ?? 0
        paymentID = row.metodo_pago_id
    }

    func base(for row: EmailMovement) -> Double {
        half ? ForeignTax.cents(row.monto / 2) : row.monto
    }

    func tax(for row: EmailMovement) -> ForeignTax {
        ForeignTax(base: base(for: row), selected: taxes, customRate: customRate)
    }

    func total(for row: EmailMovement) -> Double {
        foreign ? tax(for: row).total : base(for: row)
    }

    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Falta elegir cómo se pagó: la tarjeta lo marca en ámbar.
    var needsPayment: Bool { paymentID == nil }

    func isReady(for row: EmailMovement) -> Bool {
        !needsPayment && !cleanName.isEmpty && cleanName.count <= 200 && categoryID != 0 &&
        (!foreign || tax(for: row).isValid)
    }

    func payload(for row: EmailMovement) -> [String: Any] {
        var item: [String: Any] = ["id": row.id, "categoria_id": categoryID, "monto": base(for: row), "descripcion": cleanName]
        if let paymentID { item["metodo_pago_id"] = paymentID }
        if foreign { item["impuestos"] = ["selected": taxes, "customRate": customRate] }
        return item
    }

    /// Lo que cambia el monto respecto al del correo, bajo el importe.
    var extraText: String? {
        let parts = [half ? "Tu mitad" : nil, foreign ? "+" + taxes.map(Self.shortTax).joined(separator: " +") : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func shortTax(_ id: String) -> String {
        switch id {
        case "isd": "ISD"
        case "iva_digital": "IVA"
        default: "Otro"
        }
    }
}
