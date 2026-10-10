import SwiftUI

struct ExpensesListView: View {
    private enum RecurrenceFilter: String, CaseIterable, Identifiable {
        case all
        case recurring
        case oneTime

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "Todos"
            case .recurring:
                return "Recurrentes"
            case .oneTime:
                return "Puntuales"
            }
        }
    }

    private enum ExpenseSheet: Identifiable {
        case create
        case detail(Expense)
        case edit(Expense)

        var id: String {
            switch self {
            case .create:
                return "create"
            case let .detail(expense):
                return "detail-\(expense.id)"
            case let .edit(expense):
                return "edit-\(expense.id)"
            }
        }
    }

    @Environment(ExpenseStore.self) private var store

    private static let cal = Calendar.current
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()
    private static let spanishWeekdaySymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.weekdaySymbols
    }()

    @State private var mesActual: Date = ExpensesListView.inicioMes(Date())
    @State private var recurrenceFilter: RecurrenceFilter = .all
    @State private var selectedMethodID: Int? = nil
    @State private var searchText = ""
    @State private var showsFilters = false
    @State private var presentedExpenseSheet: ExpenseSheet?
    @State private var expenseToDelete: Expense?
    @State private var snapshot = ExpensesListSnapshot.placeholder(monthStart: ExpensesListView.inicioMes(Date()))

    private static func inicioMes(_ d: Date) -> Date {
        let comps = cal.dateComponents([.year, .month], from: d)
        return cal.date(from: comps) ?? d
    }

    private var cleanSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var puedeAvanzar: Bool {
        mesActual < ExpensesListView.inicioMes(Date())
    }

    var body: some View {
        ZStack {
            fondo.ignoresSafeArea()

            List {
                // El bloque va siempre, también en un mes sin gastos: además del
                // total lleva la navegación de mes, así que ocultarlo dejaría
                // al usuario sin forma de volver.
                sectionRow {
                    totalCard
                }

                if store.isLoadingExpenses && store.gastos.isEmpty {
                    sectionRow {
                        loadingCard
                    }
                } else {
                    sectionRow {
                        filtrosCard
                    }

                    if snapshot.monthExpenses.isEmpty {
                        sectionRow {
                            vacio
                        }
                    } else {
                        ForEach(snapshot.feedItems) { item in
                            switch item {
                            case let .day(date, totalDia):
                                sectionRow {
                                    dayMarker(date, total: totalDia)
                                }
                            case let .expense(gasto):
                                expenseRow(gasto)
                            }
                        }
                    }
                }

                bottomSafeRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .tracksScrollChrome()
            .floatingTabBarInset()
            .environment(\.defaultMinListRowHeight, 1)
            .refreshable {
                await store.loadExpenses(force: true)
            }

        }
        .task {
            await store.loadCatalogsIfNeeded()
            await store.loadExpensesIfNeeded()
            rebuildSnapshot()
        }
        .onChange(of: store.gastos) {
            rebuildSnapshot()
        }
        .onChange(of: mesActual) {
            rebuildSnapshot()
        }
        .onChange(of: recurrenceFilter) {
            rebuildSnapshot()
        }
        .onChange(of: selectedMethodID) {
            rebuildSnapshot()
        }
        .onChange(of: searchText) {
            rebuildSnapshot()
        }
        .sheet(item: $presentedExpenseSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .create:
                    AddExpenseView {
                        presentedExpenseSheet = nil
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        editSheetHeader
                            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                    }
                case let .detail(expense):
                    ExpenseDetailSheet(
                        expense: expense,
                        onEdit: { presentedExpenseSheet = .edit(expense) },
                        onDelete: { performDeleteExpenseAndDismiss(expense) }
                    )
                case let .edit(expense):
                    AddExpenseView(editingExpense: expense) {
                        presentedExpenseSheet = nil
                    }
                    .safeAreaInset(edge: .top, spacing: 0) {
                        editSheetHeader
                            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                    }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .alert("Eliminar gasto", isPresented: deleteExpenseAlertBinding) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive) {
                let expense = expenseToDelete
                expenseToDelete = nil
                guard let expense else { return }
                Task {
                    await store.deleteExpense(id: expense.id)
                }
            }
        } message: {
            Text(deleteExpenseMessage)
        }
    }

    private var activeFilterCount: Int {
        (recurrenceFilter == .all ? 0 : 1) + (selectedMethodID == nil ? 0 : 1)
    }

    /// Buscador siempre visible y píldoras bajo demanda.
    ///
    /// Las dos filas de píldoras ocupaban ~90pt fijos antes del primer gasto,
    /// aunque casi nunca se usen. El contador del botón dice cuántos filtros
    /// hay puestos sin necesidad de desplegarlas.
    private var filtrosCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                searchField
                filtersToggle
            }

            if showsFilters {
                filterPillRows
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
    }

    private var filtersToggle: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                showsFilters.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13, weight: .bold))
                if activeFilterCount > 0 {
                    Text("\(activeFilterCount)")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(AppTheme.accent))
                }
            }
            .foregroundStyle(showsFilters || activeFilterCount > 0 ? AppTheme.accent : AppTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(
                Capsule()
                    .fill(AppTheme.controlSurface)
                    .overlay(Capsule().strokeBorder(
                        showsFilters || activeFilterCount > 0 ? AppTheme.accent.opacity(0.4) : AppTheme.border,
                        lineWidth: 1
                    ))
            )
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Filtros")
        .accessibilityValue(activeFilterCount == 0 ? "Sin filtros" : "\(activeFilterCount) activos")
    }

    private var filterPillRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecurrenceFilter.allCases) { filter in
                        filterPill(
                            title: filter.title,
                            isSelected: recurrenceFilter == filter
                        ) {
                            recurrenceFilter = filter
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterPill(
                        title: "Todos los pagos",
                        isSelected: selectedMethodID == nil
                    ) {
                        selectedMethodID = nil
                    }

                    ForEach(store.metodosPago, id: \.id) { metodo in
                        filterPill(
                            title: metodo.shortLabel,
                            icon: metodo.icono,
                            isSelected: selectedMethodID == metodo.id
                        ) {
                            selectedMethodID = metodo.id
                        }
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.tertiaryText)
            TextField("Buscar gasto", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
            if !searchText.isEmpty { clearSearchButton }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(
            Capsule()
                .fill(AppTheme.insetSurface)
                .overlay(Capsule().stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }

    private var clearSearchButton: some View {
        Button {
            searchText = ""
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Limpiar búsqueda")
    }

    private func sectionRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func expenseRow(_ gasto: Expense) -> some View {
        Button {
            presentedExpenseSheet = .detail(gasto)
        } label: {
            fila(gasto)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 4, leading: 24, bottom: 4, trailing: 24))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                presentedExpenseSheet = .edit(gasto)
            } label: {
                nativeSwipeIcon("pencil", tint: AppTheme.accent)
            }
            .tint(AppTheme.backgroundBottom)
            .accessibilityLabel("Editar")

            Button(role: .destructive) {
                expenseToDelete = gasto
            } label: {
                nativeSwipeIcon("trash", tint: AppTheme.negative)
            }
            .tint(AppTheme.backgroundBottom)
            .accessibilityLabel("Eliminar")
        }
    }

    private var editSheetHeader: some View {
        HStack {
            AppCircleButton(icon: "xmark", label: "Cerrar edición") {
                presentedExpenseSheet = nil
            }

            Spacer()
        }
    }

    private var bottomSafeRow: some View {
        Color.clear
            .frame(height: AppScreenMetrics.contentBottomPadding)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func cambiarMes(_ delta: Int) {
        guard let nuevo = Self.cal.date(byAdding: .month, value: delta, to: mesActual) else { return }
        let inicioNuevoMes = ExpensesListView.inicioMes(nuevo)
        guard inicioNuevoMes <= ExpensesListView.inicioMes(Date()) else { return }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            mesActual = inicioNuevoMes
        }
    }

    private func matchesRecurrence(_ gasto: Expense) -> Bool {
        switch recurrenceFilter {
        case .all:
            return true
        case .recurring:
            return gasto.isRecurrent
        case .oneTime:
            return !gasto.isRecurrent
        }
    }

    private func matchesPaymentMethod(_ gasto: Expense) -> Bool {
        selectedMethodID == nil || gasto.metodoPagoId == selectedMethodID
    }

    private func matchesSearch(_ gasto: Expense, query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return searchTokens(for: gasto)
            .contains { $0.localizedStandardContains(query) }
    }

    private func searchTokens(for gasto: Expense) -> [String] {
        [
            gasto.descripcion,
            gasto.categoria.nombre,
            gasto.metodoPago.nombre,
            gasto.metodoPago.shortLabel,
            formatear(gasto.monto),
            headerFecha(Self.cal.startOfDay(for: gasto.fecha))
        ]
    }

    /// Navegación de mes, centrada sobre el total.
    private var selectorMesInline: some View {
        HStack(spacing: 6) {
            botonMesInline(icono: "chevron.left", label: "Mes anterior", habilitado: true) { cambiarMes(-1) }

            Text(nombreMes(mesActual))
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(minWidth: 128)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.15), value: mesActual)

            botonMesInline(icono: "chevron.right", label: "Mes siguiente", habilitado: puedeAvanzar) { cambiarMes(1) }
        }
    }

    private func botonMesInline(icono: String, label: String, habilitado: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Image(systemName: icono)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(habilitado ? AppTheme.primaryText : AppTheme.placeholderText)
                .frame(width: 32, height: 32)
                .background(Circle().fill(AppTheme.controlSurface).opacity(habilitado ? 1 : 0.5))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable(scale: 0.86))
        .disabled(!habilitado)
        .accessibilityLabel(label)
    }

    /// Total del mes: sin recuadro y centrado, igual que la entrada de monto.
    ///
    /// Era un bloque oscuro que pesaba lo mismo que una tarjeta más; siendo la
    /// cifra que resume la pantalla, manda mejor por tamaño que por caja.
    private var totalCard: some View {
        VStack(spacing: 12) {
            selectorMesInline

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("$")
                    .font(.system(size: 26, weight: .semibold, design: .default))
                    .foregroundStyle(AppTheme.accent)
                Text(snapshot.total, format: .number.precision(.fractionLength(2)))
                    .font(.system(size: 50, weight: .bold, design: .default))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: snapshot.total))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack(spacing: 6) {
                Image(systemName: "arrow.down.right")
                    .font(.caption2.bold())
                Text("\(snapshot.monthExpenses.count) movimientos registrados")
                    .font(.caption.weight(.semibold))
                    .contentTransition(.numericText(value: Double(snapshot.monthExpenses.count)))
            }
            .foregroundStyle(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func dayMarker(_ fecha: Date, total: Double) -> some View {
        HStack(spacing: 10) {
            Text(headerFecha(fecha))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("$\(formatear(total))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .fixedSize(horizontal: true, vertical: false)

            Rectangle()
                .fill(AppTheme.border)
                .frame(height: 1)
        }
    }

    private func fila(_ gasto: Expense) -> some View {
        HStack(alignment: .center, spacing: 13) {
            CategoryGlyph(categoria: gasto.categoria, size: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(gasto.descripcion)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 5) {
                    Text(gasto.categoria.nombre)
                    Text(verbatim: "·")
                        .foregroundStyle(AppTheme.tertiaryText)
                    Text(gasto.metodoPago.shortLabel)
                    if gasto.isRecurrent {
                        Image(systemName: "repeat")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 10)

            Text("−$\(formatear(gasto.monto))")
                .font(AppTheme.number(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 10)
    }

    private func deleteExpense(_ gasto: Expense) {
        expenseToDelete = gasto
    }

    private func deleteExpenseAndDismiss(_ gasto: Expense) {
        presentedExpenseSheet = nil
        deleteExpense(gasto)
    }

    private func performDeleteExpenseAndDismiss(_ gasto: Expense) {
        presentedExpenseSheet = nil
        Task {
            await store.deleteExpense(id: gasto.id)
        }
    }

    private func filterPill(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .black : AppTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Capsule().fill(isSelected ? AppTheme.accent : AppTheme.controlSurface))
            .overlay(Capsule().stroke(isSelected ? Color.clear : AppTheme.strongBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)
                .scaleEffect(1.1)
            Text("Cargando gastos")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
            Text("Preparando tu lista de movimientos.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 48)
        .background(tarjetaFondo)
    }

    private var vacio: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(AppTheme.placeholderText)
            Text(emptyTitle)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
            Text(mensajeVacio)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            if shouldShowCreateExpenseCTA {
                Button {
                    presentedExpenseSheet = .create
                } label: {
                    Label("Registrar gasto", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 18)
                        .frame(height: 44)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.top, 60)
        .padding(.bottom, 40)
    }

    private var emptyTitle: String {
        isFilteringExpenses && !snapshot.monthExpensesBase.isEmpty ? "Sin coincidencias" : "Sin gastos en este mes"
    }

    private var isFilteringExpenses: Bool {
        !cleanSearchText.isEmpty || selectedMethodID != nil || recurrenceFilter != .all
    }

    private var shouldShowCreateExpenseCTA: Bool {
        !isFilteringExpenses && store.hasBaseURLConfigured && store.canAccessProtectedEndpoints
    }

    private var mensajeVacio: String {
        if isFilteringExpenses && !snapshot.monthExpensesBase.isEmpty {
            return "Prueba con otro nombre, categoría, método o monto."
        }
        if !store.hasBaseURLConfigured {
            return "Configura tu conexión para empezar a ver tus movimientos."
        }
        if !store.canAccessProtectedEndpoints {
            return "Inicia sesión para ver tus gastos."
        }
        return "Cambia de mes o registra un gasto nuevo cuando quieras."
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

    private var tarjetaFondo: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(AppTheme.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }

    private func nombreMes(_ d: Date) -> String {
        let components = Self.cal.dateComponents([.year, .month], from: d)
        guard
            let year = components.year,
            let month = components.month,
            Self.spanishMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(Self.spanishMonthSymbols[month - 1]) \(year)".capitalized
    }

    private func headerFecha(_ fecha: Date) -> String {
        if Self.cal.isDateInToday(fecha) { return "Hoy" }
        if Self.cal.isDateInYesterday(fecha) { return "Ayer" }
        let components = Self.cal.dateComponents([.weekday, .day, .month], from: fecha)
        guard
            let weekday = components.weekday,
            let day = components.day,
            let month = components.month,
            Self.spanishWeekdaySymbols.indices.contains(weekday - 1),
            Self.spanishMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(Self.spanishWeekdaySymbols[weekday - 1]), \(day) de \(Self.spanishMonthSymbols[month - 1])".capitalized
    }

    private func formatear(_ valor: Double) -> String {
        MoneyInput.format(valor)
    }

    private func nativeSwipeIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .font(.system(size: 21, weight: .bold))
            .frame(width: 30, height: 30)
    }

    private var deleteExpenseMessage: String {
        guard let expenseToDelete else {
            return "Este movimiento se eliminará de tu historial."
        }
        return "\"\(expenseToDelete.descripcion)\" se eliminará de tu historial."
    }

    private var deleteExpenseAlertBinding: Binding<Bool> {
        Binding(
            get: { expenseToDelete != nil },
            set: { if !$0 { expenseToDelete = nil } }
        )
    }

    private func rebuildSnapshot() {
        let query = cleanSearchText
        // El total vive dentro del snapshot, así que la animación tiene que
        // envolver esta asignación: si sólo se anima `mesActual`, la cifra
        // cambia de golpe y no rueda.
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            snapshot = ExpensesListSnapshot(
                expenses: store.gastos,
                monthStart: mesActual,
                calendar: Self.cal,
                recurrenceMatches: matchesRecurrence,
                paymentMatches: matchesPaymentMethod,
                searchMatches: { matchesSearch($0, query: query) }
            )
        }
    }
}

private struct ExpenseDetailSheet: View {
    let expense: Expense
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showsDeleteConfirmation = false

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "EEEE d 'de' MMMM, yyyy"
        return formatter
    }()

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    metadataCard
                    actionRow
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, 28)
                .padding(.bottom, 36)
            }
        }
        .alert("Eliminar gasto", isPresented: $showsDeleteConfirmation) {
            Button("Cancelar", role: .cancel) { }
            Button("Eliminar", role: .destructive, action: onDelete)
        } message: {
            Text("\"\(expense.descripcion)\" se eliminará de tu historial.")
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            CategoryGlyph(
                categoria: expense.categoria,
                size: 58,
                tint: AppTheme.accent,
                background: AppTheme.accent.opacity(0.16),
                borderColor: AppTheme.accent.opacity(0.28)
            )

            VStack(spacing: 7) {
                Text(expense.descripcion)
                    .font(.system(size: 24, weight: .bold, design: .default))
                    .foregroundStyle(AppTheme.onStatement)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Text(expense.monto, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.system(size: 44, weight: .bold, design: .default))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.onStatement)
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
        .background(AppTheme.statementBackground(cornerRadius: 32))
    }

    private var metadataCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: expense.categoria.icono, title: "Categoría", value: expense.categoria.nombre, tint: AppTheme.accent)
            ExpenseFormDivider()
            detailRow(icon: expense.metodoPago.icono, title: "Método", value: expense.metodoPago.shortLabel, tint: AppTheme.secondaryAccent)
            ExpenseFormDivider()
            detailRow(icon: "calendar", title: "Fecha", value: Self.dateFormatter.string(from: expense.fecha).capitalized, tint: AppTheme.accent)
            if expense.isRecurrent {
                ExpenseFormDivider()
                detailRow(icon: "repeat", title: "Tipo", value: "Recurrente", tint: AppTheme.accent)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }

    private func detailRow(icon: String, title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 13) {
            ExpenseIconBadge(systemName: icon, color: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            detailActionButton(
                title: "Editar",
                systemImage: "pencil",
                iconTint: AppTheme.accent,
                action: onEdit
            )

            detailActionButton(
                title: "Eliminar",
                systemImage: "trash",
                iconTint: AppTheme.negative,
                role: .destructive,
                action: { showsDeleteConfirmation = true }
            )
            .accessibilityLabel("Eliminar gasto")
        }
    }

    private func detailActionButton(
        title: String,
        systemImage: String,
        iconTint: Color,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconTint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.strongBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let store = ExpenseStore()
    let categoriaComida = Categoria(id: 1, nombre: "Alimentación")
    let categoriaTransporte = Categoria(id: 2, nombre: "Transporte")
    let pagoEfectivo = ExpensePaymentMethod(id: 1, nombre: "Efectivo")
    let pagoTarjeta = ExpensePaymentMethod(id: 2, nombre: "Tarjeta")

    store.add(Expense(descripcion: "Almuerzo", monto: 12.5, fecha: Date(), categoria: categoriaComida, metodoPago: pagoEfectivo))
    store.add(Expense(descripcion: "Uber", monto: 8.3, fecha: Date(), categoria: categoriaTransporte, metodoPago: pagoTarjeta))

    return ExpensesListView()
        .environment(store)
}
