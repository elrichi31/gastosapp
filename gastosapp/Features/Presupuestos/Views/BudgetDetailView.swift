import SwiftUI

/// Plan de un mes, según el canvas «Plan · Octubre»: estado del mes y una
/// lista de categorías que se despliegan para ver y editar lo presupuestado.
struct BudgetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseStore.self) private var session
    @State private var detailStore = BudgetDetailStore()
    @State private var presentedSheet: BudgetDetailSheet?
    @State private var movementToDelete: BudgetMovement?
    @State private var categoryToDelete: BudgetCategoryDetail?
    @State private var expandedCategoryIDs: Set<Int> = []

    let budget: BudgetMonthly

    private var spendingSnapshot: BudgetMonthSpendingSnapshot {
        BudgetMonthSpendingSnapshot(
            budget: budget,
            categories: detailStore.categories,
            expenses: session.gastos
        )
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    statusCard(spendingSnapshot.monthlyMetrics)
                    content
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
            }
            .refreshable {
                await session.loadExpensesIfNeeded()
                await detailStore.loadDetail(using: session, budgetID: budget.id)
                await checkBudgetNotification()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .swipeBackBehavior()
        .environment(detailStore)
        .task {
            await session.loadCatalogsIfNeeded()
            await session.loadExpensesIfNeeded()
            await detailStore.loadDetail(using: session, budgetID: budget.id)
            await checkBudgetNotification()
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addCategory:
                BudgetCategoryPickerSheet(
                    budgetID: budget.id,
                    existingCategoryIDs: Set(detailStore.categories.map(\.categoriaId)),
                    onCreated: openMovementEditor
                )
                .environment(session)
                .environment(detailStore)
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.visible)
            case let .movement(context):
                BudgetMovementEditorSheet(
                    budgetID: budget.id,
                    category: context.category,
                    movement: context.movement,
                    onSaved: {}
                )
                .environment(session)
                .environment(detailStore)
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .alert("¿Eliminar gasto?", isPresented: deleteAlertBinding) {
            Button("Cancelar", role: .cancel) { movementToDelete = nil }
            Button("Eliminar", role: .destructive, action: deleteSelectedMovement)
        } message: {
            Text("Se eliminará «\(movementToDelete?.descripcion ?? "")» del presupuesto. Esta acción no se puede deshacer.")
        }
        .alert("Quitar categoría", isPresented: deleteCategoryAlertBinding) {
            Button("Cancelar", role: .cancel) { categoryToDelete = nil }
            Button("Quitar", role: .destructive, action: deleteSelectedCategory)
        } message: {
            Text("«\(categoryToDelete?.displayCategory.nombre ?? "")» dejará de estar en el plan de este mes.")
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.popoverSurface))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Volver a Plan")

            VStack(alignment: .leading, spacing: 1) {
                Text("Plan")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(budget.monthYearTitle)
                    .font(.system(size: 26, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    // MARK: - Estado del mes

    private struct Indicator {
        let label: String
        let tint: Color
    }

    private func indicator(budgeted: Double, spent: Double) -> Indicator {
        guard budgeted > 0 else { return Indicator(label: "Sin presupuesto", tint: AppTheme.tertiaryText) }
        if spent > budgeted { return Indicator(label: "Límite excedido", tint: AppTheme.negative) }
        if spent == budgeted { return Indicator(label: "Al límite", tint: AppTheme.warning) }
        if spent / budgeted >= 0.8 { return Indicator(label: "Cerca del límite", tint: AppTheme.warning) }
        return Indicator(label: "Dentro del límite", tint: AppTheme.positive)
    }

    /// Días que quedan del mes, contando hoy; el mes entero si aún no empezó.
    private var daysAhead: Int? {
        let cal = Calendar.current
        guard
            let monthStart = cal.date(from: DateComponents(year: budget.anio, month: budget.mes, day: 1)),
            let monthEnd = cal.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
        else { return nil }
        let start = max(cal.startOfDay(for: Date()), monthStart)
        guard start <= monthEnd else { return nil }
        return (cal.dateComponents([.day], from: start, to: monthEnd).day ?? 0) + 1
    }

    private func statusCard(_ metrics: BudgetMonthlyMetrics) -> some View {
        let state = indicator(budgeted: metrics.budgeted, spent: metrics.spent)
        let isOver = metrics.spent > metrics.budgeted && metrics.budgeted > 0
        let percent = Int(metrics.progressPercentage.rounded())

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Estado del mes")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    Circle().fill(state.tint).frame(width: 6, height: 6)
                    Text(state.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(state.tint.opacity(0.13)))
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(money(isOver ? metrics.spent - metrics.budgeted : metrics.remaining))
                        .font(.system(size: 36, weight: .semibold))
                        .tracking(-1.1)
                        .monospacedDigit()
                        .foregroundStyle(isOver ? AppTheme.negative : AppTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(isOver ? "por encima del plan" : "disponible")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 8)
                if let daysAhead, !isOver, metrics.budgeted > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        (Text(money(metrics.remaining / Double(daysAhead)))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                         + Text(" /día").font(.footnote).foregroundStyle(AppTheme.secondaryText))
                            .monospacedDigit()
                        Text("para seguir en plan")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            VStack(spacing: 8) {
                progressBar(fraction: metrics.progressPercentage / 100, tint: state.tint, height: 8)
                HStack {
                    (Text(money(metrics.spent)).fontWeight(.semibold).foregroundColor(AppTheme.primaryText)
                     + Text(" de \(money(metrics.budgeted))"))
                    Spacer()
                    Text("\(percent)%")
                }
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Consumo del presupuesto: \(percent)%")
        }
        .padding(18)
        .background(groupedBackground(cornerRadius: 20))
    }

    // MARK: - Categorías

    @ViewBuilder
    private var content: some View {
        if detailStore.isLoading && detailStore.categories.isEmpty {
            ProgressView()
                .tint(AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if detailStore.categories.isEmpty {
            emptyCategories
        } else {
            VStack(spacing: 0) {
                ForEach(detailStore.categories) { category in
                    categoryRow(category)
                    AppHairline()
                }
                Button {
                    presentedSheet = .addCategory
                } label: {
                    Label("Agregar categoría", systemImage: "plus")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.horizontal, 16)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .background(groupedBackground(cornerRadius: 16))
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }

    private func categoryRow(_ category: BudgetCategoryDetail) -> some View {
        let metrics = spendingSnapshot.metricsByCategoryID[category.id]
            ?? BudgetCategoryMetrics(budgeted: category.budgetedAmount, spent: 0)
        let color = category.displayCategory.color
        let isOpen = expandedCategoryIDs.contains(category.id)
        let hasBudget = metrics.budgeted > 0
        let state = indicator(budgeted: metrics.budgeted, spent: metrics.spent)
        let canRemove = category.movimientos.isEmpty && metrics.spent == 0
        let name = category.displayCategory.nombre

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        if isOpen { expandedCategoryIDs.remove(category.id) } else { expandedCategoryIDs.insert(category.id) }
                    }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .rotationEffect(.degrees(isOpen ? 90 : 0))
                            .frame(width: 16, height: 24)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(name)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(color)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(color.opacity(0.16)))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                (Text(money(metrics.spent))
                                    .fontWeight(.semibold)
                                    .foregroundColor(metrics.spent > metrics.budgeted && hasBudget ? AppTheme.negative : AppTheme.primaryText)
                                 + Text(hasBudget ? " / \(money(metrics.budgeted))" : "").foregroundColor(AppTheme.tertiaryText))
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            if hasBudget {
                                HStack(spacing: 10) {
                                    progressBar(fraction: metrics.progressPercentage / 100, tint: state.tint, height: 8)
                                    Text("\(Int(metrics.progressPercentage.rounded()))%")
                                        .font(.caption)
                                        .monospacedDigit()
                                        .foregroundStyle(metrics.progressPercentage >= 80 ? state.tint : AppTheme.secondaryText)
                                        .frame(minWidth: 32, alignment: .trailing)
                                }
                            } else {
                                Text("\(category.movimientos.count == 1 ? "1 gasto" : "\(category.movimientos.count) gastos") · sin monto presupuestado")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                        }
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, canRemove ? 4 : 16)
                    .padding(.vertical, 14)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityValue(isOpen ? "Desplegada" : "Plegada")
                .accessibilityHint("Muestra lo presupuestado en \(name)")

                if canRemove {
                    Button {
                        categoryToDelete = category
                    } label: {
                        Image(systemName: detailStore.deletingCategoryIDs.contains(category.id) ? "hourglass" : "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(detailStore.deletingCategoryIDs.contains(category.id))
                    .padding(.trailing, 6)
                    .accessibilityLabel("Quitar categoría \(name)")
                }
            }

            if isOpen {
                movementsList(category)
                    .transition(.opacity)
            }
        }
    }

    private func movementsList(_ category: BudgetCategoryDetail) -> some View {
        VStack(spacing: 0) {
            ForEach(category.movimientos.sorted { $0.parsedDate > $1.parsedDate }) { movement in
                HStack(spacing: 4) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(movement.descripcion)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        if let tags = movement.tags, !tags.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(tags.prefix(4), id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(AppTheme.secondaryText)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(AppTheme.popoverSurface))
                                }
                            }
                        }
                        Text(movement.parsedDate.formatted(.dateTime.day().month(.abbreviated).year().locale(Locale(identifier: "es"))))
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(money(movement.monto))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.trailing, 2)
                    iconButton("pencil", label: "Editar \(movement.descripcion)") {
                        presentedSheet = .movement(.init(category: category, movement: movement))
                    }
                    iconButton(
                        detailStore.deletingMovementIDs.contains(movement.id) ? "hourglass" : "trash",
                        label: "Eliminar \(movement.descripcion)"
                    ) {
                        movementToDelete = movement
                    }
                    .disabled(detailStore.deletingMovementIDs.contains(movement.id))
                }
                .padding(.leading, 42)
                .padding(.trailing, 6)
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(AppTheme.primaryText.opacity(0.05)).frame(height: 1)
                }
            }

            Button {
                openMovementEditor(for: category)
            } label: {
                Label("Agregar gasto", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.leading, 42)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .background(AppTheme.primaryText.opacity(0.025))
        .overlay(alignment: .top) { AppHairline() }
    }

    private var emptyCategories: some View {
        VStack(spacing: 10) {
            Text("Este mes aún no tiene categorías")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Agrega categorías una por una o copia la estructura del mes anterior.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: 270)
            VStack(spacing: 8) {
                Button {
                    presentedSheet = .addCategory
                } label: {
                    Text("Agregar categoría")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.backgroundTop)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(AppTheme.primaryText))
                }
                Button(action: copyPreviousBudget) {
                    Text(detailStore.isCopyingPreviousBudget ? "Copiando…" : "Copiar mes anterior")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Capsule().fill(AppTheme.popoverSurface))
                }
                .disabled(detailStore.isCopyingPreviousBudget)
            }
            .buttonStyle(.pressable(scale: 0.97))
            .padding(.top, 6)

            if let saveError = detailStore.saveErrorMessage {
                Text(saveError)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.negative)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.strongBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }

    // MARK: - Piezas

    private func groupedBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.separator, lineWidth: 1)
            )
    }

    private func progressBar(fraction: Double, tint: Color, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.track)
                Capsule()
                    .fill(tint)
                    .frame(width: fraction > 0 ? max(proxy.size.width * min(fraction, 1), height) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func iconButton(_ systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    // MARK: - Acciones

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { movementToDelete != nil }, set: { if !$0 { movementToDelete = nil } })
    }

    private var deleteCategoryAlertBinding: Binding<Bool> {
        Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } })
    }

    private func deleteSelectedMovement() {
        guard let movement = movementToDelete else { return }
        movementToDelete = nil
        Task { _ = await detailStore.deleteMovement(using: session, budgetID: budget.id, movementID: movement.id) }
    }

    private func deleteSelectedCategory() {
        guard let category = categoryToDelete else { return }
        categoryToDelete = nil
        Task { _ = await detailStore.deleteCategory(using: session, budgetID: budget.id, budgetCategoryID: category.id) }
    }

    private func copyPreviousBudget() {
        Task { _ = await detailStore.copyPreviousBudget(using: session, budgetID: budget.id) }
    }

    private func openMovementEditor(for category: BudgetCategoryDetail) {
        expandedCategoryIDs.insert(category.id)
        presentedSheet = .movement(.init(category: category, movement: nil))
    }

    private func checkBudgetNotification() async {
        await LocalNotificationManager.sendBudgetAlertIfNeeded(
            budget: budget,
            categories: detailStore.categories,
            expenses: session.gastos
        )
    }
}

private enum BudgetDetailSheet: Identifiable {
    case addCategory
    case movement(MovementEditorContext)

    var id: String {
        switch self {
        case .addCategory:
            return "add-category"
        case let .movement(context):
            return "movement-\(context.id)"
        }
    }
}

private struct MovementEditorContext: Hashable {
    let category: BudgetCategoryDetail
    let movement: BudgetMovement?

    var id: String {
        "\(category.id)-\(movement?.id ?? -1)"
    }
}

#Preview {
    BudgetDetailView(budget: BudgetMonthly(id: 1, anio: 2026, mes: 4, total: 600, gastosRegistrados: 8, tendencia: "stable", estado: "En progreso", userId: nil))
        .environment(ExpenseStore())
}
