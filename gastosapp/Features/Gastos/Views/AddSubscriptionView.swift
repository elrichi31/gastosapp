import SwiftUI

struct AddSubscriptionView: View {
    @Environment(ExpenseStore.self) private var expenseStore
    @Environment(\.dismiss) private var dismiss

    var showsCloseButton: Bool = true
    var existingExpense: RecurringExpense? = nil
    var onSaved: (() -> Void)? = nil

    @State private var seleccionado: Provider? = nil
    @State private var busqueda: String = ""
    @State private var nombreServicio: String = ""
    @State private var monto: String = ""
    @State private var ciclo: CicloFacturacion = .mensual
    @State private var proximaFecha: Date = Date()
    @State private var metodoPago: MetodoPago = .credito
    @State private var isPickingProvider = false
    @FocusState private var focusedField: FocusField?

    private enum FocusField: Hashable {
        case servicio
        case monto
    }

    private var resultados: [(ProviderCategoria, [Provider])] {
        let q = busqueda.trimmingCharacters(in: .whitespaces).lowercased()
        let filtrados: [Provider] = q.isEmpty
            ? Provider.allCases
            : Provider.allCases.filter { $0.nombre.lowercased().contains(q) }
        let dict = Dictionary(grouping: filtrados, by: \.categoria)
        return ProviderCategoria.allCases.compactMap { cat in
            guard let arr = dict[cat], !arr.isEmpty else { return nil }
            return (cat, arr)
        }
    }

    private var montoNumerico: Double {
        MoneyInput.parse(monto) ?? 0
    }

    private var nombreServicioLimpio: String {
        nombreServicio.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isEditing: Bool {
        existingExpense != nil
    }

    private var providerCoincidente: Provider? {
        if let seleccionado {
            return seleccionado
        }

        let lookup = nombreServicioLimpio.normalizedLookupKey
        guard !lookup.isEmpty else { return nil }

        return Provider.allCases.first { provider in
            let providerLookup = provider.nombre.normalizedLookupKey
            return providerLookup == lookup || providerLookup.contains(lookup) || lookup.contains(providerLookup)
        }
    }

    private var servicioConfigurado: Bool {
        !nombreServicioLimpio.isEmpty
    }

    private var puedeGuardar: Bool {
        servicioConfigurado &&
        montoNumerico > 0 &&
        categoriaSuscripciones != nil &&
        metodoPagoRemoto != nil &&
        !expenseStore.isSavingExpense
    }

    private var categoriaSuscripciones: Categoria? {
        expenseStore.categorias.first(where: { $0.nombre.normalizedLookupKey.contains("suscrip") })
    }

    private var metodoPagoRemoto: ExpensePaymentMethod? {
        expenseStore.metodosPago.first { metodo in
            metodo.nombre.normalizedLookupKey.contains(metodoPago.rawValue.normalizedLookupKey)
        } ?? expenseStore.metodosPago.first { metodo in
            switch metodoPago {
            case .efectivo:
                return metodo.nombre.normalizedLookupKey.contains("efectivo")
            case .debito:
                return metodo.nombre.normalizedLookupKey.contains("debito")
            case .credito:
                return metodo.nombre.normalizedLookupKey.contains("credito")
            case .transferencia:
                return metodo.nombre.normalizedLookupKey.contains("transfer")
            }
        }
    }

    private var ciclosDisponibles: [CicloFacturacion] {
        [.mensual, .semanal]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                encabezado
                estadoCard

                if servicioConfigurado && !isPickingProvider {
                    formularioCompleto(providerCoincidente)
                } else {
                    if isPickingProvider && servicioConfigurado {
                        volverFormularioButton
                    }
                    buscador
                    catalogoGrid
                }
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, AppScreenMetrics.contentBottomPadding)
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await expenseStore.loadCatalogsIfNeeded()
            aplicarSeleccionInicial()
        }
        .onAppear {
            aplicarSeleccionInicial()
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        AppScreenHeader(
            eyebrow: servicioConfigurado ? "Ajusta monto, ciclo y método de pago" : "Elige el proveedor",
            title: isEditing ? "Editar suscripción" : (servicioConfigurado ? "Configurar" : "Nueva suscripción")
        ) {
            if showsCloseButton {
                AppCircleButton(icon: "xmark", label: "Cerrar") { dismiss() }
            }
        }
    }

