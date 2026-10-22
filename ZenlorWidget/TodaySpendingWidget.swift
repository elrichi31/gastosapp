import SwiftUI
import WidgetKit

/// Pantalla bloqueada: el gasto de hoy.
struct TodaySpendingWidget: Widget {
    let kind = "TodaySpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingProvider()) { entry in
            TodaySpendingView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(WidgetSummaryStore.widgetURL)
        }
        .configurationDisplayName("Gasto de hoy")
        .description("Lo que llevas gastado hoy y en el mes.")
        .supportedFamilies([.accessoryRectangular, .accessoryInline])
    }
}

private struct TodaySpendingView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendingEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Hoy \(entry.todayTotal.widgetCurrency)")
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("Hoy")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.todayTotal.widgetCurrency)
                    .font(WidgetTheme.number(20))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(entry.summary == nil ? "Abre Zenlor" : "\(entry.monthName): \(entry.monthTotal.widgetCurrencyRounded)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#Preview("Bloqueo", as: .accessoryRectangular) {
    TodaySpendingWidget()
} timeline: {
    SpendingEntry.sample()
}
