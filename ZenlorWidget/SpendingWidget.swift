import SwiftUI
import WidgetKit

/// Pantalla de inicio: gasto del mes (pequeño) y mes + hoy + presupuesto (mediano).
struct SpendingWidget: Widget {
    let kind = "SpendingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SpendingProvider()) { entry in
            SpendingWidgetView(entry: entry)
                .containerBackground(WidgetTheme.surface, for: .widget)
                .widgetURL(WidgetSummaryStore.widgetURL)
        }
        .configurationDisplayName("Gasto del mes")
        .description("Lo que llevas gastado este mes, hoy y frente a tu presupuesto.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct SpendingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendingEntry

    var body: some View {
        if entry.summary == nil {
            EmptySpendingView()
        } else if family == .systemMedium {
            MediumSpendingView(entry: entry)
        } else {
            SmallSpendingView(entry: entry)
        }
    }
}

// MARK: - Pequeño

private struct SmallSpendingView: View {
    let entry: SpendingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetEyebrow(text: entry.monthName)
            Spacer(minLength: 6)
            Text(entry.monthTotal.widgetCurrencyRounded)
                .font(WidgetTheme.number(30, .bold))
                .monospacedDigit()
                .foregroundStyle(WidgetTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("gastado este mes")
                .font(.caption)
                .foregroundStyle(WidgetTheme.secondaryText)
            Spacer(minLength: 6)
            MonthChangeLabel(entry: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

// MARK: - Mediano

private struct MediumSpendingView: View {
    let entry: SpendingEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    WidgetEyebrow(text: entry.monthName)
                    Text(entry.monthTotal.widgetCurrencyRounded)
                        .font(WidgetTheme.number(28, .bold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    MonthChangeLabel(entry: entry)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Hoy")
                        .font(WidgetTheme.label())
                        .foregroundStyle(WidgetTheme.secondaryText)
                    Text(entry.todayTotal.widgetCurrency)
                        .font(WidgetTheme.number(18))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            Spacer(minLength: 8)
            BudgetBar(spent: entry.monthTotal, budget: entry.budget)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct BudgetBar: View {
    let spent: Double
    let budget: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Presupuesto")
                    .font(WidgetTheme.label())
                    .foregroundStyle(WidgetTheme.secondaryText)
                Spacer(minLength: 4)
                Text(caption)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(captionColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(WidgetTheme.track)
                    if ratio > 0 {
                        Capsule()
                            .fill(barColor)
                            .frame(width: max(proxy.size.width * min(ratio, 1), 6))
                    }
                }
            }
            .frame(height: 8)
        }
    }

    private var ratio: Double {
        guard let budget, budget > 0 else { return 0 }
        return spent / budget
    }

    private var caption: String {
        guard let budget else { return "Sin presupuesto este mes" }
        if spent > budget { return "Te pasaste por \((spent - budget).widgetCurrencyRounded)" }
        return "\(spent.widgetCurrencyRounded) de \(budget.widgetCurrencyRounded)"
    }

    private var barColor: Color {
        if ratio > 1 { return WidgetTheme.negative }
        if ratio >= 0.8 { return WidgetTheme.warning }
        return WidgetTheme.accent
    }

    private var captionColor: Color {
        ratio > 1 ? WidgetTheme.negative : WidgetTheme.secondaryText
    }
}

// MARK: - Piezas comunes

private struct WidgetEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(WidgetTheme.accent)
                .frame(width: 6, height: 6)
            Text(text)
                .font(WidgetTheme.label(12))
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
        }
    }
}

/// «↓ 12 % vs. sep.»: gastar menos es bueno, así que la bajada va en verde.
private struct MonthChangeLabel: View {
    let entry: SpendingEntry

    var body: some View {
        if let change = entry.monthChange {
            let percent = Int((abs(change) * 100).rounded())
            HStack(spacing: 3) {
                Image(systemName: change > 0 ? "arrow.up.right" : change < 0 ? "arrow.down.right" : "equal")
                    .font(.caption2.weight(.bold))
                Text("\(percent) % vs. \(entry.previousMonthShortName)")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(color(for: change))
        } else {
            Text("Sin datos de \(entry.previousMonthShortName)")
                .font(.caption)
                .foregroundStyle(WidgetTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func color(for change: Double) -> Color {
        if change == 0 { return WidgetTheme.secondaryText }
        return change > 0 ? WidgetTheme.negative : WidgetTheme.positive
    }
}

private struct EmptySpendingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetEyebrow(text: "Zenlor")
            Spacer(minLength: 0)
            Text("Abre Zenlor para ver tus gastos aquí.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(WidgetTheme.primaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview("Pequeño", as: .systemSmall) {
    SpendingWidget()
} timeline: {
    SpendingEntry.sample()
    SpendingEntry(date: Date(), summary: nil)
}

#Preview("Mediano", as: .systemMedium) {
    SpendingWidget()
} timeline: {
    SpendingEntry.sample()
}
