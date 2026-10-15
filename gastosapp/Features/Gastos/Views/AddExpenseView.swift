import SwiftUI

struct AddExpenseView: View {
    private enum FocusField: Hashable {
        case descripcion
    }

    let editingExpense: Expense?
    var onSaved: () -> Void = {}

    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetStore.self) private var budgetStore
    @State private var budgetDetail = BudgetDetailStore()
    @FocusState private var amountFocused: Bool
    @State private var tagsText = ""
    @State private var foreignEnabled = false
    @State private var taxSelection = ["isd"]
    @State private var customRate = ""
    private var foreignTax: ForeignTax? {
        foreignEnabled ? ForeignTax(base: ForeignTax.cents(montoNumerico), selected: taxSelection, customRate: customRate) : nil
    }
    private var expenseTags: [String] {
        var tags = ExpenseTags.normalize(tagsText)
        if foreignEnabled && !tags.contains("exterior") { tags.append("exterior") }
        return tags
    }
    @State private var descripcion: String = ""
    @State private var monto: String = ""
    @State private var fecha: Date = Date()
    @State private var categoriaId: Int = 0
    @State private var metodoPagoId: Int = 0
    @State private var hasAppliedInitialValues = false
    @State private var userPickedCategory = false
    @State private var userPickedPaymentMethod = false
    @State private var activeSuggestion: ExpenseSmartSuggestion?
    @FocusState private var focusedField: FocusField?

    init(editingExpense: Expense? = nil, onSaved: @escaping () -> Void = {}) {
        self.editingExpense = editingExpense
        self.onSaved = onSaved
    }

    private var montoNumerico: Double {
        MoneyInput.parse(monto) ?? 0
    }

    private var categoriaSeleccionada: Categoria? {
        store.categorias.first(where: { $0.id == categoriaId })
    }

    private var metodoPagoSeleccionado: ExpensePaymentMethod? {
        store.metodosPago.first(where: { $0.id == metodoPagoId })
    }

    private var puedeGuardar: Bool {
        montoNumerico > 0 && ExpenseTags.isValid(expenseTags) && (foreignTax?.isValid ?? true) &&
        categoriaSeleccionada != nil &&
        metodoPagoSeleccionado != nil &&
        canPersistExpense &&
        !store.isSavingExpense
    }

    private var isEditing: Bool {
        editingExpense != nil
    }

    private var canPersistExpense: Bool {
        if let editingExpense, editingExpense.id < 0 {
            return true
        }
        return store.canAccessProtectedEndpoints
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                estadoCard
                FormAmountEntry(
                    label: foreignEnabled ? "Precio sin impuestos" : "Monto",
                    text: $monto,
                    hint: budgetHint,
                    focus: $amountFocused
                )
                FormGroupedRows {
                    FormLabeledRow(label: "Descripción") {
                        TextField("", text: $descripcion, prompt: Text("¿En qué gastaste?").foregroundStyle(AppTheme.placeholderText))
                            .focused($focusedField, equals: .descripcion)
                            .textInputAutocapitalization(.sentences)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .tint(AppTheme.accent)
                    }
                    FormLabeledRow(label: "Fecha", showsDivider: false) {
                        DatePicker("Fecha", selection: $fecha, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                    }
                }
                suggestionCard
                VStack(alignment: .leading, spacing: 10) {
                    FormSectionTitle(title: "Categoría")
                    CategoryChipPicker(categories: store.categorias, selectedID: $categoriaId) { _ in
                        userPickedCategory = true
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    FormSectionTitle(title: "Método de pago")
                    PaymentMethodPicker(methods: store.metodosPago, selectedID: $metodoPagoId) { _ in
                        userPickedPaymentMethod = true
                    }
                }
                ForeignTaxFields(enabled: $foreignEnabled, selected: $taxSelection, customRate: $customRate, base: montoNumerico, legacyTotal: editingExpense?.tags?.contains("exterior") == true && editingExpense?.foreignTax == nil)
                ExpenseExtrasFields(tagsText: $tagsText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, AppScreenMetrics.contentBottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FormStickySaveBar {
                ExpensePrimarySaveButton(
                    isSaving: store.isSavingExpense,
                    isEnabled: puedeGuardar,
                    title: "\(isEditing ? "Guardar cambios" : "Guardar gasto") · \(totalLabel)",
                    disabledHint: disabledHint
                ) {
                    Task { await guardar() }
                }
            }
        }
        .task {
            await store.loadCatalogsIfNeeded()
            aplicarSeleccionInicial()
            await loadBudgetDetail()
        }
        .onAppear {
            aplicarSeleccionInicial()
        }
        .onChange(of: store.categorias.count) { _, _ in
            aplicarSeleccionInicial()
        }
        .onChange(of: store.metodosPago.count) { _, _ in
            aplicarSeleccionInicial()
        }
        .onChange(of: descripcion) { _, _ in
            applySmartSuggestionIfNeeded()
        }
        .onChange(of: budgetStore.budgets) {
            Task { await loadBudgetDetail() }
        }
    }

    private var registeredTotal: Double {
        foreignTax?.total ?? montoNumerico
    }

    private var totalLabel: String {
        money(registeredTotal)
    }

    private var disabledHint: String? {
        if montoNumerico <= 0 { return "Ingresa un monto" }
        if !canPersistExpense { return "Inicia sesión para guardar" }
        if !ExpenseTags.isValid(expenseTags) { return "Revisa las etiquetas" }
        if foreignTax?.isValid == false { return "Revisa los impuestos" }
        return nil
    }

    /// Cómo quedaría la categoría elegida en el presupuesto del mes con este gasto.
    private var budgetHint: (text: String, color: Color)? {
        guard montoNumerico > 0 else {
            return ("Ingresa un monto para ver el efecto en tu presupuesto", AppTheme.placeholderText)
        }
        guard
            let category = categoriaSeleccionada,
            let line = budgetDetail.categories.first(where: { $0.categoriaId == category.id }),
            line.budgetedAmount > 0
        else { return nil }

        let cal = Calendar.current
        let spent = store.gastos
            .filter {
                $0.categoriaId == category.id && $0.id != editingExpense?.id
                    && cal.isDate($0.fecha, equalTo: fecha, toGranularity: .month)
            }
            .reduce(0) { $0 + $1.monto }
        let after = spent + registeredTotal
        let limit = line.budgetedAmount
        let amounts = "\(money(after)) / \(money(limit))"
        let ratio = after / limit
        if ratio > 1 { return ("\(category.nombre) pasaría el presupuesto: \(amounts)", AppTheme.negative) }
        if ratio >= 0.8 { return ("\(category.nombre) llegaría al \(Int((ratio * 100).rounded()))%: \(amounts)", AppTheme.warning) }
        return ("\(category.nombre) quedaría en \(amounts)", AppTheme.accent)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private func loadBudgetDetail() async {
        let cal = Calendar.current
        guard let budget = budgetStore.budgets.first(where: {
            $0.anio == cal.component(.year, from: fecha) && $0.mes == cal.component(.month, from: fecha)
        }) else { return }
        await budgetDetail.loadDetail(using: store, budgetID: budget.id)
    }

    @ViewBuilder
    private var estadoCard: some View {
        if let status = estadoActual {
            ExpenseFormStatusCard(status: status)
        }
    }

    @ViewBuilder
    private var suggestionCard: some View {
        if let activeSuggestion, !isEditing {
            HStack(alignment: .top, spacing: 12) {
                ExpenseIconBadge(systemName: "sparkles", color: AppTheme.accent)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Sugerencia inteligente")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(suggestionMessage(activeSuggestion))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.accent.opacity(0.25), lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var estadoActual: ExpenseFormStatus? {
        if let error = store.saveErrorMessage {
            return .init(title: "No se pudo guardar", message: error, icon: "exclamationmark.triangle.fill", tint: AppTheme.warning)
        }
        if !store.hasBaseURLConfigured {
            return .init(title: "Configura el backend", message: "Antes de guardar necesitas la URL base del backend. Usa el botón de conexión arriba.", icon: "slider.horizontal.3", tint: .yellow)
        }
        if !store.canAccessProtectedEndpoints && !canEditLocalDraft {
            let action = isEditing ? "editar tus gastos" : "guardar gastos"
            return .init(title: "Falta la sesión", message: "Inicia sesión para \(action).", icon: "key.fill", tint: AppTheme.secondaryAccent)
        }
        if store.isLoadingCatalogs {
            return .init(title: "Sincronizando catálogos", message: "Estoy cargando categorías y métodos desde el backend.", icon: "arrow.triangle.2.circlepath", tint: AppTheme.accent)
        }
        if let error = store.catalogErrorMessage {
            return .init(title: "Catálogos con fallback", message: error, icon: "tray.full.fill", tint: AppTheme.secondaryAccent)
        }
        return nil
    }

    private func aplicarSeleccionInicial() {
        if let editingExpense, !hasAppliedInitialValues {
            descripcion = editingExpense.descripcion
            monto = MoneyInput.format(editingExpense.foreignTax?.base ?? editingExpense.monto)
            tagsText = (editingExpense.tags ?? []).joined(separator: ", ")
            foreignEnabled = editingExpense.foreignTax != nil
            taxSelection = editingExpense.foreignTax?.selected ?? ["isd"]
            customRate = editingExpense.foreignTax?.customRate ?? ""
            fecha = editingExpense.fecha
            categoriaId = editingExpense.categoriaId
            metodoPagoId = editingExpense.metodoPagoId
            hasAppliedInitialValues = true
            userPickedCategory = true
            userPickedPaymentMethod = true
            return
        }

        if categoriaSeleccionada == nil {
            categoriaId = store.categorias.first?.id ?? 0
        }
        if metodoPagoSeleccionado == nil {
            metodoPagoId = store.metodosPago.first?.id ?? 0
        }
    }

    private var canEditLocalDraft: Bool {
        editingExpense?.id ?? 0 < 0
    }

    private func limpiarFormulario() {
        tagsText = ""
        foreignEnabled = false
        taxSelection = ["isd"]
        customRate = ""
        descripcion = ""
        monto = ""
        fecha = Date()
        categoriaId = store.categorias.first?.id ?? 0
        metodoPagoId = store.metodosPago.first?.id ?? 0
        hasAppliedInitialValues = false
        userPickedCategory = false
        userPickedPaymentMethod = false
        activeSuggestion = nil
    }

    private func guardar() async {
        guard let categoria = categoriaSeleccionada, let metodoPago = metodoPagoSeleccionado else { return }

        let cleanDescription = descripcion.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty { "Gasto" }
        let ok: Bool
        if let editingExpense {
            ok = await store.updateExpense(
                id: editingExpense.id,
                descripcion: cleanDescription,
                monto: foreignTax?.total ?? montoNumerico,
                fecha: fecha,
                categoria: categoria,
                metodoPago: metodoPago,
                isRecurrent: editingExpense.isRecurrent,
                tags: expenseTags,
                foreignTax: foreignTax
            )
        } else {
            ok = await store.createExpense(
                descripcion: cleanDescription,
                monto: foreignTax?.total ?? montoNumerico,
                fecha: fecha,
                categoria: categoria,
                metodoPago: metodoPago,
                tags: expenseTags,
                foreignTax: foreignTax
            )
        }

        guard ok else { return }
        if !isEditing {
            limpiarFormulario()
        }
        onSaved()
    }

    private func applySmartSuggestionIfNeeded() {
        guard !isEditing else { return }
        guard let suggestion = store.smartSuggestion(for: descripcion) else {
            activeSuggestion = nil
            return
        }

        activeSuggestion = suggestion
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            if !userPickedCategory {
                categoriaId = suggestion.categoria.id
            }
            if !userPickedPaymentMethod {
                metodoPagoId = suggestion.metodoPago.id
            }
        }
    }

    private func suggestionMessage(_ suggestion: ExpenseSmartSuggestion) -> String {
        let base = "Usaré \(suggestion.categoria.nombre) y \(suggestion.metodoPago.shortLabel)."
        guard let source = suggestion.sourceDescription, !source.isEmpty else {
            return base
        }
        return "\(base) Basado en \"\(source)\"."
    }
}
