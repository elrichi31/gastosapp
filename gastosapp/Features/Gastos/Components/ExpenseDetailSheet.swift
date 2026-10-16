import SwiftUI

/// Detalle de un gasto al tocarlo en la lista.
///
/// Sigue el lenguaje de los formularios: barra con cerrar sobre cristal,
/// filas agrupadas y las acciones fijas al pie. Arriba, el monto grande con
/// el icono de la categoría en su color, como en la fila de la que viene.
struct ExpenseDetailSheet: View {
    let expense: Expense
    let onClose: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Environment(ExpenseStore.self) private var store
    @State private var showsDeleteConfirmation = false

    private static let emailTag = "auto"
    private static let calendar = Calendar.current

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "EEEE d 'de' MMMM, yyyy"
        return formatter
    }()

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "MMMM"
        return formatter
    }()

    private var tags: [String] { (expense.tags ?? []).filter { $0 != Self.emailTag } }
    private var isFromEmail: Bool { expense.tags?.contains(Self.emailTag) == true }

    private var dateText: String {
        let text = Self.dateFormatter.string(from: expense.fecha)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// Lo gastado en la misma categoría y mes, para dar contexto al monto.
    private var categoryMonth: (total: Double, count: Int) {
        let sameMonth = store.gastos.filter {
            $0.categoriaId == expense.categoriaId
                && Self.calendar.isDate($0.fecha, equalTo: expense.fecha, toGranularity: .month)
        }
        return (sameMonth.reduce(0) { $0 + $1.monto }, sameMonth.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                hero
                details
                if let tax = expense.foreignTax { foreignTaxSection(tax) }
                if !tags.isEmpty { tagsSection }
                monthContext
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            FormSheetChrome {
                FormSheetHeader(title: "Detalle", onClose: onClose)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormStickySaveBar { actions }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground { AppTheme.screenBackground }
        .alert("Eliminar gasto", isPresented: $showsDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive, action: onDelete)
        } message: {
            Text("\"\(expense.descripcion)\" se eliminará de tu historial.")
        }
    }

    // MARK: - Encabezado

    private var hero: some View {
        VStack(spacing: 12) {
            CategoryGlyph(
                categoria: expense.categoria,
                size: 64,
                tint: expense.categoria.color,
                background: expense.categoria.color.opacity(0.16),
                isCircular: true
            )

            Text(expense.descripcion)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Text("−\(expense.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))")
                .font(.system(size: 46, weight: .bold))
                .tracking(-1.2)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if !badges.isEmpty {
                HStack(spacing: 6) {
                    ForEach(badges, id: \.title) { badge in
                        Label(badge.title, systemImage: badge.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.horizontal, 10)
                            .frame(height: 26)
                            .background(Capsule().fill(AppTheme.popoverSurface))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private var badges: [(title: String, icon: String)] {
        var items: [(String, String)] = []
        if expense.isRecurrent { items.append(("Recurrente", "repeat")) }
        if expense.foreignTax != nil { items.append(("Exterior", "globe")) }
        if isFromEmail { items.append(("Correo", "envelope")) }
        return items
    }

    // MARK: - Datos

    private var details: some View {
        FormGroupedRows {
            FormLabeledRow(label: "Categoría") {
                HStack(spacing: 8) {
                    Circle().fill(expense.categoria.color).frame(width: 8, height: 8)
                    Text(expense.categoria.nombre)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
            }
            FormLabeledRow(label: "Pago") {
                Label(expense.metodoPago.shortLabel, systemImage: expense.metodoPago.icono)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }
            FormLabeledRow(label: "Fecha", showsDivider: false) {
                Text(dateText)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func foreignTaxSection(_ tax: ForeignTax) -> some View {
        let lines = taxLines(tax)
        return VStack(alignment: .leading, spacing: 10) {
            FormSectionTitle(title: "Compra en el exterior")
            FormGroupedRows {
                amountRow("Base", tax.base)
                ForEach(lines, id: \.title) { line in
                    amountRow(line.title, line.amount)
                }
                amountRow("Total", tax.total, isTotal: true)
            }
        }
    }

    private func taxLines(_ tax: ForeignTax) -> [(title: String, amount: Double)] {
        let rates: [(id: String, title: String, rate: Double)] = [
            ("isd", "ISD 5 %", 5),
            ("iva_digital", "IVA digital 15 %", 15),
            ("custom", "Otro \((tax.customPercentage ?? 0).formatted()) %", tax.customPercentage ?? 0)
        ]
        return rates
            .filter { tax.selected.contains($0.id) }
            .map { ($0.title, ForeignTax.cents(tax.base * $0.rate / 100)) }
    }

    private func amountRow(_ title: String, _ amount: Double, isTotal: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(isTotal ? .semibold : .regular))
                .foregroundStyle(isTotal ? AppTheme.primaryText : AppTheme.tertiaryText)
            Spacer()
            Text(amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.system(size: 16, weight: isTotal ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 48)
        .overlay(alignment: .top) {
            if title != "Base" { Rectangle().fill(AppTheme.separator).frame(height: 1) }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            FormSectionTitle(title: "Etiquetas")
            ChipFlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(AppTheme.popoverSurface))
                }
            }
        }
    }

    /// Cuánto lleva la categoría en el mes y qué parte es este gasto.
    @ViewBuilder
    private var monthContext: some View {
        let month = categoryMonth
        if month.total > 0 {
            let share = min(expense.monto / month.total, 1)
            VStack(alignment: .leading, spacing: 12) {
                FormSectionTitle(
                    title: "\(expense.categoria.nombre) en \(Self.monthFormatter.string(from: expense.fecha))",
                    trailing: month.count == 1 ? "1 gasto" : "\(month.count) gastos"
                )
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(month.total, format: .currency(code: "USD").precision(.fractionLength(2)))
                            .font(.system(size: 22, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Text("Este gasto es el \(share.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.track)
                            Capsule()
                                .fill(expense.categoria.color)
                                .frame(width: max(6, proxy.size.width * share))
                        }
                    }
                    .frame(height: 6)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
                )
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Acciones

    private var actions: some View {
        HStack(spacing: 10) {
            Button {
                showsDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.negative)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(AppTheme.negative.opacity(0.14)))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Eliminar gasto")

            Button(action: onEdit) {
                Label("Editar gasto", systemImage: "pencil")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.backgroundTop)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(AppTheme.primaryText))
            }
            .buttonStyle(.pressable(scale: 0.98))
        }
    }
}