    // MARK: - Buscador

    private var buscador: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(AppTheme.secondaryText)
            TextField(
                "",
                text: $busqueda,
                prompt: Text("Buscar proveedor").foregroundStyle(AppTheme.tertiaryText)
            )
            .foregroundStyle(AppTheme.primaryText)
            .tint(AppTheme.accent)
            if !busqueda.isEmpty {
                Button { busqueda = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .accessibilityLabel("Limpiar búsqueda")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.controlSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Grid de proveedores

    private var catalogoGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
        return VStack(spacing: 18) {
            ForEach(resultados, id: \.0) { cat, providers in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: cat.icono)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                        Text(cat.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .tracking(0.5)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    LazyVGrid(columns: cols, spacing: 12) {
                        ForEach(providers) { p in
                            celdaProvider(p)
                        }
                    }
                }
            }
            if resultados.isEmpty {
                Text("Sin resultados")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.vertical, 20)
            }
        }
    }

    private func celdaProvider(_ p: Provider) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                seleccionado = p
                nombreServicio = p.nombre
                isPickingProvider = false
            }
        } label: {
            VStack(spacing: 6) {
                ProviderBadge(provider: p, size: 52)
                Text(p.nombre)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Formulario completo (después de seleccionar)

    private func formularioCompleto(_ provider: Provider?) -> some View {
        VStack(spacing: 22) {
            providerHeaderCard(provider)
            montoCard
            detallesCard
            botonGuardar
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var volverFormularioButton: some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                    isPickingProvider = false
                }
            } label: {
                Label("Volver", systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func providerHeaderCard(_ provider: Provider?) -> some View {
        HStack(spacing: 14) {
            Group {
                if let provider {
                    ProviderBadge(provider: provider, size: 56)
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.controlSurface)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "rectangle.stack.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                TextField(
                    "",
                    text: $nombreServicio,
                    prompt: Text("Nombre del servicio").foregroundStyle(AppTheme.placeholderText)
                )
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .focused($focusedField, equals: .servicio)

                Text(provider?.categoria.rawValue ?? "Suscripción personalizada")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isPickingProvider = true
                    busqueda = ""
                }
            } label: {
                Text("Elegir otro")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(AppTheme.accent.opacity(0.15))
                    )
            }
        }
        .padding(16)
        .background(tarjetaFondo)
    }

    private var montoCard: some View {
        VStack(spacing: 14) {
            Text("Monto por cobro")
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

            if montoNumerico > 0 && ciclo != .mensual {
                Text("≈ $\(formatear(montoNumerico * ciclo.factorMensual)) / mes")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
        .background(tarjetaFondo)
    }

    private var detallesCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                iconoCircular("repeat", color: AppTheme.secondaryAccent)
                Text("Ciclo")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Menu {
                    Picker("Ciclo", selection: $ciclo) {
                        ForEach(ciclosDisponibles) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(ciclo.rawValue).foregroundStyle(AppTheme.secondaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divisor

            HStack(spacing: 14) {
                iconoCircular("calendar", color: AppTheme.accent)
                DatePicker("", selection: $proximaFecha, displayedComponents: .date)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                Spacer()
                Text("Próximo cobro")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divisor

            HStack(spacing: 14) {
                iconoCircular(metodoPago.icono, color: AppTheme.secondaryAccent)
                Text("Método de pago")
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Menu {
                    Picker("Método", selection: $metodoPago) {
                        ForEach(MetodoPago.allCases) { m in
                            Label(m.rawValue, systemImage: m.icono).tag(m)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(metodoPago.rawValue).foregroundStyle(AppTheme.secondaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(tarjetaFondo)
    }

    private var botonGuardar: some View {
        Button {
            Task { await guardar() }
        } label: {
            HStack(spacing: 10) {
                if expenseStore.isSavingExpense {
                    ProgressView()
                        .tint(puedeGuardar ? AppTheme.onAccent : AppTheme.tertiaryText)
                }
                Text(expenseStore.isSavingExpense ? "Guardando…" : (isEditing ? "Guardar cambios" : "Guardar suscripción"))
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
    }

    private var estadoCard: some View {
        Group {
            if let error = expenseStore.saveErrorMessage {
                infoCard(icon: "exclamationmark.triangle.fill", color: AppTheme.warning, title: "No se pudo guardar", message: error)
            } else if categoriaSuscripciones == nil {
                infoCard(icon: "tray.fill", color: .yellow, title: "Falta categoría", message: "No encontramos una categoría de suscripciones en tu cuenta.")
            } else if !expenseStore.canAccessProtectedEndpoints {
                infoCard(icon: "person.crop.circle.badge.exclamationmark", color: AppTheme.secondaryAccent, title: "Inicia sesión", message: "Necesitas una sesión activa para guardar suscripciones.")
            } else if isEditing {
                infoCard(icon: "checkmark.seal.fill", color: AppTheme.accent, title: "Se guarda como recurrente", message: "Esta suscripción vive dentro de tus gastos programados y se puede editar aquí mismo.")
            }
        }
    }

    private func guardar() async {
        guard
            let categoria = categoriaSuscripciones,
            let metodoPago = metodoPagoRemoto,
            montoNumerico > 0
        else { return }

        let frecuencia: RecurringFrequency = ciclo == .semanal ? .semanal : .mensual
        let diaMes = frecuencia == .mensual ? min(max(Calendar.current.component(.day, from: proximaFecha), 1), 28) : nil
        let diaSemana = frecuencia == .semanal ? Self.weekdayNumber(for: proximaFecha) : nil

        let ok: Bool
        if let existingExpense {
            ok = await expenseStore.updateRecurringExpense(
                id: existingExpense.id,
                descripcion: nombreServicioLimpio,
                monto: montoNumerico,
                fechaInicio: proximaFecha,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: diaMes,
                diaSemana: diaSemana,
                activo: existingExpense.activo
            )
        } else {
            ok = await expenseStore.createRecurringExpense(
                descripcion: nombreServicioLimpio,
                monto: montoNumerico,
                fechaInicio: proximaFecha,
                categoria: categoria,
                metodoPago: metodoPago,
                frecuencia: frecuencia,
                diaMes: diaMes,
                diaSemana: diaSemana
            )
        }

        guard ok else { return }
        if let onSaved {
            onSaved()
        } else {
            dismiss()
        }
    }

    private func aplicarSeleccionInicial() {
        guard let existingExpense else { return }
        guard nombreServicio.isEmpty && monto.isEmpty else { return }

        nombreServicio = existingExpense.descripcion
        monto = MoneyInput.format(existingExpense.monto)
        proximaFecha = existingExpense.nextChargeDate ?? existingExpense.fechaInicio
        ciclo = existingExpense.frecuencia == .semanal ? .semanal : .mensual
        metodoPago = Self.metodoPagoLocal(from: existingExpense.metodoPago)
        seleccionado = Self.providerMatch(for: existingExpense.descripcion)
    }

    // MARK: - Helpers

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

    private func iconoCircular(_ nombre: String, color: Color) -> some View {
        Image(systemName: nombre)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppTheme.primaryText)
            .frame(width: 28, height: 28)
            .background(color.opacity(0.85), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formatear(_ valor: Double) -> String {
        MoneyInput.format(valor)
    }

    private func infoCard(icon: String, color: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(tarjetaFondo)
    }

    private static func weekdayNumber(for date: Date) -> Int {
        let current = Calendar.current.component(.weekday, from: date)
        return current == 1 ? 7 : current - 1
    }

    private static func metodoPagoLocal(from remote: ExpensePaymentMethod) -> MetodoPago {
        let lookup = remote.nombre.normalizedLookupKey
        if lookup.contains("debito") { return .debito }
        if lookup.contains("credito") { return .credito }
        if lookup.contains("transfer") { return .transferencia }
        return .efectivo
    }

    private static func providerMatch(for descripcion: String) -> Provider? {
        let lookup = descripcion.normalizedLookupKey
        return Provider.allCases.first { provider in
            let providerLookup = provider.nombre.normalizedLookupKey
            return providerLookup == lookup || providerLookup.contains(lookup) || lookup.contains(providerLookup)
        }
    }
}

#Preview {
    AddSubscriptionView()
        .environment(ExpenseStore())
}
