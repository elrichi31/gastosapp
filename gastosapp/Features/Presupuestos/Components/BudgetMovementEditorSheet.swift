import SwiftUI

struct BudgetMovementEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ExpenseStore.self) private var session
    @Environment(BudgetDetailStore.self) private var detailStore
    @FocusState private var focusedField: Field?

    let budgetID: Int
    let category: BudgetCategoryDetail
    let movement: BudgetMovement?
    let onSaved: () -> Void

    @State private var tagsText = ""
    @State private var description = ""
    @State private var amount = ""
    @State private var date = Date()
    @State private var paymentMethodID = 0

    private enum Field: Hashable { case description, amount }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            BudgetEditorHeader(
                title: movement == nil ? "Nuevo gasto" : "Editar gasto",
                subtitle: category.displayCategory.nombre,
                icon: category.displayCategory.icono,
                tint: AppTheme.accent,
                onClose: dismiss.callAsFunction
            )
            fields
            ExpenseExtrasFields(tagsText: $tagsText)
            if let error = detailStore.saveErrorMessage {
                BudgetEditorErrorCard(message: error)
            }
            BudgetEditorSaveButton(isSaving: detailStore.isSaving, isEnabled: canSave, action: save)
        }
        .padding(.horizontal, 22)
        .padding(.top, 32)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        }
        .onAppear(perform: seedInitialValues)
    }

    private var fields: some View {
        VStack(spacing: 10) {
            BudgetEditorTextField(title: "Descripción", placeholder: "Ej. Supermercado", text: $description)
                .focused($focusedField, equals: .description)

            BudgetEditorTextField(title: "Monto", placeholder: "0.00", text: $amount, keyboard: .decimalPad)
                .focused($focusedField, equals: .amount)

            BudgetEditorDateField(date: $date)
            paymentMethodField
        }
    }

    private var paymentMethodField: some View {
        BudgetEditorMenuField(title: "Método", value: selectedPaymentMethodName) {
            ForEach(session.metodosPago) { method in
                Button(method.nombre) {
                    paymentMethodID = method.id
                }
            }
        }
    }

    private var canSave: Bool {
        ExpenseTags.isValid(ExpenseTags.normalize(tagsText)) && !cleanDescription.isEmpty && parsedAmount > 0 && paymentMethodID != 0 && !detailStore.isSaving
    }

    private var cleanDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Double {
        MoneyInput.parse(amount) ?? 0
    }

    private var selectedPaymentMethodName: String {
        session.metodosPago.first(where: { $0.id == paymentMethodID })?.shortLabel ?? "Elegir"
    }

    private func seedInitialValues() {
        guard description.isEmpty, amount.isEmpty else { return }
        if let movement {
            seedEditingValues(movement)
        } else {
            paymentMethodID = session.metodosPago.first?.id ?? 0
        }
    }

    private func seedEditingValues(_ movement: BudgetMovement) {
        tagsText = (movement.tags ?? []).joined(separator: ", ")
        description = movement.descripcion
        amount = MoneyInput.format(movement.monto)
        date = movement.parsedDate
        paymentMethodID = movement.metodoPagoId ?? session.metodosPago.first?.id ?? 0
    }

    private func save() {
        Task {
            let ok = await persistMovement()
            guard ok else { return }
            onSaved()
            dismiss()
        }
    }

    private func persistMovement() async -> Bool {
        if let movement {
            return await detailStore.updateMovement(
                using: session,
                budgetID: budgetID,
                movementID: movement.id,
                description: cleanDescription,
                amount: parsedAmount,
                date: date,
                paymentMethodID: paymentMethodID,
                tags: ExpenseTags.normalize(tagsText)
            )
        }
        return await detailStore.createMovement(
            using: session,
            budgetID: budgetID,
            categoryID: category.id,
            description: cleanDescription,
            amount: parsedAmount,
            date: date,
            paymentMethodID: paymentMethodID,
                tags: ExpenseTags.normalize(tagsText)
        )
    }
}
