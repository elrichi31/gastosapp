import SwiftUI

/// Movimientos del mes, según el canvas «Gastos»: total con comparativa, barras
/// diarias, filtros por categoría y etiqueta, y la lista agrupada por día.
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

    /// Etiqueta interna con la que el backend marca lo importado del correo.
    /// No es del usuario: se muestra como origen, no como etiqueta.
    private static let emailTag = "auto"

    /// Encabezado que se desplaza con el contenido (título de Gastos).
    private let header: AnyView?

    init(header: AnyView? = nil) {
        self.header = header
    }

    @Environment(ExpenseStore.self) private var store

    private static let cal = Calendar.current
    @State private var mesActual: Date = ExpensesListView.inicioMes(Date())
    @State private var recurrenceFilter: RecurrenceFilter = .all
    @State private var selectedMethodID: Int? = nil
    @State private var originFilter = "all"
    @State private var selectedCategoryID: Int?
    @State private var selectedTags: Set<String> = []
    @State private var localSearchText = ""
    @Environment(AppNavigator.self) private var navigator: AppNavigator?

    /// El texto vive en el navegador para que el buscador de la barra superior
    /// filtre esta lista; sin navegador (vistas previas) es local.
    private var searchText: String {
        get { navigator?.expenseQuery ?? localSearchText }
        nonmutating set {
            if let navigator { navigator.expenseQuery = newValue } else { localSearchText = newValue }
        }
    }
    @State private var showsFilters = false
    @State private var showsTags = false
    @State private var presentedExpenseSheet: ExpenseSheet?
    @State private var expenseToDelete: Expense?
    @State private var snapshot = ExpensesListSnapshot.placeholder(monthStart: ExpensesListView.inicioMes(Date()))
    @AppStorage("gastos.swipeTipDismissed") private var swipeTipDismissed = false
    /// Hasta la primera carga, la lista vacía no significa «sin gastos».
    @State private var hasLoaded = false
    /// Día tocado en el gráfico de barras; arriba se muestra su total.
    @State private var selectedChartDay: Int?

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

    private var isCurrentMonth: Bool {
        mesActual == ExpensesListView.inicioMes(Date())
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            List {
                if let header {
                    sectionRow(insets: EdgeInsets(top: 4, leading: 20, bottom: 8, trailing: 20)) { header }
                }

                if navigator == nil {
                    sectionRow { searchField }
                }

                // El bloque va siempre, también en un mes sin gastos: además del
                // total lleva la navegación de mes, así que ocultarlo dejaría
                // al usuario sin forma de volver.
                sectionRow { totalBlock }

                if (!hasLoaded || store.isLoadingExpenses) && snapshot.monthExpensesBase.isEmpty {
                    sectionRow { loadingState }
                } else if snapshot.monthExpensesBase.isEmpty {
                    sectionRow { emptyMonthState }
                } else {
                    sectionRow(insets: EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0)) { filterChips }

                    if showsTags && !monthTags.isEmpty {
                        sectionRow(insets: EdgeInsets(top: 2, leading: 20, bottom: 6, trailing: 20)) { tagCloud }
                    }

                    if showsFilters {
                        sectionRow { filterPillRows }
                    }

                    if snapshot.monthExpenses.isEmpty {
                        sectionRow { noResultsState }
                    } else {
                        if !swipeTipDismissed {
                            sectionRow { swipeTip }
                        }

                        ForEach(snapshot.feedItems) { item in
                            switch item {
                            case let .day(date, totalDia):
                                sectionRow(insets: EdgeInsets(top: 16, leading: 20, bottom: 4, trailing: 20)) {
                                    dayHeader(date, total: totalDia)
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
            .scrollDismissesKeyboard(.interactively)
            .tracksScrollChrome()
            .floatingTabBarInset()
            .environment(\.defaultMinListRowHeight, 1)
            .animation(AppMotion.fade, value: hasLoaded)
            .refreshable {
                await store.loadExpenses(force: true)
            }
        }
        .task {
            await store.loadCatalogsIfNeeded()
            await store.loadExpensesIfNeeded()
            rebuildSnapshot()
            hasLoaded = true
        }
        .onChange(of: store.gastos) { rebuildSnapshot() }
        .onChange(of: mesActual) {
            selectedCategoryID = nil
            rebuildSnapshot()
        }
        .onChange(of: recurrenceFilter) { rebuildSnapshot() }
        .onChange(of: selectedMethodID) { rebuildSnapshot() }
        .onChange(of: originFilter) { rebuildSnapshot() }
        .onChange(of: selectedCategoryID) { rebuildSnapshot() }
        .onChange(of: selectedTags) { rebuildSnapshot() }
        .onChange(of: searchText) { rebuildSnapshot(animated: false) }
        .sheet(item: $presentedExpenseSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .create:
                    AddExpenseView {
                        presentedExpenseSheet = nil
                    }
                    .safeAreaInset(edge: .top, spacing: 0) { sheetHeader("Nuevo gasto") }
                case let .detail(expense):
                    ExpenseDetailSheet(
                        expense: expense,
                        onClose: { presentedExpenseSheet = nil },
                        onEdit: { presentedExpenseSheet = .edit(expense) },
                        onDelete: { performDeleteExpenseAndDismiss(expense) }
                    )
                case let .edit(expense):
                    AddExpenseView(editingExpense: expense) {
                        presentedExpenseSheet = nil
                    }
                    .safeAreaInset(edge: .top, spacing: 0) { sheetHeader("Editar gasto") }
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

    // MARK: - Búsqueda

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
            TextField("Buscar", text: Binding(get: { searchText }, set: { searchText = $0 }), prompt: Text("Buscar").foregroundStyle(AppTheme.tertiaryText))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .accessibilityLabel("Buscar gastos")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppTheme.primaryText.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(
            Capsule()
                .fill(AppTheme.surface)
                .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
        )
    }

    // MARK: - Total del mes

    private var isFiltering: Bool {
        !cleanSearchText.isEmpty || selectedCategoryID != nil || !selectedTags.isEmpty
            || selectedMethodID != nil || recurrenceFilter != .all || originFilter != "all"
    }

    private var scopeLabel: String {
        guard isFiltering else { return "Todos los gastos" }
        let count = snapshot.monthExpenses.count
        return count == 1 ? "1 gasto" : "\(count) gastos"
    }

    /// Tramo del mes anterior con el que se compara: hasta hoy en el mes en
    /// curso, el mes entero si se mira un mes cerrado.
    private var previousRange: Range<Date>? {
        guard let previousStart = Self.cal.date(byAdding: .month, value: -1, to: mesActual) else { return nil }
        guard isCurrentMonth else { return previousStart..<mesActual }
        let day = Self.cal.component(.day, from: Date())
        let previousDays = Self.cal.range(of: .day, in: .month, for: previousStart)?.count ?? 30
        let end = Self.cal.date(byAdding: .day, value: min(day, previousDays), to: previousStart) ?? mesActual
        return previousStart..<end
    }

    private var previousComparable: (total: Double, label: String)? {
        guard snapshot.previousTotal > 0,
              let previousStart = Self.cal.date(byAdding: .month, value: -1, to: mesActual)
        else { return nil }
        let previousName = nombreMesCorto(previousStart)
        let label = isCurrentMonth
            ? "que \(previousName) al día \(Self.cal.component(.day, from: Date()))"
            : "que \(previousName)"
        return (snapshot.previousTotal, label)
    }

    private var totalParts: (whole: String, cents: String) {
        let total = snapshot.total
        let whole = Double(Int(total)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = Int((total * 100).rounded()) % 100
        return (whole, (Locale.current.decimalSeparator ?? ".") + String(format: "%02d", cents))
    }

    private var totalBlock: some View {
        let parts = totalParts
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                monthStepper

                (Text(parts.whole)
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                 + Text(parts.cents)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText))
                    .tracking(-1.5)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText(value: snapshot.total))
                    .accessibilityLabel(snapshot.total.formatted(.currency(code: "USD")))

                HStack(spacing: 8) {
                    if isFiltering {
                        Text("con los filtros activos")
                    } else if let previous = previousComparable {
                        HomeSpendDelta(percent: HomeMonthPulse.change(from: previous.total, to: snapshot.total), style: .pill)
                        Text(previous.label)
                    } else {
                        Text(snapshot.monthExpenses.count == 1 ? "1 movimiento" : "\(snapshot.monthExpenses.count) movimientos")
                    }
                }
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppTheme.tertiaryText)
            }

            if !snapshot.monthExpensesBase.isEmpty {
                dailyBars
            }
        }
        .padding(.top, 6)
    }

    private var monthStepper: some View {
        HStack(spacing: 2) {
            stepButton(icon: "chevron.left", label: "Mes anterior", enabled: true) { cambiarMes(-1) }
            Text("\(nombreMes(mesActual)) · \(scopeLabel)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)
                .contentTransition(.numericText())
                .lineLimit(1)
            stepButton(icon: "chevron.right", label: "Mes siguiente", enabled: puedeAvanzar) { cambiarMes(1) }
        }
        .padding(.leading, -10)
    }

    private func stepButton(icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.secondaryText : AppTheme.placeholderText)
                .frame(width: 32, height: 32)
                .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.86))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    /// Una barra por día: hoy con el acento, los días por venir como un punto.
    ///
    /// Como en Análisis, al tocar o arrastrar sobre las barras se elige un día
    /// y arriba sale su total. La lista de abajo no se filtra.
    private var dailyBars: some View {
        let days = Self.cal.range(of: .day, in: .month, for: mesActual)?.count ?? 30
        let today = isCurrentMonth ? Self.cal.component(.day, from: Date()) : days
        let byDay = snapshot.dayTotals
        let maxValue = max(byDay.values.max() ?? 0, 1)
        let monthName = nombreMesCorto(mesActual)

        return VStack(alignment: .leading, spacing: 8) {
            Text(chartReadout(monthName: monthName))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(selectedChartDay == nil ? AppTheme.tertiaryText : AppTheme.primaryText)
                .frame(minHeight: 18, alignment: .leading)
                .contentTransition(.numericText())

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(1...days, id: \.self) { day in
                    let value = byDay[day] ?? 0
                    let isFuture = day > today
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barFill(day: day, today: today, isFuture: isFuture))
                        .frame(height: isFuture ? 4 : max(4, CGFloat(value / maxValue) * 90))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
            .overlay {
                GeometryReader { proxy in
                    Color.clear
                        .contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let ratio = min(max(value.location.x / max(proxy.size.width, 1), 0), 0.9999)
                                    let day = min(Int(ratio * Double(days)) + 1, today)
                                    if day != selectedChartDay {
                                        withAnimation(AppMotion.fade) { selectedChartDay = day }
                                    }
                                }
                        )
                }
            }
            .sensoryFeedback(.selection, trigger: selectedChartDay)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gasto diario de \(nombreMes(mesActual))")
            .accessibilityValue(chartReadout(monthName: monthName))
            .accessibilityAdjustableAction { direction in
                let current = selectedChartDay ?? today
                switch direction {
                case .increment: selectedChartDay = min(current + 1, today)
                case .decrement: selectedChartDay = max(current - 1, 1)
                @unknown default: break
                }
            }

            HStack {
                Text("1 \(monthName)")
                Spacer()
                Text("15 \(monthName)")
                Spacer()
                Text("\(days) \(monthName)")
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.tertiaryText)
            .accessibilityHidden(true)
        }
        .onChange(of: mesActual) { selectedChartDay = nil }
    }

    private func barFill(day: Int, today: Int, isFuture: Bool) -> Color {
        if day == selectedChartDay { return AppTheme.primaryText }
        if isCurrentMonth && day == today { return selectedChartDay == nil ? AppTheme.accent : AppTheme.accent.opacity(0.5) }
        return isFuture ? AppTheme.primaryText.opacity(0.06) : AppTheme.primaryText.opacity(0.14)
    }

    private func chartReadout(monthName: String) -> String {
        guard let day = selectedChartDay else { return "Toca el gráfico para ver cada día" }
        let count = snapshot.dayCounts[day] ?? 0
        guard count > 0 else { return "\(day) \(monthName) · sin gastos" }
        let total = (snapshot.dayTotals[day] ?? 0).formatted(.currency(code: "USD").precision(.fractionLength(2)))
        return "\(day) \(monthName) · \(total) · \(count == 1 ? "1 gasto" : "\(count) gastos")"
    }

    // MARK: - Filtros

    private var monthCategories: [Categoria] { snapshot.categories }
    private var monthTags: [String] { snapshot.tags }

    private var advancedFilterCount: Int {
        (originFilter == "all" ? 0 : 1) + (recurrenceFilter == .all ? 0 : 1) + (selectedMethodID == nil ? 0 : 1)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(title: "Todos", color: nil, isSelected: selectedCategoryID == nil) {
                    selectedCategoryID = nil
                }
                ForEach(monthCategories, id: \.id) { category in
                    categoryChip(title: category.nombre, color: category.color, isSelected: selectedCategoryID == category.id) {
                        selectedCategoryID = selectedCategoryID == category.id ? nil : category.id
                    }
                }

                if !monthTags.isEmpty {
                    accentChip(isOn: showsTags || !selectedTags.isEmpty) {
                        withAnimation(AppMotion.standard) { showsTags.toggle() }
                    } label: {
                        Text("#").fontWeight(.bold).foregroundStyle(AppTheme.accent)
                        Text(selectedTags.isEmpty ? "Etiquetas" : "Etiquetas · \(selectedTags.count)")
                            .contentTransition(.numericText())
                    }
                    .accessibilityLabel(selectedTags.isEmpty ? "Etiquetas" : "Etiquetas, \(selectedTags.count) activas")
                }

                accentChip(isOn: showsFilters || advancedFilterCount > 0) {
                    withAnimation(AppMotion.standard) { showsFilters.toggle() }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease").font(.system(size: 13, weight: .bold))
                    Text(advancedFilterCount == 0 ? "Filtros" : "Filtros · \(advancedFilterCount)")
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
    }

    private func categoryChip(title: String, color: Color?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button { withAnimation(AppMotion.standard, action) } label: {
            HStack(spacing: 8) {
                if let color {
                    Circle().fill(color).frame(width: 8, height: 8)
                }
                Text(title).lineLimit(1)
            }
            .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.primaryText)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Capsule().fill(isSelected ? AppTheme.primaryText : AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable(scale: 0.95))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func accentChip<Label: View>(
        isOn: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { label() }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isOn ? AppTheme.accent : AppTheme.secondaryText)
                .padding(.horizontal, 14)
                .frame(height: 40)
                .background(Capsule().fill(isOn ? AppTheme.accent.opacity(0.18) : AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable(scale: 0.95))
    }

    private var tagCloud: some View {
        ChipFlowLayout(spacing: 6) {
            ForEach(monthTags, id: \.self) { tag in
                tagChip(tag, height: 32, fontSize: 14, weight: .semibold)
            }
        }
        .transition(AppMotion.reveal)
    }

    private func tagChip(_ tag: String, height: CGFloat, fontSize: CGFloat, weight: Font.Weight) -> some View {
        let isOn = selectedTags.contains(tag)
        return Button {
            withAnimation(AppMotion.standard) {
                if isOn { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
            }
        } label: {
            Text("#\(tag)")
                .font(.system(size: fontSize, weight: weight))
                .foregroundStyle(isOn ? AppTheme.onAccent : AppTheme.secondaryText)
                .padding(.horizontal, height > 24 ? 12 : 8)
                .frame(height: height)
                .background(Capsule().fill(isOn ? AppTheme.accent : AppTheme.popoverSurface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Etiqueta \(tag)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var filterPillRows: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Origen", selection: $originFilter.animation(AppMotion.standard)) {
                Text("Todos").tag("all")
                Text("Manual").tag("manual")
                Text("Correo").tag("email")
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecurrenceFilter.allCases) { filter in
                        filterPill(title: filter.title, isSelected: recurrenceFilter == filter) {
                            recurrenceFilter = filter
                        }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterPill(title: "Todos los pagos", isSelected: selectedMethodID == nil) {
                        selectedMethodID = nil
                    }
                    ForEach(store.metodosPago, id: \.id) { metodo in
                        filterPill(title: metodo.shortLabel, icon: metodo.icono, isSelected: selectedMethodID == metodo.id) {
                            selectedMethodID = metodo.id
                        }
                    }
                }
            }
        }
        .transition(AppMotion.reveal)
    }

    private func filterPill(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button { withAnimation(AppMotion.standard, action) } label: {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.primaryText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(isSelected ? AppTheme.primaryText : AppTheme.popoverSurface))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var swipeTip: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(AppTheme.accent.opacity(0.16)))
                .accessibilityHidden(true)
            (Text("Desliza un gasto hacia la izquierda para ")
             + Text("editarlo").fontWeight(.semibold).foregroundColor(AppTheme.primaryText)
             + Text(" o ")
             + Text("eliminarlo").fontWeight(.semibold).foregroundColor(AppTheme.primaryText)
             + Text("."))
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Entendido") {
                withAnimation(AppMotion.standard) { swipeTipDismissed = true }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.accent)
            .frame(minHeight: 40)
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
        )
    }

    // MARK: - Lista

    private func sectionRow<Content: View>(
        insets: EdgeInsets = EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20),
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .listRowInsets(insets)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private func dayHeader(_ fecha: Date, total: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(headerFecha(fecha))
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Text(total.formatted(.currency(code: "USD").precision(.fractionLength(2))))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppTheme.tertiaryText)
        }
    }

    private func expenseRow(_ gasto: Expense) -> some View {
        Button {
            presentedExpenseSheet = .detail(gasto)
        } label: {
            fila(gasto)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Sólo iconos: el texto bajo cada uno sobraba en un hueco tan estrecho.
            // Sin `role: .destructive`: con ese rol iOS anima la fila como borrada
            // al tocar, pero el borrado espera a la confirmación y la fila volvía
            // de golpe. El rojo lo da el `tint`.
            Button {
                expenseToDelete = gasto
            } label: {
                Image(systemName: "trash")
            }
            .tint(AppTheme.negative)
            .accessibilityLabel("Eliminar \(gasto.descripcion)")

            Button {
                presentedExpenseSheet = .edit(gasto)
            } label: {
                Image(systemName: "pencil")
            }
            .tint(AppTheme.tertiaryText)
            .accessibilityLabel("Editar \(gasto.descripcion)")
        }
    }

    private func visibleTags(for gasto: Expense) -> [String] {
        (gasto.tags ?? []).filter { $0 != Self.emailTag }
    }

    private func fila(_ gasto: Expense) -> some View {
        let color = gasto.categoria.color
        let tags = visibleTags(for: gasto)
        return HStack(alignment: .center, spacing: 14) {
            CategoryGlyph(
                categoria: gasto.categoria,
                size: 48,
                tint: color,
                background: color.opacity(0.16),
                isCircular: true
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.descripcion)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(gasto.categoria.nombre) · \(gasto.metodoPago.shortLabel)")
                        .lineLimit(1)
                    if gasto.isRecurrent { badge("Recurrente") }
                    if gasto.foreignTax != nil { badge("Exterior") }
                    if gasto.tags?.contains(Self.emailTag) == true { badge("Correo") }
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.tertiaryText)

                if !tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(tags.prefix(4), id: \.self) { tag in
                            tagChip(tag, height: 22, fontSize: 12, weight: .medium)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 8)

            Text("−\(gasto.monto.formatted(.currency(code: "USD").precision(.fractionLength(2))))")
                .font(.system(size: 16, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .fixedSize()
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 1)
            .background(Capsule().fill(AppTheme.popoverSurface))
            .fixedSize()
    }

    // MARK: - Estados

    /// Esqueleto con la forma de la lista: encabezado de día y filas.
    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 0) {
            SkeletonBlock(width: 90, height: 16)
                .padding(.bottom, 10)
            ForEach(0..<5, id: \.self) { _ in
                HStack(spacing: 14) {
                    SkeletonBlock(width: 48, height: 48, cornerRadius: 24)
                    VStack(alignment: .leading, spacing: 8) {
                        SkeletonBlock(width: 140, height: 14)
                        SkeletonBlock(width: 100, height: 10)
                    }
                    Spacer(minLength: 0)
                    SkeletonBlock(width: 64, height: 16)
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cargando gastos")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private var emptyMonthState: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 72, height: 72)
                .background(Circle().fill(AppTheme.accent.opacity(0.16)))
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(isCurrentMonth ? "Aún no tienes gastos" : "Sin gastos en \(nombreMes(mesActual))")
                    .font(.system(size: 22, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(AppTheme.primaryText)
                Text(emptyMessage)
                    .font(.system(size: 15))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: 280)
            }
            .multilineTextAlignment(.center)
            if canCreateExpense {
                Button {
                    presentedExpenseSheet = .create
                } label: {
                    Text("Agregar gasto")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.pressable(scale: 0.98))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.bottom, 24)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Text("Sin resultados")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Ningún gasto coincide con estos filtros.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
            Button(action: clearFilters) {
                Text("Quitar filtros")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.backgroundTop)
                    .padding(.horizontal, 20)
                    .frame(height: 44)
                    .background(Capsule().fill(AppTheme.primaryText))
            }
            .buttonStyle(.pressable(scale: 0.96))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .multilineTextAlignment(.center)
    }

    private var canCreateExpense: Bool {
        store.hasBaseURLConfigured && store.canAccessProtectedEndpoints
    }

    private var emptyMessage: String {
        if !store.hasBaseURLConfigured {
            return "Configura tu conexión para empezar a ver tus movimientos."
        }
        if !store.canAccessProtectedEndpoints {
            return "Inicia sesión para ver tus gastos."
        }
        return isCurrentMonth
            ? "Registra uno a mano o impórtalos desde los correos de tu banco."
            : "Cambia de mes o registra un gasto nuevo cuando quieras."
    }

    private func clearFilters() {
        withAnimation(AppMotion.standard) {
            searchText = ""
            selectedCategoryID = nil
            selectedTags = []
            selectedMethodID = nil
            recurrenceFilter = .all
            originFilter = "all"
        }
    }

    private func sheetHeader(_ title: String) -> some View {
        FormSheetChrome {
            FormSheetHeader(title: title) { presentedExpenseSheet = nil }
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

    // MARK: - Lógica

    private func cambiarMes(_ delta: Int) {
        guard let nuevo = Self.cal.date(byAdding: .month, value: delta, to: mesActual) else { return }
        let inicioNuevoMes = ExpensesListView.inicioMes(nuevo)
        guard inicioNuevoMes <= ExpensesListView.inicioMes(Date()) else { return }

        withAnimation(AppMotion.standard) {
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

    private func matchesCategoryAndTags(_ gasto: Expense) -> Bool {
        let categoryOK = selectedCategoryID == nil || gasto.categoriaId == selectedCategoryID
        let tagsOK = selectedTags.isEmpty || selectedTags.isSubset(of: Set(gasto.tags ?? []))
        return categoryOK && tagsOK
    }

    private func matchesPaymentMethod(_ gasto: Expense) -> Bool {
        let email = gasto.tags?.contains(Self.emailTag) == true
        let matchesOrigin = originFilter == "all" || (originFilter == "email" ? email : !email)
        return matchesOrigin && (selectedMethodID == nil || gasto.metodoPagoId == selectedMethodID)
    }

    private func matchesSearch(_ gasto: Expense, query: String, matcher: (Expense) -> Bool) -> Bool {
        guard !query.isEmpty else { return true }
        // Las reglas comunes de toda la app, más el día tal como sale en la
        // cabecera de la lista («Hoy», «Ayer»…).
        return matcher(gasto)
            || headerFecha(Self.cal.startOfDay(for: gasto.fecha)).localizedStandardContains(query)
    }

    private func performDeleteExpenseAndDismiss(_ gasto: Expense) {
        presentedExpenseSheet = nil
        Task {
            await store.deleteExpense(id: gasto.id)
        }
    }

    private func nombreMes(_ d: Date) -> String {
        let components = Self.cal.dateComponents([.year, .month], from: d)
        guard
            let year = components.year,
            let month = components.month,
            SpanishCalendar.monthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(SpanishCalendar.monthSymbols[month - 1].capitalized) \(year)"
    }

    private func nombreMesCorto(_ d: Date) -> String {
        d.formatted(.dateTime.month(.abbreviated).locale(Locale(identifier: "es")))
            .replacingOccurrences(of: ".", with: "")
    }

    private func headerFecha(_ fecha: Date) -> String {
        if Self.cal.isDateInToday(fecha) { return "Hoy" }
        if Self.cal.isDateInYesterday(fecha) { return "Ayer" }
        let components = Self.cal.dateComponents([.day, .month], from: fecha)
        guard
            let day = components.day,
            let month = components.month,
            SpanishCalendar.monthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(day) de \(SpanishCalendar.monthSymbols[month - 1])"
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

    /// Recalcula la lista. Al escribir en el buscador va sin animación: animar
    /// la lista entera a cada tecla era lo que la hacía ir a tirones.
    private func rebuildSnapshot(animated: Bool = true) {
        let query = cleanSearchText
        let matcher = ExpenseSearch.matcher(for: query)
        let next = ExpensesListSnapshot(
            expenses: store.gastos,
            monthStart: mesActual,
            previousRange: previousRange,
            calendar: Self.cal,
            visibleTags: visibleTags(for:),
            recurrenceMatches: { matchesRecurrence($0) && matchesCategoryAndTags($0) },
            paymentMatches: matchesPaymentMethod,
            searchMatches: { matchesSearch($0, query: query, matcher: matcher) }
        )
        guard animated else {
            snapshot = next
            return
        }
        // El total vive dentro del snapshot, así que la animación tiene que
        // envolver esta asignación: si sólo se anima `mesActual`, la cifra
        // cambia de golpe y no rueda.
        withAnimation(AppMotion.standard) {
            snapshot = next
        }
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
