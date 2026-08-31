import SwiftUI

struct BudgetCategorySummaryCard: View {
    let category: BudgetCategoryDetail
    let metrics: BudgetCategoryMetrics
    var onAddMovement: (() -> Void)?
    var position: BudgetMovementGroupPosition = .single

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            amountRow
            progressBar
            footerRow
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .topLeading)
        .padding(14)
        .background(cardBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category.displayCategory.nombre), \(category.movimientos.count) movimientos, \(Int(metrics.progressPercentage)) por ciento usado")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            iconBadge

            Text(category.displayCategory.nombre)
                .font(.system(.subheadline, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onAddMovement {
                Button(action: onAddMovement) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(tint))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Agregar movimiento a \(category.displayCategory.nombre)")
            }
        }
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tint.opacity(0.15))
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: category.displayCategory.icono)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
            )
    }

    private var amountRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(metrics.spent, format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)

            Text("/ \(Int(metrics.budgeted))")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.controlSurface)
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * metrics.progressValue, metrics.progressValue > 0 ? 10 : 0))
            }
        }
        .frame(height: 6)
        .animation(.easeOut(duration: 0.28), value: metrics.progressValue)
    }

    private var footerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Restante \(metrics.remaining.budgetCurrency)")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 6)
            Text("\(Int(round(metrics.progressPercentage)))%")
                .monospacedDigit()
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(AppTheme.tertiaryText)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
    }

    private var tint: Color { AppTheme.accent }
}
