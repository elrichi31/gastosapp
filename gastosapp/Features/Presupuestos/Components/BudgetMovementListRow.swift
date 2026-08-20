import SwiftUI

struct BudgetMovementListRow: View {
    let movement: BudgetMovement
    let paymentMethod: ExpensePaymentMethod
    let position: BudgetMovementGroupPosition
    var tint: Color = AppTheme.primaryText

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(movement.descripcion)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill")
                        .font(.caption2)
                    Text(paymentMethod.shortLabel)
                    Text("•")
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(movement.dateLabel)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText.opacity(0.52))
            }

            Spacer(minLength: 12)

            Text(movement.monto, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.system(.subheadline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(rowBackground)
        .overlay(alignment: .bottom) {
            if position.showsBottomDivider {
                Divider()
                    .overlay(AppTheme.primaryText.opacity(0.08))
                    .padding(.horizontal, 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(movement.descripcion), \(movement.monto.budgetCurrency), \(paymentMethod.shortLabel), \(movement.dateLabel)")
    }

    private var rowBackground: some View {
        BudgetGroupedShape(position: position)
            .fill(AppTheme.primaryText.opacity(0.055))
            .overlay(
                BudgetGroupedShape(position: position)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }
}
