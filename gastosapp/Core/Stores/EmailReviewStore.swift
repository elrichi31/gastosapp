import Foundation
import Observation

@MainActor @Observable
final class EmailReviewStore {
    var result: EmailReviewPage?
    var counts: [String: Int] = [:]
    var isEnabled: Bool?
    var isLoading = false
    var isWorking = false
    var isSyncing = false
    var isSavingAlias = false
    /// Fallo de una acción (vincular, guardar, alias). Se muestra en la revisión.
    var error: String?
    /// Fallo al leer la bandeja. Sustituye a la lista.
    var loadError: String?
    var message: String?
    var tab = "nuevos"
    var query = ""
    var page = 1
    var otherIDs: Set<Int> = []
    private var requestID = UUID()

    /// `keepsRows` deja la lista visible mientras se recarga tras una acción,
    /// en lugar de volver al esqueleto.
    func load(using session: ExpenseStore, keepsRows: Bool = false) async {
        let id = UUID(); requestID = id
        isLoading = true; loadError = nil
        // Clear rows so a tab switch cannot act on the previous tab's data.
        if !keepsRows { result = nil }
        defer { if requestID == id { isLoading = false } }
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "tab", value: tab), URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "q", value: query), URLQueryItem(name: "otros", value: otherIDs.sorted().map(String.init).joined(separator: ","))]
        do {
            let data = try await session.request(EmailReviewPage.self, path: "/api/email-import/yahoo?" + (components.percentEncodedQuery ?? ""), requiresAuth: true)
            guard requestID == id else { return }
            result = data
            counts = data.counts ?? [:]
            isEnabled = data.enabled
            page = data.page ?? 1
        } catch {
            if requestID == id && !isCancellationError(error) { loadError = error.localizedDescription }
        }
    }
    func sync(using session: ExpenseStore) async {
        guard !isWorking else { return }
        isWorking = true; isSyncing = true; loadError = nil; message = nil
        defer { isWorking = false; isSyncing = false }
        do {
            struct Result: Decodable { let nuevos: Int }
            let value = try await session.request(Result.self, path: "/api/email-import/yahoo", method: "POST", requiresAuth: true)
            message = "\(value.nuevos) movimientos nuevos encontrados"
            await load(using: session, keepsRows: true)
        } catch { if !isCancellationError(error) { loadError = error.localizedDescription } }
    }
    func saveAlias(for row: EmailMovement, alias: String, using session: ExpenseStore) async -> Bool {
        let cleanAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isWorking, row.canHaveAlias, cleanAlias.utf16.count <= 200 else { return false }
        isWorking = true; isSavingAlias = true; error = nil; message = nil
        defer { isWorking = false; isSavingAlias = false }
        do {
            struct Payload: Encodable { let id: Int; let alias: String }
            let body = try JSONEncoder().encode(Payload(id: row.id, alias: cleanAlias))
            let saved = try await session.request(EmailAliasResult.self,
                path: "/api/email-import/yahoo", method: "PUT", requiresAuth: true, body: body)
            guard saved.destinatario == row.destinatario else { throw ExpenseStoreError.invalidResponse }
            result = result?.applyingAlias(saved)
            message = saved.alias.isEmpty ? "Alias eliminado" : "Alias guardado para próximas transferencias"
            return true
        } catch {
            if !isCancellationError(error) { self.error = error.localizedDescription }
            return false
        }
    }

    func apply(_ payload: [String: Any], using session: ExpenseStore, method: String = "PATCH") async -> Bool {
        guard !isWorking else { return false }
        isWorking = true; error = nil
        defer { isWorking = false }
        do {
            struct Result: Decodable {}
            let previousExpenses = session.gastos
            let body = try JSONSerialization.data(withJSONObject: payload)
            _ = try await session.request(Result.self, path: "/api/email-import/yahoo", method: method, requiresAuth: true, body: body)
            message = method == "PUT" ? "Alias guardado" : "Movimiento revisado"
            await session.loadExpenses(force: true)
            if let alert = await session.budgetCrossingMessage(before: previousExpenses) { message = alert }
            await load(using: session, keepsRows: true)
            return true
        } catch { if !isCancellationError(error) { self.error = error.localizedDescription }; return false }
    }
}
