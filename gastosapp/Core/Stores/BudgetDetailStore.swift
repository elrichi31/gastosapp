import Foundation
import Observation

@MainActor
@Observable
final class BudgetDetailStore {
    var categories: [BudgetCategoryDetail] = []
    var isLoading = false
    var isSaving = false
    var isCopyingPreviousBudget = false
    var deletingMovementIDs: Set<Int> = []
    var deletingCategoryIDs: Set<Int> = []
    var errorMessage: String?
    var saveErrorMessage: String?
    private var loadedBudgetID: Int?
    private var activeLoadRequestID: UUID?

    func loadDetail(using session: ExpenseStore, budgetID: Int) async {
        let requestID = UUID()
        activeLoadRequestID = requestID
        isLoading = true
        defer {
            if activeLoadRequestID == requestID {
                isLoading = false
            }
        }

        if loadedBudgetID != budgetID || categories.isEmpty {
            loadedBudgetID = budgetID
            categories = Self.loadCachedDetail(budgetID: budgetID)
        }
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            guard activeLoadRequestID == requestID else { return }
            errorMessage = categories.isEmpty ? "Inicia sesión para ver el detalle del presupuesto." : nil
            return
        }

        do {
            let detail = try await fetchDetail(using: session, budgetID: budgetID, authHeader: authHeader)
            guard activeLoadRequestID == requestID else { return }
            categories = detail
            persistCachedDetail(budgetID: budgetID)
            errorMessage = nil
        } catch {
            guard !isCancellationError(error) else { return }
            guard activeLoadRequestID == requestID else { return }
            if isConnectivityError(error), !categories.isEmpty {
                errorMessage = nil
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func createMovement(using session: ExpenseStore, budgetID: Int, categoryID: Int, description: String, amount: Double, date: Date, paymentMethodID: Int, tags: [String]? = nil) async -> Bool {
        let payload = BudgetMovementPayload(categoryID: categoryID, movementID: nil, description: description, amount: amount, date: date, paymentMethodID: paymentMethodID, tags: tags)
        return await persistMovement(path: "/api/movimientos-categoria", method: "POST", budgetID: budgetID, payload: payload, session: session)
    }

    func updateMovement(using session: ExpenseStore, budgetID: Int, movementID: Int, description: String, amount: Double, date: Date, paymentMethodID: Int, tags: [String]? = nil) async -> Bool {
        let payload = BudgetMovementPayload(categoryID: nil, movementID: movementID, description: description, amount: amount, date: date, paymentMethodID: paymentMethodID, tags: tags)
        return await persistMovement(path: "/api/movimientos-categoria", method: "PUT", budgetID: budgetID, payload: payload, session: session)
    }

    func createCategory(using session: ExpenseStore, budgetID: Int, categoryID: Int) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            saveErrorMessage = "Inicia sesión para agregar categorías."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let payload = BudgetCategoryPayload(budgetID: budgetID, categoryID: categoryID)
            let body = try JSONEncoder().encode(payload)
            _ = try await rawRequest(path: "/api/presupuesto-categoria", method: "POST", body: body, session: session, authHeader: authHeader)
            try await refreshDetailAndMonthlyTotal(using: session, budgetID: budgetID, authHeader: authHeader)
            saveErrorMessage = nil
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteCategory(using session: ExpenseStore, budgetID: Int, budgetCategoryID: Int) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            errorMessage = "Inicia sesión para eliminar categorías."
            return false
        }
        guard !deletingCategoryIDs.contains(budgetCategoryID) else { return false }

        deletingCategoryIDs.insert(budgetCategoryID)
        defer { deletingCategoryIDs.remove(budgetCategoryID) }

        do {
            _ = try await rawRequest(path: "/api/presupuesto-categoria?id=\(budgetCategoryID)", method: "DELETE", body: nil, session: session, authHeader: authHeader)
            try await refreshDetailAndMonthlyTotal(using: session, budgetID: budgetID, authHeader: authHeader)
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func copyPreviousBudget(using session: ExpenseStore, budgetID: Int) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            saveErrorMessage = "Inicia sesión para copiar el mes anterior."
            return false
        }
        guard !isCopyingPreviousBudget else { return false }

        isCopyingPreviousBudget = true
        defer { isCopyingPreviousBudget = false }

        do {
            let body = try JSONEncoder().encode(CopyPreviousBudgetPayload(budgetID: budgetID))
            _ = try await rawRequest(path: "/api/presupuestos/copy-previous", method: "POST", body: body, session: session, authHeader: authHeader)
            try await refreshDetailAndMonthlyTotal(using: session, budgetID: budgetID, authHeader: authHeader)
            saveErrorMessage = nil
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteMovement(using session: ExpenseStore, budgetID: Int, movementID: Int) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            errorMessage = "Inicia sesión para eliminar movimientos."
            return false
        }
        guard !deletingMovementIDs.contains(movementID) else { return false }

        deletingMovementIDs.insert(movementID)
        defer { deletingMovementIDs.remove(movementID) }

        do {
            let body = try JSONEncoder().encode(DeleteBudgetMovementPayload(id: movementID))
            _ = try await rawRequest(path: "/api/movimientos-categoria", method: "DELETE", body: body, session: session, authHeader: authHeader)
            try await refreshDetailAndMonthlyTotal(using: session, budgetID: budgetID, authHeader: authHeader)
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func persistMovement(path: String, method: String, budgetID: Int, payload: BudgetMovementPayload, session: ExpenseStore) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            saveErrorMessage = "Inicia sesión para guardar movimientos."
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let body = try JSONEncoder().encode(payload)
            _ = try await rawRequest(path: path, method: method, body: body, session: session, authHeader: authHeader)
            try await refreshDetailAndMonthlyTotal(using: session, budgetID: budgetID, authHeader: authHeader)
            saveErrorMessage = nil
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    private func refreshDetailAndMonthlyTotal(using session: ExpenseStore, budgetID: Int, authHeader: String) async throws {
        loadedBudgetID = budgetID
        let refreshedCategories = try await fetchDetail(using: session, budgetID: budgetID, authHeader: authHeader)
        categories = refreshedCategories
        persistCachedDetail(budgetID: budgetID)
        try await updateMonthlyTotal(using: session, budgetID: budgetID, categories: refreshedCategories, authHeader: authHeader)
    }

    private func fetchDetail(using session: ExpenseStore, budgetID: Int, authHeader: String) async throws -> [BudgetCategoryDetail] {
        let path = "/api/presupuesto-mensual-detalle?presupuesto_mensual_id=\(budgetID)"
        let detail: [BudgetCategoryDetail] = try await request([BudgetCategoryDetail].self, path: path, session: session, authHeader: authHeader)
        return detail.sorted { $0.displayCategory.nombre < $1.displayCategory.nombre }
    }

    private func updateMonthlyTotal(using session: ExpenseStore, budgetID: Int, categories: [BudgetCategoryDetail], authHeader: String) async throws {
        let payload = UpdateBudgetTotalPayload(
            presupuestoMensualId: budgetID,
            total: categories.reduce(0) { $0 + $1.budgetedAmount },
            gastosRegistrados: categories.reduce(0) { $0 + $1.movimientos.count }
        )
        let body = try JSONEncoder().encode(payload)
        _ = try await rawRequest(path: "/api/presupuestos", method: "PUT", body: body, session: session, authHeader: authHeader)
    }

    private func request<T: Decodable>(_ type: T.Type, path: String, session: ExpenseStore, authHeader: String) async throws -> T {
        let (data, _) = try await rawRequest(path: path, method: "GET", body: nil, session: session, authHeader: authHeader)
        return try JSONDecoder().decode(type, from: data)
    }

    private func rawRequest(path: String, method: String, body: Data?, session: ExpenseStore, authHeader: String) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: session.apiBaseURL + path) else { throw BudgetDetailError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BudgetDetailError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw mapError(data: data, statusCode: http.statusCode) }
        return (data, http)
    }

