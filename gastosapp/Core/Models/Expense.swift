import Foundation

extension String {
    var normalizedLookupKey: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    func ifEmpty(_ fallback: () -> String) -> String {
        isEmpty ? fallback() : self
    }
}

struct ExpensePaymentMethod: Identifiable, Hashable, Codable {
    let id: Int
    let nombre: String

    var shortLabel: String {
        let key = nombre.normalizedLookupKey
        if key.contains("credito") {
            return "Crédito"
        }
        if key.contains("debito") {
            return "Débito"
        }
        if key.contains("transfer") {
            return "Transfer."
        }
        if key.contains("efectivo") {
            return "Efectivo"
        }
        if key.contains("wallet") || key.contains("digital") || key.contains("paypal") || key.contains("apple pay") {
            return "Digital"
        }
        return nombre
    }

    var icono: String {
        let key = nombre.normalizedLookupKey
        if key.contains("efectivo") {
            return "banknote.fill"
        }
        if key.contains("credito") {
            return "creditcard.and.123"
        }
        if key.contains("debito") {
            return "creditcard.fill"
        }
        if key.contains("transfer") {
            return "arrow.left.arrow.right"
        }
        if key.contains("wallet") || key.contains("digital") || key.contains("paypal") || key.contains("apple pay") {
            return "iphone.gen3"
        }
        return "creditcard.fill"
    }

    static let fallback: [ExpensePaymentMethod] = [
        ExpensePaymentMethod(id: 1, nombre: "Efectivo"),
        ExpensePaymentMethod(id: 2, nombre: "Tarjeta"),
        ExpensePaymentMethod(id: 3, nombre: "Débito"),
        ExpensePaymentMethod(id: 4, nombre: "Transferencia")
    ]

    static var placeholder: ExpensePaymentMethod {
        fallback.first ?? ExpensePaymentMethod(id: 0, nombre: "Efectivo")
    }
}

struct Expense: Identifiable, Hashable, Codable {
    let id: Int
    var descripcion: String
    var monto: Double
    var fecha: Date
    var categoriaId: Int
    var metodoPagoId: Int
    var categoria: Categoria
    var metodoPago: ExpensePaymentMethod
    var isRecurrent: Bool

    init(
        id: Int = Int.random(in: 900_000...999_999),
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoriaId: Int? = nil,
        metodoPagoId: Int? = nil,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        isRecurrent: Bool = false
    ) {
        self.id = id
        self.descripcion = descripcion
        self.monto = monto
        self.fecha = AppDateCodec.normalizedDateOnly(fecha)
        self.categoriaId = categoriaId ?? categoria.id
        self.metodoPagoId = metodoPagoId ?? metodoPago.id
        self.categoria = categoria
        self.metodoPago = metodoPago
        self.isRecurrent = isRecurrent
    }
}
