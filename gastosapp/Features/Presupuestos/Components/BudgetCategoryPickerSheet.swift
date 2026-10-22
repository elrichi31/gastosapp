import SwiftUI

struct BudgetCategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseStore.self) private var session
    @Environment(BudgetDetailStore.self) private var detailStore

    let budgetID: Int
    let existingCategoryIDs: Set<Int>
    let onCreated: (BudgetCategoryDetail) -> Void

    @State private var selectedCategoryID: Int?

    private var availableCategories: [Categoria] {
        session.categorias
            .filter { !existingCategoryIDs.contains($0.id) }
            .sorted { $0.nombre < $1.nombre }
    }

    private var selectedCategory: Categoria? {
        guard let selectedCategoryID else { return availableCategories.first }
        return availableCategories.first { $0.id == selectedCategoryID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroCard
            ScrollView { content }
            errors
            createButton
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .task {
            await session.loadCatalogs(force: true)
            selectedCategoryID = selectedCategoryID ?? availableCategories.first?.id
        }
        .onChange(of: availableCategories.map(\.id), initial: false) { _, ids in
            guard let selectedCategoryID, ids.contains(selectedCategoryID) else {
                self.selectedCategoryID = ids.first
                return
            }
        }
    }

    private var heroCard: some View {
        BudgetEditorHeader(
            title: "Nueva categoría",
            subtitle: selectedCategory?.nombre ?? "Elige una categoría",
            icon: selectedCategory?.icono ?? "circle.grid.2x2.fill",
            tint: AppTheme.accent,
            onClose: dismiss.callAsFunction
        )
    }

    @ViewBuilder
    private var content: some View {
        if session.isLoadingCatalogs && availableCategories.isEmpty {
            infoCard(icon: "hourglass", title: "Cargando categorías", message: "Estoy consultando las categorías disponibles.")
        } else if availableCategories.isEmpty {
            infoCard(icon: "checkmark.circle.fill", title: "Todo listo", message: "Este mes ya tiene todas las categorías disponibles.")
        } else {
            VStack(spacing: 10) {
                ForEach(availableCategories) { category in
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: Categoria) -> some View {
        Button {
            selectedCategoryID = category.id
        } label: {
            HStack(spacing: 14) {
                CategoryGlyph(categoria: category, size: 42)

                Text(category.nombre)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Spacer()

                Image(systemName: selectedCategoryID == category.id ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(selectedCategoryID == category.id ? AppTheme.accent : AppTheme.placeholderText)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selectedCategoryID == category.id ? AppTheme.insetSurface : AppTheme.controlSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(selectedCategoryID == category.id ? AppTheme.accent.opacity(0.38) : AppTheme.controlSurface, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func infoCard(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }

    @ViewBuilder
    private var errors: some View {
        if let error = session.catalogErrorMessage {
            BudgetEditorErrorCard(message: error)
        }
        if let error = detailStore.saveErrorMessage {
            BudgetEditorErrorCard(message: error)
        }
    }

    private var createButton: some View {
        BudgetEditorSaveButton(isSaving: detailStore.isSaving, isEnabled: canCreate, action: createCategory)
    }

    private var canCreate: Bool {
        selectedCategory != nil && !detailStore.isSaving
    }

    private var background: some View {
        AppTheme.screenBackground
    }

    private func createCategory() {
        guard let selectedCategory else { return }
        Task {
            let ok = await detailStore.createCategory(using: session, budgetID: budgetID, categoryID: selectedCategory.id)
            guard ok, let createdCategory = detailStore.categories.first(where: { $0.categoriaId == selectedCategory.id }) else { return }
            onCreated(createdCategory)
        }
    }
}
