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
        case monto
    }

    let kind: RecurringComposerKind
    var existingExpense: RecurringExpense? = nil
    var onSaved: () -> Void = {}

    @Environment(ExpenseStore.self) private var store

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
        montoNumerico > 0 &&
        categoriaSeleccionada != nil &&
        metodoPagoSeleccionado != nil &&
        store.canAccessProtectedEndpoints &&
        !store.isSavingExpense
    }

    private var isEditing: Bool {
        existingExpense != nil
    }

    var body: some View {
        ZStack {
            fondo.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    encabezado
                    estadoCard
                    montoCard
                    detallesCard
                    if kind != .suscripcion || categoriaSuscripciones == nil {
                        categoriaCard
                    }
                    metodoPagoCard
                    botonGuardar
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, 12)
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
        .onChange(of: fechaInicio) { _, newDate in
            syncScheduleFields(from: newDate)
        }
    }

    private var fondo: some View {
        LinearGradient(
            colors: [
                AppTheme.backgroundTop,
                AppTheme.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var encabezado: some View {
        AppScreenHeader(
            eyebrow: isEditing ? "Actualiza monto, frecuencia o método de pago." : kind.subtitle,
            title: isEditing ? "Editar cargo recurrente" : kind.title
        )
    }

    @ViewBuilder
    private var estadoCard: some View {
        if let status = estadoActual {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: status.icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(status.tint)
                    .frame(width: 28, height: 28)
                    .background(status.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(status.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(tarjetaFondo)
        }
    }

    private var montoCard: some View {
        VStack(spacing: 14) {
            Text(kind == .suscripcion ? "Monto por cobro" : "Monto del gasto")
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.statementSecondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Spacer(minLength: 0)
                Text("$")
                    .font(.system(size: 30, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.accent)
                TextField(
                    "",
                    text: $monto,
                    prompt: Text("0").foregroundStyle(AppTheme.onStatement.opacity(0.22))
                )
                .keyboardType(.decimalPad)
                .font(.system(size: 64, weight: .bold, design: .default))
                .focused($focusedField, equals: .monto)
                .foregroundStyle(AppTheme.onStatement)
                .tint(AppTheme.accent)
                .multilineTextAlignment(.leading)
                .fixedSize()
                Spacer(minLength: 0)
            }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.accent.opacity(0.0), AppTheme.accent.opacity(0.7), AppTheme.accent.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 3)
                .opacity(monto.isEmpty ? 0.2 : 1)
                .animation(.easeInOut(duration: 0.2), value: monto.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(AppTheme.statementBackground(cornerRadius: 32))
    }

    private var detallesCard: some View {
        VStack(spacing: 0) {
            campoTexto(icono: kind == .suscripcion ? "rectangle.stack.fill" : "repeat", placeholder: kind.descriptionPlaceholder, texto: $descripcion)
            divisor
            HStack(spacing: 14) {
                iconoCircular("calendar", color: AppTheme.secondaryAccent)
                DatePicker("", selection: $fechaInicio, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                Spacer()
                Text(isEditing ? "Próximo cobro" : "Primer cobro")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divisor

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    iconoCircular("calendar.badge.clock", color: AppTheme.secondaryAccent)
                    Text("Frecuencia")
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                }

                HStack(spacing: 8) {
                    frecuenciaPill(.mensual)
                    frecuenciaPill(.semanal)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divisor

            if frecuencia == .mensual {
                HStack(spacing: 14) {
                    iconoCircular("number.square.fill", color: AppTheme.accent)
                    Text("Día del mes")
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Menu {
                        Picker("Día del mes", selection: $diaMes) {
                            ForEach(1...28, id: \.self) { day in
                                Text("\(day)").tag(day)
                            }
                        }
                    } label: {
                        selectorLabel("\(diaMes)")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            } else {
                HStack(spacing: 14) {
                    iconoCircular("calendar.day.timeline.leading", color: AppTheme.accent)
                    Text("Día de la semana")
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Menu {
                        Picker("Día de la semana", selection: $diaSemana) {
                            ForEach(weekdays, id: \.value) { item in
                                Text(item.label).tag(item.value)
                            }
                        }
                    } label: {
                        selectorLabel(weekdayLabel(for: diaSemana))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .background(tarjetaFondo)
    }

    private var categoriaCard: some View {
        VStack(spacing: 0) {
            menuFila(
                icono: categoriaSeleccionada?.icono ?? "square.grid.2x2.fill",
                color: categoriaSeleccionada?.color ?? .gray,
                titulo: "Categoría",
                valor: categoriaSeleccionada?.nombre ?? "Selecciona"
            ) {
                Picker("Categoría", selection: $categoriaId) {
                    ForEach(store.categorias) { categoria in
                        Label(categoria.nombre, systemImage: categoria.icono).tag(categoria.id)
                    }
                }
            }
        }
        .background(tarjetaFondo)
    }

    private var metodoPagoCard: some View {
        VStack(spacing: 0) {
            menuFila(
                icono: metodoPagoSeleccionado?.icono ?? "creditcard.fill",
                color: AppTheme.secondaryAccent,
                titulo: "Método de pago",
                valor: metodoPagoSeleccionado?.nombre ?? "Selecciona"
            ) {
                Picker("Método de pago", selection: $metodoPagoId) {
                    ForEach(store.metodosPago) { metodo in
                        Label(metodo.nombre, systemImage: metodo.icono).tag(metodo.id)
                    }
                }
            }
        }
        .background(tarjetaFondo)
    }

    private var botonGuardar: some View {
        Button {
            Task { await guardar() }
        } label: {
            HStack(spacing: 10) {
                if store.isSavingExpense {
                    ProgressView()
                        .tint(puedeGuardar ? AppTheme.onAccent : AppTheme.tertiaryText)
                }
                Text(store.isSavingExpense ? "Guardando…" : (isEditing ? "Guardar cambios" : kind.saveTitle))
                    .font(.headline)
            }
            .foregroundStyle(puedeGuardar ? AppTheme.onAccent : AppTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: puedeGuardar
                        ? [AppTheme.accent, AppTheme.accent]
                        : [AppTheme.disabledFill, AppTheme.disabledFill],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!puedeGuardar)
        .padding(.top, 8)
    }

    private func frecuenciaPill(_ option: RecurringFrequency) -> some View {
        let isSelected = frecuencia == option
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                frecuencia = option
            }
        } label: {
            Text(option.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .black : AppTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.accent : AppTheme.controlSurface)
                )
        }
        .buttonStyle(.plain)
    }

    private func selectorLabel(_ value: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .foregroundStyle(AppTheme.secondaryText)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private func campoTexto(icono: String, placeholder: String, texto: Binding<String>) -> some View {
        HStack(spacing: 14) {
            iconoCircular(icono, color: AppTheme.secondaryAccent)
            TextField("", text: texto, prompt: Text(placeholder).foregroundStyle(AppTheme.tertiaryText))
                .focused($focusedField, equals: .descripcion)
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func menuFila<Content: View>(
        icono: String,
        color: Color,
        titulo: String,
        valor: String,
        @ViewBuilder picker: () -> Content
    ) -> some View {
        HStack(spacing: 14) {
            iconoCircular(icono, color: color)
            Text(titulo)
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Menu {
                picker()
            } label: {
                selectorLabel(valor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var tarjetaFondo: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppTheme.controlSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(AppTheme.border, lineWidth: 1)
            )
    }

    private var divisor: some View {
        Divider()
            .background(AppTheme.border)
            .padding(.leading, 56)
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

    private func iconoCircular(_ nombre: String, color: Color) -> some View {
        Image(systemName: nombre)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

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
                "Inicia sesión en la app para crear cargos recurrentes con tu bearer token.",
                "key.fill",
                AppTheme.secondaryAccent
            )
        }
        if let categoria = categoriaSuscripciones, kind == .suscripcion {
            return (
                "Categoría aplicada",
                "Esta suscripción se guardará dentro de \(categoria.nombre).",
                "checkmark.seal.fill",
                AppTheme.accent
            )
        }
        return ("Listo para programar", "El cargo se guardará como recurrente en el backend.", "repeat.circle.fill", AppTheme.accent)
    }

    private func aplicarSeleccionInicial() {
        if let existingExpense {
            descripcion = existingExpense.descripcion
            monto = MoneyInput.format(existingExpense.monto)
            fechaInicio = existingExpense.nextChargeDate ?? existingExpense.fechaInicio
            categoriaId = existingExpense.categoriaId
            metodoPagoId = existingExpense.metodoPagoId
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

        if diaMes < 1 || diaMes > 28 {
            diaMes = min(max(diaMes, 1), 28)
        }
        syncScheduleFields(from: fechaInicio)
    }

    private func syncScheduleFields(from date: Date) {
        let calendar = Calendar.current
        diaMes = min(max(calendar.component(.day, from: date), 1), 28)
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
                monto: montoNumerico,
                fechaInicio: fechaInicio,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: frecuencia == .mensual ? diaMes : nil,
                diaSemana: frecuencia == .semanal ? diaSemana : nil,
                activo: existingExpense.activo
            )
        } else {
            ok = await store.createRecurringExpense(
                descripcion: cleanedDescription,
                monto: montoNumerico,
                fechaInicio: fechaInicio,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: frecuencia == .mensual ? diaMes : nil,
                diaSemana: frecuencia == .semanal ? diaSemana : nil
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
