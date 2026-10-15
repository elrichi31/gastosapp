import SwiftUI

enum RecurringComposerKind: Hashable {
    case recurrente
    case suscripcion

    var title: String {
        switch self {
        case .recurrente:
            return "Nuevo gasto recurrente"
        case .suscripcion:
            return "Nueva suscripción"
        }
    }

    var subtitle: String {
        switch self {
        case .recurrente:
            return "Programa un gasto que se repite cada semana o cada mes"
        case .suscripcion:
            return "Guarda un cobro periódico como Netflix, Spotify o cualquier servicio"
        }
    }

    var descriptionPlaceholder: String {
        switch self {
        case .recurrente:
            return "Descripción"
        case .suscripcion:
            return "Servicio o suscripción"
        }
    }

    var saveTitle: String {
        switch self {
        case .recurrente:
            return "Guardar recurrente"
        case .suscripcion:
            return "Guardar suscripción"
        }
    }
}

struct AddRecurringExpenseView: View {
    private enum FocusField: Hashable {
        case descripcion
    }

    let kind: RecurringComposerKind
    var existingExpense: RecurringExpense? = nil
    var onSaved: () -> Void = {}

    @Environment(ExpenseStore.self) private var store

    @State private var seeded = false
    @State private var foreignEnabled = false
    @State private var taxSelection = ["isd"]
    @State private var customRate = ""
    @State private var annualMonth = Calendar.current.component(.month, from: Date())
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var active = true
    private var foreignTax: ForeignTax? {
        foreignEnabled ? ForeignTax(base: ForeignTax.cents(montoNumerico), selected: taxSelection, customRate: customRate) : nil
    }
    @State private var descripcion = ""
    @State private var monto = ""
    @State private var fechaInicio = Date()
    @State private var categoriaId = 0
    @State private var metodoPagoId = 0
    @State private var frecuencia: RecurringFrequency = .mensual
    @State private var diaMes = Calendar.current.component(.day, from: Date())
    @State private var diaSemana = AddRecurringExpenseView.currentWeekday
    @FocusState private var focusedField: FocusField?

    private static var currentWeekday: Int {
        weekdayNumber(for: Date())
    }

    private static func weekdayNumber(for date: Date) -> Int {
        let current = Calendar.current.component(.weekday, from: date)
        return current == 1 ? 7 : current - 1
    }

    private var montoNumerico: Double {
        MoneyInput.parse(monto) ?? 0
    }

    private var categoriaSeleccionada: Categoria? {
        if kind == .suscripcion, let categoria = categoriaSuscripciones {
            return categoria
        }
        return store.categorias.first(where: { $0.id == categoriaId })
    }

    private var categoriaSuscripciones: Categoria? {
        store.categorias.first(where: { $0.nombre.normalizedLookupKey.contains("suscrip") })
    }

    private var metodoPagoSeleccionado: ExpensePaymentMethod? {
        store.metodosPago.first(where: { $0.id == metodoPagoId })
    }

    private var puedeGuardar: Bool {
        !descripcion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        montoNumerico > 0 && (foreignTax?.isValid ?? true) &&
        categoriaSeleccionada != nil &&
        metodoPagoSeleccionado != nil &&
        store.canAccessProtectedEndpoints &&
        !store.isSavingExpense && (!hasEndDate || endDate >= fechaInicio)
    }

    private var isEditing: Bool {
        existingExpense != nil
    }

    @FocusState private var amountFocused: Bool

    private static let weekdayLetters = ["L", "M", "X", "J", "V", "S", "D"]
    private static let monthShort = ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                estadoCard
                FormAmountEntry(
                    label: foreignEnabled ? "Precio sin impuestos" : (kind == .suscripcion ? "Monto por cobro" : "Monto de cada cobro"),
                    text: $monto,
                    hint: (scheduleSummary, AppTheme.secondaryAccent),
                    focus: $amountFocused
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Descripción")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.tertiaryText)
                    TextField("", text: $descripcion, prompt: Text(kind == .suscripcion ? "Ej: Netflix, Spotify" : "Ej: Netflix, gimnasio").foregroundStyle(AppTheme.placeholderText))
                        .focused($focusedField, equals: .descripcion)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .tint(AppTheme.accent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(groupBackground)

                VStack(alignment: .leading, spacing: 10) {
                    FormSectionTitle(title: "Frecuencia")
                    HStack(spacing: 8) {
                        ForEach([RecurringFrequency.semanal, .mensual, .anual], id: \.self) { option in
                            pill(option.title, isSelected: frecuencia == option, height: 44, fontSize: 15) {
                                frecuencia = option
                            }
                        }
                    }
                }

                if frecuencia == .semanal {
                    VStack(alignment: .leading, spacing: 10) {
                        FormSectionTitle(title: "Día de la semana")
                        HStack {
                            ForEach(1...7, id: \.self) { day in
                                let isSelected = diaSemana == day
                                Button {
                                    diaSemana = day
                                } label: {
                                    Text(Self.weekdayLetters[day - 1])
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.primaryText)
                                        .frame(width: 44, height: 44)
                                        .background(Circle().fill(isSelected ? AppTheme.primaryText : AppTheme.popoverSurface))
                                }
                                .buttonStyle(.pressable(scale: 0.92))
                                .accessibilityLabel(weekdayLabel(for: day))
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                                if day < 7 { Spacer(minLength: 0) }
                            }
                        }
                    }
                }

                if frecuencia == .anual {
                    VStack(alignment: .leading, spacing: 10) {
                        FormSectionTitle(title: "Mes")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(1...12, id: \.self) { month in
                                pill(Self.monthShort[month - 1], isSelected: annualMonth == month, height: 44, fontSize: 14) {
                                    annualMonth = month
                                }
                                .accessibilityLabel(StatsView.spanishMonthSymbols[month - 1])
                            }
                        }
                    }
                }

