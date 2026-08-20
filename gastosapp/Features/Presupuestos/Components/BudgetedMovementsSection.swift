import SwiftUI

struct BudgetedMovementsSection: View {
    let movements: [BudgetMovement]
    let paymentMethods: [ExpensePaymentMethod]
    let onSelect: (BudgetMovement) -> Void
    let onDelete: (BudgetMovement) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            content
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Gastos presupuestados")
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(countLabel)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.46))
        }
    }

    @ViewBuilder
    private var content: some View {
        if movements.isEmpty {
            emptyCard
        } else {
            movementList
        }
    }

    private var movementList: some View {
        List {
            ForEach(Array(movements.enumerated()), id: \.element.id) { index, movement in
                BudgetedMovementDetailRow(
                    movement: movement,
                    paymentMethod: paymentMethod(for: movement),
                    showsDivider: index < movements.count - 1,
                    onSelect: { onSelect(movement) }
                )
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        onDelete(movement)
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .frame(height: CGFloat(movements.count) * 74)
        .background(AppTheme.cardBackground(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.30))
            Text("Sin gastos presupuestados")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Agrega ítems como almuerzo, mercado o transporte para planificar esta categoría.")
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText.opacity(0.50))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(AppTheme.cardBackground(cornerRadius: 24))
    }

    private var countLabel: String {
        movements.count == 1 ? "1 item" : "\(movements.count) items"
    }

    private func paymentMethod(for movement: BudgetMovement) -> ExpensePaymentMethod {
        paymentMethods.first(where: { $0.id == movement.metodoPagoId }) ?? .placeholder
    }
}

private struct BudgetedMovementDetailRow: View {
    let movement: BudgetMovement
    let paymentMethod: ExpensePaymentMethod
    let showsDivider: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            rowContent
        }
        .buttonStyle(.plain)
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            initialsBadge
            details
            Spacer()
            amount
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.clear)
        .overlay(alignment: .bottom) { divider }
    }

    private var initialsBadge: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .foregroundStyle(AppTheme.primaryText.opacity(0.52))
            .frame(width: 46, height: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.primaryText.opacity(0.07)))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(movement.descripcion)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
            Text("\(paymentMethod.shortLabel) · \(movement.dateLabel)")
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText.opacity(0.44))
        }
    }

    private var amount: some View {
        Text(movement.monto, format: .currency(code: "USD").precision(.fractionLength(2)))
            .font(.system(.subheadline, design: .default, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(AppTheme.primaryText)
    }

    @ViewBuilder
    private var divider: some View {
        if showsDivider {
            Divider()
                .overlay(AppTheme.primaryText.opacity(0.08))
                .padding(.leading, 78)
        }
    }

    private var initials: String {
        let letters = movement.descripcion
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let value = String(letters).uppercased()
        return value.isEmpty ? "PR" : value
    }
}
