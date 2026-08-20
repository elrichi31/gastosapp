import Foundation
import Observation

@MainActor
@Observable
final class BudgetStore {
    var budgets: [BudgetMonthly] = []
    var selectedYear: Int = Calendar.current.component(.year, from: Date())
    var isLoadingBudgets = false
    var isSavingBudget = false
    var deletingBudgetIDs: Set<Int> = []
    var errorMessage: String?
    var saveErrorMessage: String?
    var saveStatusMessage: String?

    private var hasLoadedBudgetsOnce = false
    private static let cachedBudgetsKey = "budget.cache.monthlyBudgets"
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

    init() {
        budgets = Self.loadCachedBudgets()
    }

    func loadBudgets(using session: ExpenseStore, force: Bool = false) async {
        guard force || !hasLoadedBudgetsOnce else { return }
        guard !isLoadingBudgets else { return }
        guard session.hasBaseURLConfigured else {
            errorMessage = budgets.isEmpty ? "Configura la URL del backend para ver tus presupuestos." : nil
            return
        }
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            errorMessage = budgets.isEmpty ? "Inicia sesión para consultar tus presupuestos." : nil
            return
        }

        isLoadingBudgets = true
        defer { isLoadingBudgets = false }

        do {
            let path = "/api/presupuestos?anio=\(selectedYear)&include_expense_count=true"
            let remote: [BudgetMonthly] = try await request([BudgetMonthly].self, path: path, baseURL: session.apiBaseURL, authHeader: authHeader)
            budgets = remote.sorted { lhs, rhs in
                if lhs.anio != rhs.anio { return lhs.anio < rhs.anio }
                return lhs.mes < rhs.mes
            }
            persistCachedBudgets()
            errorMessage = nil
            hasLoadedBudgetsOnce = true
        } catch {
            guard !isCancellationError(error) else { return }
            if isConnectivityError(error), !budgets.isEmpty {
                errorMessage = nil
                hasLoadedBudgetsOnce = true
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func createBudget(using session: ExpenseStore, year: Int, month: Int) async -> Bool {
        guard session.hasBaseURLConfigured else {
            saveErrorMessage = "Configura la URL del backend antes de guardar."
            return false
        }
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            saveErrorMessage = "Inicia sesión para crear presupuestos."
            return false
        }
        guard !isPastMonth(year: year, month: month) else {
            saveErrorMessage = "No puedes crear presupuestos de meses pasados."
            return false
        }
        guard !budgets.contains(where: { $0.anio == year && $0.mes == month }) else {
            saveErrorMessage = "Ese mes ya tiene un presupuesto creado."
            return false
        }

        isSavingBudget = true
        defer { isSavingBudget = false }

        do {
            let payload = CreateBudgetPayload(
                anio: year,
                mes: month,
                total: 0,
                gastosRegistrados: 0,
                tendencia: nil,
                estado: budgetStateString(year: year, month: month)
            )
            let body = try JSONEncoder().encode(payload)
            let created: [BudgetMonthly] = try await request(
                [BudgetMonthly].self,
                path: "/api/presupuestos",
                method: "POST",
                body: body,
                baseURL: session.apiBaseURL,
                authHeader: authHeader
            )
            selectedYear = year
            budgets = merge(budgets: budgets, with: created)
            persistCachedBudgets()
            saveErrorMessage = nil
            errorMessage = nil
            hasLoadedBudgetsOnce = true
            showSaveStatus("Presupuesto creado")
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteBudget(using session: ExpenseStore, budget: BudgetMonthly) async -> Bool {
        guard let authHeader = await session.authorizationHeaderValueRefreshingIfNeeded() else {
            errorMessage = "Inicia sesión para eliminar presupuestos."
            return false
        }
        guard budget.gastosRegistrados == 0 else {
            errorMessage = "No puedes eliminar un presupuesto con gastos reales registrados."
            return false
        }
        guard !deletingBudgetIDs.contains(budget.id) else { return false }

        deletingBudgetIDs.insert(budget.id)
        defer { deletingBudgetIDs.remove(budget.id) }

        do {
            let path = "/api/presupuestos?anio=\(budget.anio)&mes=\(budget.mes)"
            _ = try await rawRequest(path: path, method: "DELETE", baseURL: session.apiBaseURL, authHeader: authHeader)
            budgets.removeAll { $0.id == budget.id }
            persistCachedBudgets()
            errorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func request<T: Decodable>(
        _ type: T.Type,
        path: String,
        method: String = "GET",
        body: Data? = nil,
        baseURL: String,
        authHeader: String
    ) async throws -> T {
        let (data, _) = try await rawRequest(path: path, method: method, body: body, baseURL: baseURL, authHeader: authHeader)
        return try JSONDecoder().decode(type, from: data)
    }

    private func rawRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        baseURL: String,
        authHeader: String
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: baseURL + path) else { throw BudgetStoreError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw BudgetStoreError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw mapError(data: data, statusCode: http.statusCode) }
        return (data, http)
    }

    private func mapError(data: Data, statusCode: Int) -> Error {
        if let payload = try? JSONDecoder().decode(BudgetErrorResponse.self, from: data) {
            return BudgetStoreError.server(payload.error)
        }
        return BudgetStoreError.server("El backend respondió con status \(statusCode).")
    }

    private func merge(budgets: [BudgetMonthly], with created: [BudgetMonthly]) -> [BudgetMonthly] {
        let merged = Dictionary(grouping: budgets + created, by: \.id).compactMap { $0.value.last }
        return merged.sorted { lhs, rhs in
            if lhs.anio != rhs.anio { return lhs.anio < rhs.anio }
            return lhs.mes < rhs.mes
        }
    }

    private func persistCachedBudgets() {
        guard let data = try? JSONEncoder().encode(budgets) else { return }
        UserDefaults.standard.set(data, forKey: Self.cachedBudgetsKey)
    }

    private func showSaveStatus(_ message: String) {
        saveStatusMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if saveStatusMessage == message {
                saveStatusMessage = nil
            }
        }
    }

    private static func loadCachedBudgets() -> [BudgetMonthly] {
        guard
            let data = UserDefaults.standard.data(forKey: cachedBudgetsKey),
            let cached = try? JSONDecoder().decode([BudgetMonthly].self, from: data)
        else {
            return []
        }
        return cached.sorted { lhs, rhs in
            if lhs.anio != rhs.anio { return lhs.anio < rhs.anio }
            return lhs.mes < rhs.mes
        }
    }

    func availableMonths(for year: Int) -> [(value: Int, label: String)] {
        let createdMonths = Set(budgets.filter { $0.anio == year }.map(\.mes))

        return (1...12).compactMap { month in
            guard !isPastMonth(year: year, month: month), !createdMonths.contains(month) else { return nil }
            guard Self.spanishMonthSymbols.indices.contains(month - 1) else { return nil }
            return (month, Self.spanishMonthSymbols[month - 1].capitalized)
        }
    }

    private func budgetStateString(year: Int, month: Int) -> String {
        isPastMonth(year: year, month: month) ? "Completado" : "En progreso"
    }

    private func isPastMonth(year: Int, month: Int, calendar: Calendar = .current) -> Bool {
        let now = calendar.dateComponents([.year, .month], from: Date())
        guard let currentYear = now.year, let currentMonth = now.month else { return false }
        if year < currentYear { return true }
        if year > currentYear { return false }
        return month < currentMonth
    }
}

private struct CreateBudgetPayload: Encodable {
    let anio: Int
    let mes: Int
    let total: Double
    let gastosRegistrados: Int
    let tendencia: String?
    let estado: String

    enum CodingKeys: String, CodingKey {
        case anio
        case mes
        case total
        case gastosRegistrados = "gastos_registrados"
        case tendencia
        case estado
    }
}

private struct BudgetErrorResponse: Decodable {
    let error: String
}

private enum BudgetStoreError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "La URL del backend no es válida."
        case .invalidResponse:
            return "No se pudo interpretar la respuesta del backend."
        case let .server(message):
            return message
        }
    }
}
