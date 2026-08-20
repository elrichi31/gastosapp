import SwiftUI

struct BudgetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseStore.self) private var session
    @State private var detailStore = BudgetDetailStore()
    @State private var presentedSheet: BudgetDetailSheet?
    @State private var movementToDelete: BudgetMovement?

    let budget: BudgetMonthly
    private let categoryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    private var spendingSnapshot: BudgetMonthSpendingSnapshot {
        BudgetMonthSpendingSnapshot(
            budget: budget,
            categories: detailStore.categories,
            expenses: session.gastos
        )
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            detailScroll
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.78))
                }
                .accessibilityLabel("Volver")
            }
        }
        .navigationBarBackButtonHidden(true)
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
        .alert("Eliminar movimiento", isPresented: deleteAlertBinding) {
            Button("Cancelar", role: .cancel) { movementToDelete = nil }
            Button("Eliminar", role: .destructive, action: deleteSelectedMovement)
        } message: {
            Text("Este movimiento se eliminará del presupuesto.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if detailStore.isLoading && detailStore.categories.isEmpty {
            messageCard(icon: "hourglass", tint: AppTheme.accent, title: "Cargando categorías", message: "Estamos armando tu presupuesto del mes.")
        } else if detailStore.categories.isEmpty {
            messageCard(icon: "tray", tint: AppTheme.accent, title: "No hay categorías todavía", message: "Cuando tengas categorías o movimientos aparecerán aquí.")
            copyPreviousBudgetButton
            if let saveError = detailStore.saveErrorMessage {
                messageCard(icon: "exclamationmark.triangle.fill", tint: AppTheme.warning, title: "No pudimos copiar", message: saveError)
            }
        } else {
            categoriesHeader

            LazyVGrid(columns: categoryColumns, spacing: 12) {
                ForEach(detailStore.categories) { category in
                    NavigationLink {
                        BudgetCategoryDetailView(
                            budget: budget,
                            category: category,
                            expenses: session.gastos
                        )
                        .environment(detailStore)
                        .floatingTabBarInset()
                    } label: {
                        BudgetCategorySummaryCard(
                            category: category,
                            metrics: spendingSnapshot.metricsByCategoryID[category.id]
                                ?? BudgetCategoryMetrics(budgeted: category.budgetedAmount, spent: 0),
                            position: .single
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var detailScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                screenHeader
                BudgetSummaryHero(budget: budget, snapshot: spendingSnapshot)
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 36)
        }
        .refreshable {
            await session.loadExpensesIfNeeded()
            await detailStore.loadDetail(using: session, budgetID: budget.id)
            await checkBudgetNotification()
        }
    }

    private var screenHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Presupuesto")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(2)
                    .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                Text(budget.monthYearTitle)
                    .font(.system(.title2, design: .default, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer()

            Button {
                presentedSheet = .addCategory
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Agregar categoría")
        }
    }

    private var categoriesHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Categorías")
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Text("Detalle ↓")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.42))
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { movementToDelete != nil }, set: { if !$0 { movementToDelete = nil } })
    }

    private var background: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func deleteSelectedMovement() {
        guard let movement = movementToDelete else { return }
        movementToDelete = nil
        Task { _ = await detailStore.deleteMovement(using: session, budgetID: budget.id, movementID: movement.id) }
    }

    private func copyPreviousBudget() {
        Task { _ = await detailStore.copyPreviousBudget(using: session, budgetID: budget.id) }
    }

    private func openMovementEditor(for category: BudgetCategoryDetail) {
        presentedSheet = .movement(.init(category: category, movement: nil))
    }

    private func checkBudgetNotification() async {
        await LocalNotificationManager.sendBudgetAlertIfNeeded(
            budget: budget,
            categories: detailStore.categories,
            expenses: session.gastos
        )
    }

    private func messageCard(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primaryText)
                Text(message).font(.caption).foregroundStyle(AppTheme.primaryText.opacity(0.58))
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }

    private var copyPreviousBudgetButton: some View {
        Button(action: copyPreviousBudget) {
            HStack(spacing: 12) {
                Image(systemName: detailStore.isCopyingPreviousBudget ? "hourglass" : "doc.on.doc.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(detailStore.isCopyingPreviousBudget ? "Copiando..." : "Copiar mes anterior")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Trae categorías y movimientos presupuestados del mes previo.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.42))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.accent.opacity(0.18), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .disabled(detailStore.isCopyingPreviousBudget)
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
