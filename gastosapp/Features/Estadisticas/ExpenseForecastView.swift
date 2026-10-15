import SwiftUI

struct ExpenseForecastView: View {
    @Environment(ExpenseStore.self) private var session
    @State private var model = ExpenseForecastStore()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let forecast = model.forecast {
                    ForecastContent(forecast: forecast, pendingExpenseCount: session.pendingExpenseCount)
                } else if model.isLoading {
                    VStack(spacing: 16) {
                        ProgressView().tint(AppTheme.accent)
                        Text("Preparando tu proyección").font(.headline)
                        Text("Revisamos tu historial y los pagos que vienen.")
                            .font(.subheadline).foregroundStyle(AppTheme.secondaryText).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 48).padding(.horizontal, 20)
                    .background(AppTheme.cardBackground())
                }
                if let error = model.error {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("No pudimos actualizar la proyección", systemImage: "wifi.exclamationmark").font(.headline)
                        Text(error).font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                        Button("Reintentar", systemImage: "arrow.clockwise") { Task { await model.load(using: session) } }
                            .buttonStyle(.bordered).tint(AppTheme.accent).disabled(model.isLoading)
                    }.padding(20).background(AppTheme.cardBackground())
                }
            }
            .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .navigationTitle("Proyecciones").navigationBarTitleDisplayMode(.inline)
        .task { await model.load(using: session) }
        .refreshable { await model.load(using: session) }
    }
}

/// Sin dependencias de red, permite previsualizar los estados con el contrato real.
struct ForecastContent: View {
    let forecast: ExpenseForecast
    var pendingExpenseCount = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text(ForecastFormat.month(forecast.month)).font(.title2.weight(.bold)).foregroundStyle(AppTheme.primaryText)
                Text("Datos al \(ForecastFormat.date(forecast.today)) · desliza para actualizar")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
            }.padding(.vertical, 4)
            ForecastSummary(forecast: forecast)
            if pendingExpenseCount > 0 {
                ForecastNotice(icon: "icloud.and.arrow.up", message: "Hay \(pendingExpenseCount) gastos por sincronizar. Se incluirán en la proyección cuando se suban.")
            }
            ForecastTrendChart(forecast: forecast)
            ForecastDailyGuide(forecast: forecast)
            ForecastBreakdown(forecast: forecast)
            ForecastUpcomingPayments(forecast: forecast)
            ForecastCategories(forecast: forecast)
            ForecastMethodDetails(forecast: forecast)
            Text("Solo incluye gastos registrados y recurrentes identificados. Los correos pendientes y los gastos sin registrar pueden cambiar el cierre.")
                .font(.caption).foregroundStyle(AppTheme.secondaryText).padding(.horizontal, 4)
        }
    }
}
