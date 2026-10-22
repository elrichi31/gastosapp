import SwiftUI

/// Gastos planeados dentro de una categoría del plan del mes.
///
/// Las filas siguen a las de Gastos: círculo con el icono y el color de la
/// categoría, descripción, pago y fecha debajo, y el monto con su signo. Antes
/// llevaban iniciales en un cuadrado gris y la fecha en dd/mm/aaaa, y no se
/// parecían a nada más de la app.
struct BudgetedMovementsSection: View {
    let category: Categoria
    let movements: [BudgetMovement]
    let paymentMethods: [ExpensePaymentMethod]
    let onSelect: (BudgetMovement) -> Void
    let onDelete: (BudgetMovement) -> Void

    /// Alto fijo de cada fila: la lista va dentro de otro desplazamiento y
    /// necesita saber cuánto mide para que funcione el deslizar para borrar.
    private static let rowHeight: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionTitle(title: "Gastos planeados", trailingText: movements.isEmpty ? nil : summary)
            if movements.isEmpty {
                emptyCard
            } else {
                movementList
            }
        }
    }

    private var summary: String {
        let total = movements.reduce(0) { $0 + $1.monto }
        let count = movements.count == 1 ? "1 gasto" : "\(movements.count) gastos"
        return "\(count) · \(total.formatted(.currency(code: "USD").precision(.fractionLength(2))))"
    }

    private var movementList: some View {
        List {
            ForEach(Array(movements.enumerated()), id: \.element.id) { index, movement in
                BudgetedMovementRow(
                    category: category,
                    movement: movement,
                    paymentMethod: paymentMethod(for: movement),
                    showsDivider: index < movements.count - 1,
                    onSelect: { onSelect(movement) }
                )
                .frame(height: Self.rowHeight)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Como en Gastos: sólo el icono y sin rol destructivo, que
                    // animaba la fila como borrada antes de confirmar.
                    Button {
                        onDelete(movement)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(AppTheme.negative)
                    .accessibilityLabel("Eliminar")
                }
            }
        }
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .frame(height: CGFloat(movements.count) * Self.rowHeight)
        .background(AppTheme.cardBackground())
        .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
        .animation(AppMotion.standard, value: movements.map(\.id))
    }

    private var emptyCard: some View {
        VStack(spacing: 14) {
            CategoryGlyph(
                categoria: category,
                size: 56,
                tint: category.color,
                background: category.color.opacity(0.16),
                isCircular: true
            )
            VStack(spacing: 6) {
                Text("Sin gastos planeados")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Agrega lo que piensas gastar en \(category.nombre.lowercased()) este mes para ver cuánto te queda.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(AppTheme.cardBackground())
    }

    private func paymentMethod(for movement: BudgetMovement) -> ExpensePaymentMethod {
        paymentMethods.first(where: { $0.id == movement.metodoPagoId }) ?? .placeholder
    }
}

struct BudgetedMovementRow: View {
    let category: Categoria
    let movement: BudgetMovement
    let paymentMethod: ExpensePaymentMethod
    let showsDivider: Bool
    let onSelect: () -> Void

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private var tags: [String] { (movement.tags ?? []).filter { $0 != "auto" } }

    private var subtitle: String {
        var parts = [paymentMethod.shortLabel, Self.dateFormatter.string(from: movement.parsedDate)]
        if let tag = tags.first { parts.append("#\(tag)") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                CategoryGlyph(
                    categoria: category,
                    size: 44,
                    tint: category.color,
                    background: category.color.opacity(0.16),
                    isCircular: true
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(movement.descripcion)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("−\(movement.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))")
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .overlay(alignment: .bottom) {
                if showsDivider { AppHairline().padding(.leading, 74) }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Editar")
    }
}
