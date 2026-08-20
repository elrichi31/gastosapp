import SwiftUI

struct BudgetAddMovementButton: View {
    let tint: Color
    let position: BudgetMovementGroupPosition
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(tint)
                Text("Agregar gasto")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(buttonBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Agregar gasto")
    }

    private var buttonBackground: some View {
        BudgetGroupedShape(position: position)
            .fill(AppTheme.primaryText.opacity(0.055))
            .overlay(
                BudgetGroupedShape(position: position)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            )
    }
}
