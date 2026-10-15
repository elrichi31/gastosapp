import SwiftUI
import Charts

struct ForecastTrendChart: View {
    let forecast: ExpenseForecast
    @State private var selectedDay: Int?

    private var inspectedPoint: ExpenseForecast.Point? {
        let day = selectedDay ?? Int(forecast.today.suffix(2)) ?? 1
        return forecast.points.min { abs($0.day - day) < abs($1.day - day) }
    }

    var body: some View {
        ForecastSection(title: "Así va tu mes", subtitle: "Gasto acumulado · toca el gráfico para explorar") {
            VStack(alignment: .leading, spacing: 12) {
                if let point = inspectedPoint {
                    Text(ForecastFormat.date(point.date)).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { pointValues(point) }
                        VStack(alignment: .leading, spacing: 8) { pointValues(point) }
                    }
                }
                Chart {
                    ForEach(forecast.points) { point in
                        if let actual = point.actual {
                            LineMark(x: .value("Día", point.day), y: .value("USD", actual))
                                .foregroundStyle(by: .value("Serie", "Registrado"))
                                .lineStyle(StrokeStyle(lineWidth: 3))
                        }
                        if let projected = point.forecast {
                            LineMark(x: .value("Día", point.day), y: .value("USD", projected))
                                .foregroundStyle(by: .value("Serie", "Proyección"))
                                .lineStyle(StrokeStyle(lineWidth: 2.5, dash: [5, 4]))
                        }
                        if let previous = point.previous {
                            LineMark(x: .value("Día", point.day), y: .value("USD", previous))
                                .foregroundStyle(by: .value("Serie", "Mes anterior"))
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                        }
                    }
                    if let point = inspectedPoint {
                        RuleMark(x: .value("Día seleccionado", point.day))
                            .foregroundStyle(AppTheme.tertiaryText).lineStyle(StrokeStyle(dash: [3, 3]))
                    }
                }
                .chartForegroundStyleScale(["Registrado": AppTheme.accent, "Proyección": AppTheme.secondaryAccent, "Mes anterior": AppTheme.secondaryText])
                .chartLegend(.hidden)
                .chartXScale(domain: 1...max(2, forecast.days))
                .chartYScale(domain: .automatic(includesZero: true))
                .chartXSelection(value: $selectedDay)
                .chartXAxis {
                    AxisMarks(values: [1, 10, 20, forecast.days]) { value in
                        AxisValueLabel { if let day = value.as(Int.self) { Text("\(day)").foregroundStyle(AppTheme.secondaryText) } }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine().foregroundStyle(AppTheme.border)
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(amount, format: .currency(code: "USD").precision(.fractionLength(0)).notation(.compactName))
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                        }
                    }
                }
                .frame(height: 220)
                .accessibilityLabel("Evolución del gasto acumulado de \(ForecastFormat.month(forecast.month))")
                .accessibilityHint("Compara el gasto registrado, la proyección y el mes anterior")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { legend }
                    VStack(alignment: .leading, spacing: 8) { legend }
                }
            }
        }
    }

    @ViewBuilder private var legend: some View {
        legendItem("Registrado", color: AppTheme.accent, dash: [])
        if forecast.projected != nil { legendItem("Proyección", color: AppTheme.secondaryAccent, dash: [4, 3]) }
        if forecast.previous != nil { legendItem("Mes anterior", color: AppTheme.secondaryText, dash: [2, 2]) }
    }

    private func legendItem(_ title: String, color: Color, dash: [CGFloat]) -> some View {
        HStack(spacing: 5) {
            Path { path in path.move(to: .zero); path.addLine(to: CGPoint(x: 16, y: 0)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dash)).frame(width: 16, height: 2).accessibilityHidden(true)
            Text(title).font(.caption).foregroundStyle(AppTheme.secondaryText)
        }
    }

    @ViewBuilder private func pointValues(_ point: ExpenseForecast.Point) -> some View {
        if let actual = point.actual { value("Registrado", amount: actual, color: AppTheme.accent) }
        if let estimate = point.forecast { value("Estimado", amount: estimate, color: AppTheme.secondaryAccent) }
        if let previous = point.previous { value("Anterior", amount: previous, color: AppTheme.secondaryText) }
    }

    private func value(_ title: String, amount: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(AppTheme.secondaryText)
            Text(ForecastFormat.money(amount)).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(color)
        }.accessibilityElement(children: .combine)
    }
}
