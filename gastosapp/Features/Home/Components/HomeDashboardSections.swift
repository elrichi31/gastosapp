import SwiftUI

struct HomeUpcomingChargesSection: View {
    let upcomingItems: [HomeRecurringPreview]
    let dueSoonValue: String
    let monthlyEstimateValue: String
    let dayLabel: (RecurringExpense) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "Próximos cobros", trailingText: upcomingItems.isEmpty ? "sin agenda" : "hasta 3")

            if upcomingItems.isEmpty {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "repeat.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("No tienes cargos próximos")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("Cuando agregues un gasto recurrente o una suscripción, te mostraré aquí lo siguiente que viene.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    HomeMetricTile(title: "En 7 días", value: dueSoonValue, icon: "calendar", tint: AppTheme.secondaryAccent)
                    HomeMetricTile(title: "Fijo mensual", value: monthlyEstimateValue, icon: "repeat.circle.fill", tint: AppTheme.accent)
                }

                VStack(spacing: 10) {
                    ForEach(upcomingItems) { preview in
                        HStack(spacing: 12) {
                            Image(systemName: preview.expense.isSubscriptionLike ? "rectangle.stack.fill" : "repeat.circle.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(preview.expense.isSubscriptionLike ? AppTheme.secondaryAccent : AppTheme.accent)
                                .frame(width: 34, height: 34)
                                .background((preview.expense.isSubscriptionLike ? AppTheme.secondaryAccent : AppTheme.accent).opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(preview.expense.descripcion)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(dayLabel(preview.expense)) • \(preview.expense.cadenceLabel)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Text(preview.expense.monto.budgetCurrency)
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.insetSurface)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                        )
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct HomeInsightsSection: View {
    let insights: [HomeSmartInsight]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeader(title: "Consejos inteligentes", trailingText: "hoy")

            VStack(spacing: 10) {
                ForEach(insights) { insight in
                    HomeInsightRow(insight: insight)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

struct HomeSavingsGoalSection: View {
    let monthlyTargetValue: String
    let budgetBase: Double
    let monthlyTarget: Double
    let spendableAllowanceValue: String
    let suggestedDailyValue: String
    let availableAllowance: Double
    let allowanceProgress: Double
    let statusMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.secondaryAccent)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.secondaryAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Objetivo de ahorro")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Meta mensual: \(monthlyTargetValue)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()
            }

            if budgetBase <= 0 {
                HomeMessageCard(
                    title: "Crea un presupuesto mensual",
                    message: "Con un presupuesto puedo separar tu meta y calcular cuánto gastar por día.",
                    icon: "target",
                    tint: AppTheme.warning
                )
            } else if monthlyTarget >= budgetBase {
                HomeMessageCard(
                    title: "La meta supera tu presupuesto",
                    message: "Baja la meta o sube el presupuesto para tener cupo de gasto este mes.",
                    icon: "exclamationmark.triangle.fill",
                    tint: AppTheme.warning
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        HomeSavingsMetric(title: "Cupo gastable", value: spendableAllowanceValue)
                        HomeSavingsMetric(title: "Por día", value: suggestedDailyValue)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.controlSurface)
                            Capsule()
                                .fill(availableAllowance >= 0 ? AppTheme.secondaryAccent : AppTheme.warning)
                                .frame(width: max(proxy.size.width * allowanceProgress, 8))
                        }
                    }
                    .frame(height: 8)

                    Text(statusMessage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.insetSurface)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
                )
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

struct HomeRecent30DaysSection: View {
    let bars: [DailyExpenseBar]
    var totalValue: String = ""
    @Binding var selectedBar: DailyExpenseBar?
    let dayLabel: (Date?) -> String
    let accessibilityLabel: (DailyExpenseBar) -> String

    private var maxValue: Double {
        bars.map(\.total).max() ?? 0
    }

    private var latestActiveDate: Date? {
        bars.last(where: { $0.total > 0 })?.date
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Resumen mensual")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                Text("Tus gastos")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.primaryText)
                if !totalValue.isEmpty {
                    Text(totalValue)
                        .font(AppTheme.number(34, .bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.top, 6)
                }
            }

            GeometryReader { proxy in
                let spacing: CGFloat = 4
                let availableWidth = max(0, proxy.size.width - (spacing * 29))
                let barWidth = max(6, min(12, availableWidth / 30))

                HStack(alignment: .bottom, spacing: spacing) {
                    ForEach(bars) { bar in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                selectedBar = bar
                            }
                        } label: {
                            HomeRecentDayBar(
                                bar: bar,
                                width: barWidth,
                                maxValue: maxValue,
                                isHighlighted: bar.date == (selectedBar?.date ?? latestActiveDate)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityLabel(bar))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 84, alignment: .bottom)

            HStack {
                Text(dayLabel(bars.first?.date))
                Spacer()
                Text(dayLabel(Date()))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.tertiaryText)

            if let selectedBar {
                HomeRecentDayDetailCard(bar: selectedBar, dayLabel: dayLabel)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(AppTheme.strongBorder, lineWidth: 1))
        )
    }
}

struct HomeCategoriesSection: View {
    let title: String
    let trailingText: String
    let totals: [(Categoria, Double)]
    let totalAmount: Double
    let onSelectCategory: (Categoria) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(trailingText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if totals.isEmpty {
                Text("Sin gastos este mes")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 18) {
                    ForEach(totals, id: \.0) { category, amount in
                        Button {
                            onSelectCategory(category)
                        } label: {
                            HomeCategoryRow(category: category, amount: amount, totalAmount: totalAmount)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Muestra los gastos de esta categoría")
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HomeInsightRow: View {
    let insight: HomeSmartInsight

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 34, height: 34)
                .background(insight.tint.opacity(0.82), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text(insight.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }
}

private struct HomeSavingsMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value)
                .font(.system(.headline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }
}

private struct HomeMessageCard: View {
    let title: String
    let message: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }
}

private struct HomeRecentDayBar: View {
    let bar: DailyExpenseBar
    let width: CGFloat
    let maxValue: Double
    let isHighlighted: Bool

    var body: some View {
        if bar.total > 0 {
            let height = max(12, CGFloat(bar.total / max(maxValue, 1)) * 78)

            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHighlighted ? AppTheme.accent : AppTheme.accent.opacity(0.22))
            .frame(width: width, height: height, alignment: .bottom)
            .frame(width: width, height: 84, alignment: .bottom)
        } else {
            Capsule()
                .fill(AppTheme.controlSurface)
                .frame(width: width, height: width)
                .frame(width: width, height: 84, alignment: .bottom)
        }
    }
}

private struct HomeRecentDayDetailCard: View {
    let bar: DailyExpenseBar
    let dayLabel: (Date?) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayLabel(bar.date))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Text(bar.total, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }

            if bar.segments.isEmpty {
                Text("Sin gastos registrados ese día")
                    .font(.caption)
                    .foregroundStyle(AppTheme.tertiaryText)
            } else {
                VStack(spacing: 6) {
                    ForEach(bar.segments) { segment in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 8, height: 8)
                            Text(segment.categoryName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            Text(segment.amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.primaryText)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }
}

private struct HomeCategoryRow: View {
    let category: Categoria
    let amount: Double
    let totalAmount: Double

    var body: some View {
        let percentage = totalAmount > 0 ? amount / totalAmount : 0.0

        VStack(spacing: 8) {
            HStack(spacing: 12) {
                CategoryGlyph(categoria: category, size: 42)
                Text(category.nombre)
                    .font(.system(.headline, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Text(amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.system(.headline, design: .default, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(Int(round(percentage * 100)))%")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(width: 46, alignment: .trailing)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(AppTheme.controlSurface))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.controlSurface)
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: max(proxy.size.width * percentage, 8))
                }
            }
            .frame(height: 7)
        }
    }
}

struct HomeMetricTile: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                AppSectionLabel(text: title, size: 10)
            }
            Text(value)
                .font(AppTheme.number(15, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.insetBackground(cornerRadius: 14))
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let trailingText: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(AppTheme.number(17, .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            AppSectionLabel(text: trailingText, size: 10)
        }
    }
}