                if frecuencia != .semanal {
                    HStack(spacing: 12) {
                        Text("Día del mes")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer(minLength: 8)
                        stepButton("chevron.left", label: "Día anterior", enabled: diaMes > 1) { diaMes -= 1 }
                        Text(diaMes >= 31 ? "Último día" : "\(diaMes)")
                            .font(.system(size: 18, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(minWidth: 76)
                            .contentTransition(.numericText(value: Double(diaMes)))
                            .accessibilityLabel("Día del mes: \(diaMes >= 31 ? "último día" : "\(diaMes)")")
                        stepButton("chevron.right", label: "Día siguiente", enabled: diaMes < 31) { diaMes += 1 }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(groupBackground)
                }

                FormGroupedRows {
                    FormLabeledRow(label: isEditing ? "Próximo cobro" : "Inicio") {
                        DatePicker("Fecha de inicio", selection: $fechaInicio, displayedComponents: .date)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                    }
                    if isEditing {
                        toggleRow("Activo", isOn: $active)
                    }
                    toggleRow("¿Tiene fecha de finalización?", isOn: $hasEndDate.animation(.easeOut(duration: 0.18)), showsDivider: hasEndDate)
                    if hasEndDate {
                        FormLabeledRow(label: "Fecha de fin", showsDivider: false) {
                            DatePicker("Fecha de fin", selection: $endDate, in: fechaInicio..., displayedComponents: .date)
                                .labelsHidden()
                                .tint(AppTheme.accent)
                        }
                    }
                }

                if kind != .suscripcion || categoriaSuscripciones == nil {
                    VStack(alignment: .leading, spacing: 10) {
                        FormSectionTitle(title: "Categoría")
                        CategoryChipPicker(categories: store.categorias, selectedID: $categoriaId)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    FormSectionTitle(title: "Método de pago")
                    PaymentMethodPicker(methods: store.metodosPago, selectedID: $metodoPagoId)
                }

                ForeignTaxFields(enabled: $foreignEnabled, selected: $taxSelection, customRate: $customRate, base: montoNumerico)
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
                    title: isEditing ? "Guardar cambios" : kind.saveTitle,
                    disabledHint: disabledHint
                ) {
                    Task { await guardar() }
                }
            }
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
        .onChange(of: fechaInicio) { _, newDate in
            if existingExpense == nil { syncScheduleFields(from: newDate) }
        }
    }

    /// «Cada mes el día 15 · $155,88 al año», como el resumen del canvas.
    private var scheduleSummary: String {
        let rule: String
        switch frecuencia {
        case .semanal:
            rule = "Cada \(weekdayLabel(for: diaSemana).lowercased())"
        case .mensual:
            rule = "Cada mes " + (diaMes >= 31 ? "el último día" : "el día \(diaMes)")
        case .anual:
            rule = "Cada año el " + (diaMes >= 31 ? "último día" : "\(diaMes)") + " de " + StatsView.spanishMonthSymbols[annualMonth - 1]
        }
        let perCharge = foreignTax?.total ?? montoNumerico
        guard perCharge > 0 else { return rule }
        let timesPerYear: Double = switch frecuencia {
        case .semanal: 52
        case .mensual: 12
        case .anual: 1
        }
        let yearly = (perCharge * timesPerYear).formatted(.currency(code: "USD").precision(.fractionLength(2)))
        return frecuencia == .anual ? rule : "\(rule) · \(yearly) al año"
    }

    private var disabledHint: String? {
        if montoNumerico <= 0 { return "Ingresa un monto" }
        if descripcion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Agrega una descripción" }
        if !store.canAccessProtectedEndpoints { return "Inicia sesión para guardar" }
        if hasEndDate && endDate < fechaInicio { return "Revisa la fecha de fin" }
        if foreignTax?.isValid == false { return "Revisa los impuestos" }
        return nil
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
    }

    private func pill(_ title: String, isSelected: Bool, height: CGFloat, fontSize: CGFloat, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { action() }
        } label: {
            Text(title)
                .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.primaryText)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(Capsule().fill(isSelected ? AppTheme.primaryText : AppTheme.popoverSurface))
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.18)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.primaryText : AppTheme.placeholderText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable(scale: 0.9))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, showsDivider: Bool = true) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)
        }
        .tint(AppTheme.accent)
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if showsDivider { Rectangle().fill(AppTheme.separator).frame(height: 1) }
        }
    }

    @ViewBuilder
    private var estadoCard: some View {
        if let status = estadoActual {
            ExpenseFormStatusCard(status: ExpenseFormStatus(title: status.title, message: status.message, icon: status.icon, tint: status.tint))
        }
    }

    private var weekdays: [(value: Int, label: String)] {
        [
            (1, "Lunes"),
            (2, "Martes"),
            (3, "Miércoles"),
            (4, "Jueves"),
            (5, "Viernes"),
            (6, "Sábado"),
            (7, "Domingo")
        ]
    }

    private func weekdayLabel(for value: Int) -> String {
        weekdays.first(where: { $0.value == value })?.label ?? "Lunes"
    }

    /// Sólo lo que impide guardar; los avisos informativos ya no ocupan sitio.
    private var estadoActual: (title: String, message: String, icon: String, tint: Color)? {
        if let error = store.saveErrorMessage {
            return ("No se pudo guardar", error, "exclamationmark.triangle.fill", AppTheme.warning)
        }
        if !store.hasBaseURLConfigured {
            return (
                "Configura el backend",
                "Antes de guardar necesitas la URL base del backend. Usa el botón de conexión arriba.",
                "slider.horizontal.3",
                .yellow
            )
        }
        if !store.canAccessProtectedEndpoints {
            return (
                "Falta la sesión",
                "Inicia sesión para guardar cargos recurrentes.",
                "key.fill",
                AppTheme.secondaryAccent
            )
        }
        return nil
    }

    private func aplicarSeleccionInicial() {
        guard !seeded else { return }
        if existingExpense != nil { seeded = true }
        if let existingExpense {
            descripcion = existingExpense.descripcion
            monto = MoneyInput.format(existingExpense.foreignTax?.base ?? existingExpense.monto)
            foreignEnabled = existingExpense.foreignTax != nil
            taxSelection = existingExpense.foreignTax?.selected ?? ["isd"]
            customRate = existingExpense.foreignTax?.customRate ?? ""
            hasEndDate = existingExpense.fechaFin != nil
            endDate = existingExpense.fechaFin ?? Date()
            active = existingExpense.activo
            fechaInicio = existingExpense.fechaInicio
            categoriaId = existingExpense.categoriaId
            metodoPagoId = existingExpense.metodoPagoId
            annualMonth = existingExpense.annualMonth ?? annualMonth
            frecuencia = existingExpense.frecuencia
            diaMes = existingExpense.diaMes ?? diaMes
            diaSemana = existingExpense.diaSemana ?? diaSemana
            return
        }

        if kind == .suscripcion, let categoria = categoriaSuscripciones {
            categoriaId = categoria.id
        } else if categoriaSeleccionada == nil {
            categoriaId = store.categorias.first?.id ?? 0
        }

        if metodoPagoSeleccionado == nil {
            metodoPagoId = store.metodosPago.first?.id ?? 0
        }

        if diaMes < 1 || diaMes > 31 {
            diaMes = min(max(diaMes, 1), 31)
        }
        syncScheduleFields(from: fechaInicio)
    }

    private func syncScheduleFields(from date: Date) {
        let calendar = Calendar.current
        diaMes = min(max(calendar.component(.day, from: date), 1), 31)
        annualMonth = calendar.component(.month, from: date)
        diaSemana = Self.weekdayNumber(for: date)
    }

    private func guardar() async {
        guard let categoria = categoriaSeleccionada, let metodoPago = metodoPagoSeleccionado else { return }

        let cleanedDescription = descripcion.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok: Bool

        if let existingExpense {
            ok = await store.updateRecurringExpense(
                id: existingExpense.id,
                descripcion: cleanedDescription,
                monto: foreignTax?.total ?? montoNumerico,
                fechaInicio: fechaInicio,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: frecuencia != .semanal ? diaMes : nil,
                diaSemana: frecuencia == .semanal ? diaSemana : nil,
                activo: active,
                fechaFin: hasEndDate ? endDate : nil,
                annualMonth: annualMonth,
                foreignTax: foreignTax
            )
        } else {
            ok = await store.createRecurringExpense(
                descripcion: cleanedDescription,
                monto: foreignTax?.total ?? montoNumerico,
                fechaInicio: fechaInicio,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: frecuencia != .semanal ? diaMes : nil,
                diaSemana: frecuencia == .semanal ? diaSemana : nil,
                fechaFin: hasEndDate ? endDate : nil,
                annualMonth: annualMonth,
                foreignTax: foreignTax
            )
        }

        guard ok else { return }
        onSaved()
    }
}

#Preview {
    AddRecurringExpenseView(kind: .recurrente)
        .environment(ExpenseStore())
}