    private func mapError(data: Data, statusCode: Int) -> Error {
        if let payload = try? JSONDecoder().decode(BudgetDetailErrorResponse.self, from: data) {
            return BudgetDetailError.server(payload.error)
        }
        return BudgetDetailError.server("El backend respondió con status \(statusCode).")
    }

    private func persistCachedDetail(budgetID: Int) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedDetailKey(budgetID: budgetID))
    }

    private static func loadCachedDetail(budgetID: Int) -> [BudgetCategoryDetail] {
        guard
            let data = UserDefaults.standard.data(forKey: cachedDetailKey(budgetID: budgetID)),
            let cached = try? JSONDecoder().decode([BudgetCategoryDetail].self, from: data)
        else {
            return []
        }
        return cached.sorted { $0.displayCategory.nombre < $1.displayCategory.nombre }
    }

    private static func cachedDetailKey(budgetID: Int) -> String {
        "budget.cache.detail.\(budgetID)"
    }
}

private struct BudgetMovementPayload: Encodable {
    let presupuestoCategoriaId: Int?
    let id: Int?
    let descripcion: String
    let monto: Double
    let fecha: String
    let metodoPagoId: Int
    let tags: [String]?

    init(categoryID: Int?, movementID: Int?, description: String, amount: Double, date: Date, paymentMethodID: Int, tags: [String]?) {
        presupuestoCategoriaId = categoryID
        id = movementID
        descripcion = description
        monto = amount
        fecha = AppDateCodec.apiDateString(from: date)
        metodoPagoId = paymentMethodID
        self.tags = tags
    }

    enum CodingKeys: String, CodingKey {
        case presupuestoCategoriaId = "presupuesto_categoria_id"
        case id
        case descripcion
        case monto
        case fecha
        case tags
        case metodoPagoId = "metodo_pago_id"
    }

}

private struct DeleteBudgetMovementPayload: Encodable {
    let id: Int
}

private struct BudgetCategoryPayload: Encodable {
    let budgetID: Int
    let categoryID: Int

    enum CodingKeys: String, CodingKey {
        case budgetID = "presupuesto_mensual_id"
        case categoryID = "categoria_id"
    }
}

private struct CopyPreviousBudgetPayload: Encodable {
    let budgetID: Int

    enum CodingKeys: String, CodingKey {
        case budgetID = "presupuesto_mensual_id"
    }
}

private struct UpdateBudgetTotalPayload: Encodable {
    let presupuestoMensualId: Int
    let total: Double
    let gastosRegistrados: Int

    enum CodingKeys: String, CodingKey {
        case presupuestoMensualId = "presupuesto_mensual_id"
        case total
        case gastosRegistrados = "gastos_registrados"
    }
}

private struct BudgetDetailErrorResponse: Decodable {
    let error: String
}

private enum BudgetDetailError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "La URL del backend no es válida."
        case .invalidResponse: return "No se pudo interpretar la respuesta del backend."
        case let .server(message): return message
        }
    }
}
