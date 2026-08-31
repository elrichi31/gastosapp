import SwiftUI

struct AddExpenseView: View {
    private enum FocusField: Hashable {
        case descripcion
        case monto
    }

    let editingExpense: Expense?
    var onSaved: () -> Void = {}

    @Environment(ExpenseStore.self) private var store
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
        montoNumerico > 0 &&
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
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    encabezado
                    estadoCard
                    expenseComposerCard
                    suggestionCard
                    categoriaCard
                    botonGuardar
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            await store.loadCatalogsIfNeeded()
            aplicarSeleccionInicial()
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
    }

    private var encabezado: some View {
        AppScreenHeader(
            eyebrow: isEditing ? "Corrige monto, categoría, método o fecha" : "Registra rápido sin perder detalle",
            title: isEditing ? "Editar gasto" : "Nuevo gasto"
        )
    }

    @ViewBuilder
    private var estadoCard: some View {
        if let status = estadoActual {
            ExpenseFormStatusCard(status: status)
        }
    }

    private var expenseComposerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            compactAmountField

            VStack(spacing: 0) {
                descripcionField
                ExpenseFormDivider()
                fechaField
                ExpenseFormDivider()
                metodoPagoInlineField
            }
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.controlSurface)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            )
        }
    }

    private var compactAmountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Monto")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.statementSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("$")
                    .font(.system(size: 26, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.accent)
                TextField(
                    "",
                    text: $monto,
                    prompt: Text("0.00").foregroundStyle(AppTheme.onStatement.opacity(0.22))
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 46, weight: .bold, design: .default))
                .focused($focusedField, equals: .monto)
                .foregroundStyle(AppTheme.onStatement)
                .tint(AppTheme.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .monospacedDigit()

                Spacer(minLength: 0)
            }
        }
        .padding(24)
        .background(AppTheme.statementBackground(cornerRadius: 32))
    }

    private var descripcionField: some View {
        HStack(spacing: 14) {
            ExpenseIconBadge(systemName: "text.alignleft", color: AppTheme.secondaryAccent)
            TextField(
                "",
                text: $descripcion,
                prompt: Text("Descripción opcional").foregroundStyle(AppTheme.tertiaryText)
            )
            .focused($focusedField, equals: .descripcion)
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
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
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppTheme.controlSurface)
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            )
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var fechaField: some View {
        HStack(spacing: 14) {
            ExpenseIconBadge(systemName: "calendar", color: AppTheme.secondaryAccent)
            Text("Fecha")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            DatePicker("", selection: $fecha, displayedComponents: .date)
                .labelsHidden()
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var metodoPagoInlineField: some View {
        HStack(spacing: 14) {
            ExpenseIconBadge(systemName: metodoPagoSeleccionado?.icono ?? "creditcard.fill", color: AppTheme.accent)
            Text("Método")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Menu {
                ForEach(store.metodosPago) { metodo in
                    Button {
                        userPickedPaymentMethod = true
                        metodoPagoId = metodo.id
                    } label: {
                        Label(metodo.nombre, systemImage: metodo.icono)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(metodoPagoSeleccionado?.shortLabel ?? "Elegir")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(AppTheme.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
    }

    private var categoriaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionTitle(title: "Categoría", trailingText: categoriaSeleccionada?.nombre ?? "Elegir")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                ForEach(store.categorias) { categoria in
                    categoriaButton(categoria)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func categoriaButton(_ categoria: Categoria) -> some View {
        let isSelected = categoriaId == categoria.id
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                userPickedCategory = true
                categoriaId = categoria.id
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                CategoryGlyph(
                    categoria: categoria,
                    size: 54,
                    tint: isSelected ? AppTheme.onAccent : AppTheme.primaryText,
                    background: isSelected ? AppTheme.accent : AppTheme.controlSurface,
                    borderColor: isSelected ? nil : AppTheme.border
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black)
                        .background(Circle().fill(AppTheme.accent))
                        .offset(x: 3, y: -3)
                }
            }
            .frame(width: 58, height: 58)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(categoria.nombre)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var botonGuardar: some View {
        ExpensePrimarySaveButton(
            isSaving: store.isSavingExpense,
            isEnabled: puedeGuardar,
            title: isEditing ? "Guardar cambios" : "Guardar gasto"
        ) {
            Task { await guardar() }
        }
        .padding(.top, 8)
    }

    private var estadoActual: ExpenseFormStatus? {
        if let error = store.saveErrorMessage {
            return .init(title: "No se pudo guardar", message: error, icon: "exclamationmark.triangle.fill", tint: AppTheme.warning)
        }
        if !store.hasBaseURLConfigured {
            return .init(title: "Configura el backend", message: "Antes de guardar necesitas la URL base del backend. Usa el botón de conexión arriba.", icon: "slider.horizontal.3", tint: .yellow)
        }
        if !store.canAccessProtectedEndpoints && !canEditLocalDraft {
            let action = isEditing ? "editar tus gastos" : "llamar POST /api/gastos con tu bearer token"
            return .init(title: "Falta la sesión", message: "Inicia sesión en la app para poder \(action).", icon: "key.fill", tint: AppTheme.secondaryAccent)
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
            monto = MoneyInput.format(editingExpense.monto)
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
                monto: montoNumerico,
                fecha: fecha,
                categoria: categoria,
                metodoPago: metodoPago,
                isRecurrent: editingExpense.isRecurrent
            )
        } else {
            ok = await store.createExpense(
                descripcion: cleanDescription,
                monto: montoNumerico,
                fecha: fecha,
                categoria: categoria,
                metodoPago: metodoPago
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
