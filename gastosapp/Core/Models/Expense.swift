import Foundation
import Synchronization

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

    var shortLabel: String { style.shortLabel }

    var icono: String { style.icon }

    private struct Style: Sendable {
        let shortLabel: String
        let icon: String
    }

    /// Resolver el rótulo normaliza el nombre, y las listas, la búsqueda y
    /// Análisis lo piden por cada gasto: se guarda por nombre, que sólo hay
    /// unas pocas formas de pago.
    private static let styleCache = Mutex<[String: Style]>([:])

    private var style: Style {
        if let cached = Self.styleCache.withLock({ $0[nombre] }) { return cached }
        let resolved = Self.resolveStyle(nombre)
        Self.styleCache.withLock { $0[nombre] = resolved }
        return resolved
    }

    private static func resolveStyle(_ nombre: String) -> Style {
        let key = nombre.normalizedLookupKey
        let isDigital = key.contains("wallet") || key.contains("digital") || key.contains("paypal") || key.contains("apple pay")

        let shortLabel: String
        if key.contains("credito") {
            shortLabel = "Crédito"
        } else if key.contains("debito") {
            shortLabel = "Débito"
        } else if key.contains("transfer") {
            shortLabel = "Transfer."
        } else if key.contains("efectivo") {
            shortLabel = "Efectivo"
        } else if isDigital {
            shortLabel = "Digital"
        } else {
            shortLabel = nombre
        }

        let icon: String
        if key.contains("efectivo") {
            icon = "banknote.fill"
        } else if key.contains("credito") {
            icon = "creditcard.and.123"
        } else if key.contains("debito") {
            icon = "creditcard.fill"
        } else if key.contains("transfer") {
            icon = "arrow.left.arrow.right"
        } else if isDigital {
            icon = "iphone.gen3"
        } else {
            icon = "creditcard.fill"
        }

        return Style(shortLabel: shortLabel, icon: icon)
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
    var tags: [String]?
    var foreignTax: ForeignTax?

    init(
        id: Int = Int.random(in: 900_000...999_999),
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoriaId: Int? = nil,
        metodoPagoId: Int? = nil,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        isRecurrent: Bool = false,
        tags: [String]? = nil,
        foreignTax: ForeignTax? = nil
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
        self.tags = tags
        self.foreignTax = foreignTax
    }
}
