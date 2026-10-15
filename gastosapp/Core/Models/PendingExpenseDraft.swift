import Foundation

struct PendingExpenseDraft: Codable, Identifiable {
    let id: String
    let localExpenseID: Int
    let descripcion: String
    let monto: Double
    let fecha: Date
    let categoriaId: Int
    let metodoPagoId: Int
    var tags: [String]? = nil
    var foreignTax: ForeignTax? = nil
    let isRecurrent: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case localExpenseID
        case descripcion
        case monto
        case fecha
        case categoriaId
        case metodoPagoId
        case tags, foreignTax
        case isRecurrent
    }

    init(
        id: String,
        localExpenseID: Int,
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoriaId: Int,
        metodoPagoId: Int,
        isRecurrent: Bool = false,
        tags: [String]? = nil,
        foreignTax: ForeignTax? = nil
    ) {
        self.id = id
        self.localExpenseID = localExpenseID
        self.descripcion = descripcion
        self.monto = monto
        self.fecha = fecha
        self.categoriaId = categoriaId
        self.metodoPagoId = metodoPagoId
        self.isRecurrent = isRecurrent
        self.tags = tags
        self.foreignTax = foreignTax
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        localExpenseID = try container.decode(Int.self, forKey: .localExpenseID)
        descripcion = try container.decode(String.self, forKey: .descripcion)
        monto = try container.decode(Double.self, forKey: .monto)
        fecha = try container.decode(Date.self, forKey: .fecha)
        categoriaId = try container.decode(Int.self, forKey: .categoriaId)
        metodoPagoId = try container.decode(Int.self, forKey: .metodoPagoId)
        tags = try container.decodeIfPresent([String].self, forKey: .tags)
        foreignTax = try container.decodeIfPresent(ForeignTax.self, forKey: .foreignTax)
        isRecurrent = try container.decodeIfPresent(Bool.self, forKey: .isRecurrent) ?? false
    }

    var payload: CreateExpensePayload {
        CreateExpensePayload(
            descripcion: descripcion,
            monto: monto,
            fecha: AppDateCodec.apiDateString(from: AppDateCodec.repairedCachedDateOnly(fecha)),
            categoriaId: categoriaId,
            metodoPagoId: metodoPagoId,
            isRecurrent: isRecurrent,
            tags: tags,
            foreignTax: foreignTax
        )
    }

    func asExpense(categorias: [Categoria], metodosPago: [ExpensePaymentMethod]) -> Expense {
        Expense(
            id: localExpenseID,
            descripcion: descripcion,
            monto: monto,
            fecha: AppDateCodec.repairedCachedDateOnly(fecha),
            categoriaId: categoriaId,
            metodoPagoId: metodoPagoId,
            categoria: categorias.first(where: { $0.id == categoriaId }) ?? Categoria(id: categoriaId, nombre: "Otros"),
            metodoPago: metodosPago.first(where: { $0.id == metodoPagoId }) ?? ExpensePaymentMethod(id: metodoPagoId, nombre: "Efectivo"),
            isRecurrent: isRecurrent,
            tags: tags,
            foreignTax: foreignTax
        )
    }

    func updated(
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoriaId: Int,
        metodoPagoId: Int,
        tags: [String]?,
        foreignTax: ForeignTax?
    ) -> PendingExpenseDraft {
        PendingExpenseDraft(
            id: id,
            localExpenseID: localExpenseID,
            descripcion: descripcion,
            monto: monto,
            fecha: fecha,
            categoriaId: categoriaId,
            metodoPagoId: metodoPagoId,
            isRecurrent: isRecurrent,
            tags: tags,
            foreignTax: foreignTax
        )
    }
}

