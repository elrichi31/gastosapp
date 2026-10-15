import SwiftUI

struct ForecastSummary: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 48.0
    let forecast: ExpenseForecast

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("CIERRE ESTIMADO").font(.caption.weight(.semibold)).tracking(1.2)
                .foregroundStyle(AppTheme.statementSecondary)
            if let projected = forecast.projected {
                Text(ForecastFormat.money(projected))
                    .font(AppTheme.number(amountSize, .bold)).monospacedDigit().kerning(-1.5)
                    .foregroundStyle(AppTheme.onStatement).lineLimit(1).minimumScaleFactor(0.5)
                Text("Si mantienes tu patrón de gastos actual.")
                    .font(.subheadline).foregroundStyle(AppTheme.statementSecondary)
                if let range = forecast.range {
                    Text("Entre \(ForecastFormat.money(range.low)) y \(ForecastFormat.money(range.high)) según las desviaciones observadas en tu historial.")
                        .font(.caption).foregroundStyle(AppTheme.statementSecondary)
                }
            } else {
                Text("Aún es pronto").font(.largeTitle.bold()).foregroundStyle(AppTheme.onStatement)
                Text("Registra más gastos para estimar el cierre. Por ahora puedes ver lo registrado y tus pagos pendientes.")
                    .font(.subheadline).foregroundStyle(AppTheme.statementSecondary)
            }
            AppTheme.statementHairline
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16)) : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
            layout {
                metric("Registrado", value: forecast.recorded)
                metric("Pagos pendientes", value: forecast.committed)
            }
            if let projected = forecast.projected, let previous = forecast.previous {
                let difference = projected - previous.total
                Label(difference == 0 ? "Igual al mes anterior" : "\(ForecastFormat.money(abs(difference))) \(difference > 0 ? "más" : "menos") que el mes anterior", systemImage: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.medium)).foregroundStyle(AppTheme.onStatement)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(24)
        .background(AppTheme.statementBackground())
        .accessibilityElement(children: .combine)
    }

    private func metric(_ title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(AppTheme.statementSecondary)
            Text(ForecastFormat.money(value)).font(.title3.weight(.semibold)).monospacedDigit().foregroundStyle(AppTheme.onStatement)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ForecastBreakdown: View {
    let forecast: ExpenseForecast
    var body: some View {
        ForecastSection(title: "De dónde sale el total", subtitle: "Lo que ya gastaste y lo que falta este mes") {
            ForecastAmountRow("Gastos registrados", detail: forecast.futureRecorded > 0 ? "Incluye \(ForecastFormat.money(forecast.futureRecorded)) con fecha futura" : nil, value: forecast.recorded)
            ForecastAmountRow("Recurrentes por pagar", value: forecast.committed, tint: AppTheme.secondaryAccent)
            if let remaining = forecast.variableRemaining {
                ForecastAmountRow("Otros gastos estimados", detail: "Según tu ritmo e historial", value: remaining)
            }
            Divider().overlay(AppTheme.border)
            ForecastAmountRow("Mínimo comprometido", detail: "Registrado + recurrentes pendientes", value: forecast.floor)
        }
    }
}

struct ForecastDailyGuide: View {
    let forecast: ExpenseForecast
    var body: some View {
        if let allowance = forecast.dailyAllowance, let previous = forecast.previous {
            ForecastSection(title: allowance > 0 ? "Una referencia para tus próximos días" : "Ya alcanzaste el mes anterior", subtitle: "Comparado con \(ForecastFormat.month(previous.month).lowercased())") {
                if allowance > 0 {
                    Text("\(ForecastFormat.money(allowance)) / día")
                        .font(.title2.bold()).monospacedDigit().foregroundStyle(AppTheme.accent)
                    Text("Para cerrar sin superar los \(ForecastFormat.money(previous.total)) del mes anterior, después de cubrir los recurrentes pendientes.")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                } else {
                    Text("Lo registrado y los pagos pendientes ya suman \(ForecastFormat.money(forecast.floor)). El mes anterior cerró en \(ForecastFormat.money(previous.total)).")
                        .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
                }
                Text("Es una comparación con tu historial, no tu presupuesto.").font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
        }
    }
}
