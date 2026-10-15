import SwiftUI

struct ForecastCategories: View {
    let forecast: ExpenseForecast
    @State private var showsAll = false
    private var sortedCategories: [ExpenseForecast.Category] {
        forecast.categories.sorted { ($0.projected ?? $0.recorded) > ($1.projected ?? $1.recorded) }
    }
    private var visibleCategories: [ExpenseForecast.Category] {
        showsAll ? sortedCategories : Array(sortedCategories.prefix(4))
    }

    var body: some View {
        ForecastSection(title: "Qué impulsa tus gastos", subtitle: forecast.projected == nil ? "Categorías ordenadas por gasto registrado" : "Categorías ordenadas por su cierre estimado") {
            if forecast.categories.isEmpty {
                Text("Las categorías aparecerán cuando registres gastos.").font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(visibleCategories) { category in
                    VStack(alignment: .leading, spacing: 10) {
                        ForecastAmountRow(category.name, detail: category.projected == nil ? "Registrado · aún sin estimación" : "Cierre estimado", value: category.projected ?? category.recorded)
                        GeometryReader { geometry in
                            let largest = sortedCategories.first.map { $0.projected ?? $0.recorded } ?? 0
                            let ratio = largest > 0 ? min(1, max(0, (category.projected ?? category.recorded) / largest)) : 0
                            Capsule().fill(AppTheme.controlSurface)
                            Capsule().fill(AppTheme.secondaryAccent.opacity(0.8)).frame(width: geometry.size.width * ratio)
                        }.frame(height: 5).accessibilityHidden(true)
                        Text("Registrado \(ForecastFormat.money(category.recorded)) · Anterior \(ForecastFormat.money(category.previous))")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }.padding(.vertical, 4).accessibilityElement(children: .combine)
                }
                Text("El ritmo por categoría se calcula por separado; su suma puede diferir del cierre total.")
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                if sortedCategories.count > 4 {
                    Button(showsAll ? "Ver menos" : "Ver las \(sortedCategories.count) categorías", systemImage: showsAll ? "chevron.up" : "chevron.down") { showsAll.toggle() }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryAccent).frame(minHeight: 44)
                }
            }
        }
    }
}

struct ForecastUpcomingPayments: View {
    let forecast: ExpenseForecast
    @State private var showsAll = false
    private var items: [ExpenseForecast.Upcoming] { forecast.upcoming.sorted { $0.date < $1.date } }
    var body: some View {
        ForecastSection(title: "Pagos en el horizonte", subtitle: "Recurrentes pendientes · ya incluidos en el cierre") {
            if items.isEmpty {
                Label("No hay pagos recurrentes pendientes", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(showsAll ? items : Array(items.prefix(3))) { item in
                    ForecastAmountRow(item.description, detail: ForecastFormat.date(item.date), value: item.amount, tint: AppTheme.secondaryAccent)
                }
                if items.count > 3 {
                    Button(showsAll ? "Ver menos" : "Ver los \(items.count) pagos", systemImage: showsAll ? "chevron.up" : "chevron.down") { showsAll.toggle() }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.secondaryAccent).frame(minHeight: 44)
                }
            }
        }
    }
}

struct ForecastMethodDetails: View {
    let forecast: ExpenseForecast
    @State private var isExpanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(forecast.status == "validated" ? "Contrastada con tu historial" : "Estimación inicial", systemImage: forecast.status == "validated" ? "checkmark.shield" : "clock")
                .font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primaryText)
            Text(forecast.status == "validated" ? "El método se comparó con meses anteriores. El resultado puede cambiar con nuevos gastos." : "Todavía falta historial para comprobar la precisión de la estimación.")
                .font(.subheadline).foregroundStyle(AppTheme.secondaryText)
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 18) {
                    if let method = forecast.methodLabel {
                        Text("Método elegido: \(method)").font(.subheadline.weight(.medium))
                    }
                    if let error = forecast.errorTypical {
                        ForecastAmountRow("Error habitual", detail: "Diferencia media frente al gasto real en meses anteriores", value: error)
                    }
                    if !forecast.trainingMonths.isEmpty {
                        Text("Historial utilizado: \(forecast.trainingMonths.map(ForecastFormat.month).joined(separator: ", ")).")
                            .font(.caption).foregroundStyle(AppTheme.secondaryText)
                    }
                    if !forecast.models.isEmpty {
                        Text("Métodos comparados").font(.subheadline.weight(.semibold))
                        ForEach(forecast.models) { model in
                            VStack(alignment: .leading, spacing: 6) {
                                ForecastAmountRow(model.label, detail: model.method == forecast.method ? "Elegido para este mes" : nil, value: model.projected)
                                if let mae = model.mae {
                                    Text("Error medio: \(ForecastFormat.money(mae))\(model.wape.map { " · " + $0.formatted(.number.precision(.fractionLength(1))) + "% relativo" } ?? "")")
                                        .font(.caption).foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                        }
                    }
                    if !forecast.backtest.isEmpty {
                        Text("Estimación frente al cierre real").font(.subheadline.weight(.semibold))
                        ForEach(forecast.backtest) { month in
                            ForecastAmountRow(ForecastFormat.month(month.month), detail: forecast.method.flatMap { month.predictions[$0] }.map { "Estimado: " + ForecastFormat.money($0) }, value: month.actual)
                        }
                    }
                    if !forecast.warnings.isEmpty {
                        Text("Qué tener en cuenta").font(.subheadline.weight(.semibold))
                        ForEach(forecast.warnings, id: \.self) { warning in
                            Text(warning).font(.caption).foregroundStyle(AppTheme.secondaryText)
                        }
                    }
                }.padding(.top, 16).foregroundStyle(AppTheme.primaryText)
            } label: {
                Text("Cómo se calcula").font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }.tint(AppTheme.secondaryAccent)
        }.padding(20).background(AppTheme.cardBackground())
    }
}
