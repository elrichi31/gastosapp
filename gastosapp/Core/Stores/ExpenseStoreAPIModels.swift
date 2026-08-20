import Foundation

struct MobileLoginResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let expiresAt: Int
    let tokenType: String
    let user: AuthenticatedUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case user
    }
}

struct MobileRefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let expiresAt: Int?
    let tokenType: String?
    let user: AuthenticatedUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case tokenType = "token_type"
        case user
    }
}

struct ExpenseSuggestionKey: Hashable {
    let categoryID: Int
    let paymentMethodID: Int
}

struct MobileLoginRequest: Encodable {
    let email: String
    let password: String
}

struct RemoteExpense: Decodable {
    let id: Int
    let descripcion: String
    let monto: Double
    let fecha: String
    let categoriaId: Int
    let metodoPagoId: Int
    let isRecurrent: Bool?
    let categoria: Categoria?
    let metodoPago: ExpensePaymentMethod?

    enum CodingKeys: String, CodingKey {
        case id
        case descripcion
        case monto
        case fecha
        case categoriaId = "categoria_id"
        case metodoPagoId = "metodo_pago_id"
        case isRecurrent = "is_recurrent"
        case categoria
        case metodoPago = "metodo_pago"
    }

    @MainActor
    func asExpense(categorias: [Categoria], metodosPago: [ExpensePaymentMethod]) -> Expense {
        let resolvedCategoria = categoria
            ?? categorias.first(where: { $0.id == categoriaId })
            ?? Categoria(id: categoriaId, nombre: "Otros")
        let resolvedMetodo = metodoPago
            ?? metodosPago.first(where: { $0.id == metodoPagoId })
            ?? ExpensePaymentMethod(id: metodoPagoId, nombre: "Efectivo")

        let parsedDate = AppDateCodec.flexibleDate(from: fecha) ?? Date()

        return Expense(
            id: id,
            descripcion: descripcion,
            monto: monto,
            fecha: parsedDate,
            categoriaId: categoriaId,
            metodoPagoId: metodoPagoId,
            categoria: resolvedCategoria,
            metodoPago: resolvedMetodo,
            isRecurrent: isRecurrent ?? false
        )
    }
}

struct CreateExpensePayload: Encodable {
    let descripcion: String
    let monto: Double
    let fecha: String
    let categoriaId: Int
    let metodoPagoId: Int
    let isRecurrent: Bool

    enum CodingKeys: String, CodingKey {
        case descripcion
        case monto
        case fecha
        case categoriaId = "categoria_id"
        case metodoPagoId = "metodo_pago_id"
        case isRecurrent = "is_recurrent"
    }
}

struct UpdateExpensePayload: Encodable {
    let descripcion: String
    let monto: Double
    let fecha: String
    let categoriaId: Int
    let metodoPagoId: Int
    let isRecurrent: Bool

    enum CodingKeys: String, CodingKey {
        case descripcion
        case monto
        case fecha
        case categoriaId = "categoria_id"
        case metodoPagoId = "metodo_pago_id"
        case isRecurrent = "is_recurrent"
    }
}

struct RemoteRecurringExpense: Decodable {
    let id: Int
    let descripcion: String
    let monto: Double
    let categoriaId: Int
    let metodoPagoId: Int
    let frecuencia: RecurringFrequency
    let diaSemana: Int?
    let diaMes: Int?
    let fechaInicio: String
    let fechaFin: String?
    let activo: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case descripcion
        case monto
        case categoriaId = "categoria_id"
        case metodoPagoId = "metodo_pago_id"
        case frecuencia
        case diaSemana = "dia_semana"
        case diaMes = "dia_mes"
        case fechaInicio = "fecha_inicio"
        case fechaFin = "fecha_fin"
        case activo
    }

    @MainActor
    func asRecurringExpense(categorias: [Categoria], metodosPago: [ExpensePaymentMethod]) -> RecurringExpense {
        let resolvedCategoria = categorias.first(where: { $0.id == categoriaId }) ?? Categoria(id: categoriaId, nombre: "Otros")
        let resolvedMetodo = metodosPago.first(where: { $0.id == metodoPagoId }) ?? ExpensePaymentMethod(id: metodoPagoId, nombre: "Efectivo")
        let parsedStart = AppDateCodec.flexibleDate(from: fechaInicio) ?? Date()
        let parsedEnd = fechaFin.flatMap { value in
            AppDateCodec.flexibleDate(from: value)
        }

        return RecurringExpense(
            id: id,
            descripcion: descripcion,
            monto: monto,
            frecuencia: frecuencia,
            diaMes: diaMes,
            diaSemana: diaSemana,
            fechaInicio: parsedStart,
            fechaFin: parsedEnd,
            activo: activo,
            categoriaId: categoriaId,
            metodoPagoId: metodoPagoId,
            categoria: resolvedCategoria,
            metodoPago: resolvedMetodo
        )
    }
}

struct CreateRecurringExpensePayload: Encodable {
    let descripcion: String
    let monto: Double
    let categoriaId: Int
    let metodoPagoId: Int
    let frecuencia: String
    let diaSemana: Int?
    let diaMes: Int?
    let fechaInicio: String
    let fechaFin: String?
    let activo: Bool

    enum CodingKeys: String, CodingKey {
        case descripcion
        case monto
        case categoriaId = "categoria_id"
        case metodoPagoId = "metodo_pago_id"
        case frecuencia
        case diaSemana = "dia_semana"
        case diaMes = "dia_mes"
        case fechaInicio = "fecha_inicio"
        case fechaFin = "fecha_fin"
        case activo
    }
}

struct CreateExpenseResponse: Decodable {
    let mensaje: String?
    let data: RemoteExpense?
}

struct ErrorResponse: Decodable {
    let error: String
}

enum ExpenseStoreError: LocalizedError {
    case missingBaseURL
    case invalidBaseURL
    case missingAccessToken
    case invalidResponse
    case decoding(Error)
    case unauthorized(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Falta la URL base del backend."
        case .invalidBaseURL:
            return "La URL del backend no es valida."
        case .missingAccessToken:
            return "Falta el token de acceso."
        case .invalidResponse:
            return "No se pudo interpretar la respuesta del backend."
        case let .decoding(error):
            return "No se pudo leer la respuesta JSON: \(error.localizedDescription)"
        case let .unauthorized(message):
            return message
        case let .server(message):
            return message
        }
    }
}
