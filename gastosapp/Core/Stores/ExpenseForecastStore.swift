import Foundation
import Observation

@MainActor @Observable
final class ExpenseForecastStore {
    var forecast: ExpenseForecast?
    var isLoading = false
    var error: String?
    private var requestID = UUID()
    func load(using session: ExpenseStore) async {
        let id = UUID(); requestID = id
        isLoading = true; error = nil
        defer { if requestID == id { isLoading = false } }
        do {
            let today = AppDateCodec.apiDateString(from: Date())
            let result = try await session.request(ExpenseForecast.self, path: "/api/estadisticas/proyeccion?today=\(today)", requiresAuth: true)
            guard requestID == id else { return }
            forecast = result
        } catch { if requestID == id && !isCancellationError(error) { self.error = error.localizedDescription } }
    }
}
