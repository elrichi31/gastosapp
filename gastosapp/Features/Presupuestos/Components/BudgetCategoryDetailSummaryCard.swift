import SwiftUI

struct BudgetCategoryDetailSummaryCard: View {
    let category: BudgetCategoryDetail
    let metrics: BudgetCategoryMetrics
    let monthTitle: String
    let onAddMovement: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topRow
            metricsRow
            progressSection
        }
        .padding(22)
        .background(background)
    }

    private var topRow: some View {
        HStack(alignment: .top, spacing: 14) {
            iconBadge
            remainingColumn
            Spacer()
            addButton
        }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(tint)
            .frame(width: 54, height: 54)
            .overlay(
                Image(systemName: category.displayCategory.icono)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            )
    }

    private var remainingColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Restante")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.3)
                .foregroundStyle(AppTheme.primaryText.opacity(0.46))
            Text(metrics.remaining, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.system(size: 38, weight: .bold, design: .default))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.62)
                .lineLimit(1)
        }
    }

    private var addButton: some View {
        Button(action: onAddMovement) {
            HStack(spacing: 6) {
                Text("Gasto")
                Image(systemName: "plus")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.onAccent)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(AppTheme.accent))
        }
        .buttonStyle(.plain)
    }

    private var metricsRow: some View {
        HStack(spacing: 14) {
            metricColumn("Consumido", metrics.spent)
            divider
            metricColumn("Planificado", metrics.budgeted)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            progressBar
            HStack {
                Text("\(Int(round(metrics.progressPercentage)))% usado")
                Spacer()
                Text("Presupuesto \(monthTitle)")
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.primaryText.opacity(0.52))
        }
    }

    private func metricColumn(_ title: String, _ amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.primaryText.opacity(0.42))
            Text(amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.system(.subheadline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.primaryText.opacity(0.10))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * metrics.progressValue, metrics.progressValue > 0 ? 12 : 0))
            }
        }
        .frame(height: 8)
    }

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.primaryText.opacity(0.10))
            .frame(width: 1, height: 38)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(tint.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(tint.opacity(0.24), lineWidth: 1)
            )
    }

    private var tint: Color { category.displayCategory.color }
}
