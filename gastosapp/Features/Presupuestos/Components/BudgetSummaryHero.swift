import SwiftUI

struct BudgetSummaryHero: View {
    let budget: BudgetMonthly
    let snapshot: BudgetMonthSpendingSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topRow
            remainingBlock
            segmentedProgress
            footerRow
        }
        .padding(24)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            AppSectionLabel(text: "Restante en \(budget.monthTitle)")

            Spacer()

            statusChip
        }
    }

    private var statusChip: some View {
        Text(snapshot.monthlyMetrics.status.uppercased())
            .font(AppTheme.number(11, .bold))
            .tracking(0.6)
            .foregroundStyle(AppTheme.accent)
            .padding(.horizontal, 12)
            .frame(height: 28)
        .background(
            Capsule()
                .fill(AppTheme.accent.opacity(0.14))
        )
    }

    private var remainingBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(snapshot.monthlyMetrics.remaining, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(AppTheme.number(50, .bold))
                .monospacedDigit()
                .kerning(-1.4)
                .contentTransition(.numericText())
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text("de \(snapshot.monthlyMetrics.budgeted.budgetCurrency) planificados · \(daysRemainingInMonth) días por delante")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(2)
        }
    }

    private var segmentedProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.insetSurface)

                    HStack(spacing: 0) {
                        ForEach(snapshot.progressSegments) { segment in
                            Rectangle()
                                .fill(segment.color)
                                .frame(width: proxy.size.width * segment.fraction)
                        }
                    }
                    .frame(maxWidth: proxy.size.width, alignment: .leading)
                    .clipShape(Capsule())
                }
            }
            .frame(height: 10)
            .animation(.easeOut(duration: 0.35), value: snapshot.monthlyMetrics.spent)
        }
    }

    private var footerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Consumido \(snapshot.monthlyMetrics.spent.budgetCurrency)")
            Spacer()
            Text("\(Int(round(snapshot.monthlyMetrics.progressPercentage)))% del mes")
        }
        .font(AppTheme.number(13, .semibold))
        .foregroundStyle(AppTheme.secondaryText)
    }

    private var cardBackground: some View {
        AppTheme.cardBackground(cornerRadius: 28)
    }

    private var daysRemainingInMonth: Int {
        let calendar = Calendar.current
        guard
            let monthStart = calendar.date(from: DateComponents(year: budget.anio, month: budget.mes, day: 1)),
            let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
        else { return 0 }

        let start = max(calendar.startOfDay(for: Date()), calendar.startOfDay(for: monthStart))
        guard start <= monthEnd else { return 0 }
        return (calendar.dateComponents([.day], from: start, to: monthEnd).day ?? 0) + 1
    }
}
