import SwiftUI

struct BudgetCategoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseStore.self) private var session
    @Environment(BudgetDetailStore.self) private var detailStore
    @State private var movementContext: BudgetCategoryMovementContext?
    @State private var showingDeleteCategoryAlert = false

    let budget: BudgetMonthly
    let category: BudgetCategoryDetail
    let expenses: [Expense]

    private var currentCategory: BudgetCategoryDetail {
        detailStore.categories.first(where: { $0.id == category.id }) ?? category
    }

    private var metrics: BudgetCategoryMetrics {
        currentCategory.metrics(expenses: expenses, year: budget.anio, month: budget.mes)
    }

    private var movements: [BudgetMovement] {
        currentCategory.movimientos.sorted { $0.parsedDate > $1.parsedDate }
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    summaryCard
                    budgetedSection
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
            }
        }
        .navigationBarBackButtonHidden(true)
        .swipeBackBehavior()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: dismiss.callAsFunction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .accessibilityLabel("Volver")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingDeleteCategoryAlert = true
                } label: {
                    Image(systemName: isDeletingCategory ? "hourglass" : "trash")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.negative.opacity(0.88))
                }
                .disabled(isDeletingCategory)
                .accessibilityLabel("Eliminar categoría")

                Button {
                    movementContext = .init(category: currentCategory, movement: nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.primaryText)
                }
                .accessibilityLabel("Agregar gasto")
            }
        }
        .sheet(item: $movementContext) { context in
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
        .alert("Eliminar categoría", isPresented: $showingDeleteCategoryAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Eliminar", role: .destructive, action: deleteCategory)
        } message: {
            Text("Si borras \(currentCategory.displayCategory.nombre), también se eliminarán todos los gastos presupuestados agregados dentro de esa categoría. Esta acción no se puede deshacer.")
        }
    }

    private var header: some View {
        AppScreenHeader(eyebrow: "Categoría", title: currentCategory.displayCategory.nombre)
    }

    private var summaryCard: some View {
        BudgetCategoryDetailSummaryCard(
            category: currentCategory,
            metrics: metrics,
            monthTitle: budget.monthTitle,
            onAddMovement: addMovement
        )
    }

    private var budgetedSection: some View {
        BudgetedMovementsSection(
            category: currentCategory.displayCategory,
            movements: movements,
            paymentMethods: session.metodosPago,
            onSelect: editMovement,
            onDelete: deleteMovement
        )
    }

    private func addMovement() {
        movementContext = .init(category: currentCategory, movement: nil)
    }

    private func editMovement(_ movement: BudgetMovement) {
        movementContext = .init(category: currentCategory, movement: movement)
    }

    private func deleteMovement(_ movement: BudgetMovement) {
        Task {
            _ = await detailStore.deleteMovement(using: session, budgetID: budget.id, movementID: movement.id)
        }
    }

    private var isDeletingCategory: Bool {
        detailStore.deletingCategoryIDs.contains(currentCategory.id)
    }

    private func deleteCategory() {
        Task {
            let ok = await detailStore.deleteCategory(using: session, budgetID: budget.id, budgetCategoryID: currentCategory.id)
            guard ok else { return }
            dismiss()
        }
    }

    private var background: some View {
        AppTheme.screenBackground
    }
}

private struct BudgetCategoryMovementContext: Identifiable {
    let category: BudgetCategoryDetail
    let movement: BudgetMovement?

    var id: String {
        "\(category.id)-\(movement?.id ?? -1)"
    }
}

#Preview {
    BudgetCategoryDetailView(
        budget: BudgetMonthly(id: 1, anio: 2026, mes: 4, total: 600, gastosRegistrados: 8, tendencia: "stable", estado: "En progreso", userId: nil),
        category: BudgetCategoryDetail(
            id: 1,
            categoriaId: 1,
            totalCategoria: 0,
            cantidadGastos: 0,
            categoria: BudgetCategoryInfo(nombre: "Alimentación"),
            movimientos: [
                BudgetMovement(id: 1, presupuestoCategoriaId: 1, descripcion: "Almuerzo 2x2", monto: 18.5, fecha: "2026-04-13", metodoPagoId: 1),
                BudgetMovement(id: 2, presupuestoCategoriaId: 1, descripcion: "Mercado semanal", monto: 128.4, fecha: "2026-04-15", metodoPagoId: 2)
            ]
        ),
        expenses: []
    )
    .environment(ExpenseStore())
    .environment(BudgetDetailStore())
}
