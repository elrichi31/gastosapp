import SwiftUI

/// Barra superior del canvas, igual en las cuatro pestañas: cuenta, buscador,
/// notificaciones y gasto nuevo.
///
/// En Gastos el buscador filtra la lista en su sitio (`.filter`); en el resto
/// abre un panel de resultados debajo (`.panel`).
struct AppTopBar: View {
    enum Mode { case panel, filter }

    var mode: Mode = .panel

    @Environment(ExpenseStore.self) private var store
    @Environment(AppNavigator.self) private var navigator
    @Environment(AppInbox.self) private var inbox
    @Environment(\.profileTransitionNamespace) private var profileNamespace
    @FocusState private var searchFocused: Bool

    private var query: Binding<String> {
        Binding(
            get: { mode == .filter ? navigator.expenseQuery : navigator.searchText },
            set: { value in
                if mode == .filter {
                    navigator.expenseQuery = value
                } else {
                    navigator.searchText = value
                    navigator.searchFiltersInPlace = false
                    if navigator.panel != .search { navigator.panel = .search }
                }
            }
        )
    }

    private var isSearching: Bool {
        searchFocused || navigator.panel == .search || (mode == .filter && !navigator.expenseQuery.isEmpty)
    }

    private var initials: String {
        let name = store.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    var body: some View {
        HStack(spacing: 8) {
            if !isSearching {
                Button {
                    navigator.closePanel()
                    navigator.showsProfile = true
                } label: {
                    Text(initials)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .chromeGlass(Circle())
                }
                .buttonStyle(.pressable)
                .profileTransitionSource(profileNamespace)
                .accessibilityLabel("Cuenta: perfil, conexiones y ajustes")
                .transition(AppMotion.pop)
            }

            searchField

            if isSearching {
                Button("Cancelar") {
                    searchFocused = false
                    if mode == .filter { navigator.expenseQuery = "" }
                    navigator.closePanel()
                }
                // Pastilla como el resto de botones de la barra: el texto verde
                // suelto casi no se veía sobre el velo oscuro del panel.
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .chromeGlass(Capsule())
                .contentShape(Capsule())
                .buttonStyle(.pressable)
                .transition(AppMotion.pop)
            } else {
                inboxButton
                    .transition(AppMotion.pop)
                Button {
                    navigator.closePanel()
                    navigator.showsNewExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .chromeGlass(Circle())
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Nuevo gasto")
                .transition(AppMotion.pop)
            }
        }
        // Con Liquid Glass, el buscador y los botones se funden y se
        // transforman al abrir y cerrar la búsqueda.
        .chromeGlassGroup(spacing: 8)
        .animation(AppMotion.standard, value: isSearching)
        .onChange(of: searchFocused) { _, focused in
            // Los dos modos abren el mismo panel; en Gastos sólo sugiere.
            if focused {
                navigator.searchFiltersInPlace = mode == .filter
                navigator.panel = .search
            } else if mode == .filter, navigator.panel == .search {
                // En Gastos las sugerencias sólo valen mientras se escribe: si
                // se baja el teclado y luego se borra el texto, no deben volver
                // a aparecer solas.
                navigator.panel = nil
            }
        }
        .onChange(of: navigator.panel) { _, panel in
            if panel == nil { searchFocused = false }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .accessibilityHidden(true)
            TextField("Buscar", text: query, prompt: Text("Buscar").foregroundStyle(AppTheme.tertiaryText))
                .focused($searchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.primaryText)
                .tint(AppTheme.accent)
                .accessibilityLabel("Buscar gastos")
            if !query.wrappedValue.isEmpty {
                Button {
                    query.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppTheme.primaryText.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .frame(height: 44)
        .chromeGlass(Capsule())
        .contentShape(Capsule())
        .onTapGesture { searchFocused = true }
    }

    private var inboxButton: some View {
        Button {
            navigator.closePanel()
            withAnimation(AppMotion.expand) {
                navigator.showsNotifications = true
            }
        } label: {
            Image(systemName: "bell")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .chromeGlass(Circle())
                .overlay(alignment: .topTrailing) {
                    if inbox.hasUnread {
                        Circle()
                            .fill(AppTheme.negative)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(AppTheme.backgroundTop, lineWidth: 2))
                            .offset(x: -1, y: -1)
                    }
                }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(inbox.unreadCount > 0 ? "Notificaciones, \(inbox.unreadCount) sin leer" : "Notificaciones")
    }
}

private extension View {
    /// El avatar es el origen de la burbuja que se abre en Cuenta.
    @ViewBuilder
    func profileTransitionSource(_ namespace: Namespace.ID?) -> some View {
        if let namespace {
            // Recortado en círculo: sin esto iOS trata el avatar como un
            // rectángulo y al cerrar Cuenta la burbuja volvía en forma de
            // cuadrado antes de desaparecer.
            matchedTransitionSource(id: ProfileTransition.sourceID, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: 22, style: .circular))
            }
        } else {
            self
        }
    }
}

// MARK: - Paneles

extension View {
    /// Panel de resultados de la barra superior sobre el contenido.
    ///
    /// Aplícalo al contenido **antes** del `safeAreaInset` que lleva la barra:
    /// así el velo oscurece la pantalla pero deja la barra tocable encima.
    func appTopBarPanels() -> some View {
        modifier(AppTopBarPanelsModifier())
    }
}

private struct AppTopBarPanelsModifier: ViewModifier {
    @Environment(AppNavigator.self) private var navigator: AppNavigator?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let navigator, let panel = navigator.visiblePanel {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { navigator.closePanel() }
                        .accessibilityLabel("Cerrar")
                        .accessibilityAddTraits(.isButton)
                    Group {
                        switch panel {
                        case .search: SearchPanel()
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
                }
                .transition(.opacity)
            }
        }
    }
}

private struct PanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppTheme.popoverSurface)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(AppTheme.border, lineWidth: 1))
            .shadow(color: .black.opacity(0.45), radius: 25, y: 20)
    }
}

/// Resultados de la búsqueda global: categorías como atajo y, al escribir,
/// los gastos que coinciden. Tocar uno lleva a Gastos ya filtrado.
/// Panel del buscador, igual en todas las pestañas.
///
/// Vacío, sugiere categorías del catálogo. Con texto, muestra las categorías
/// y los gastos que coinciden con las reglas de `ExpenseSearch`. En Gastos
/// sólo aparece vacío: allí escribir filtra la lista en su sitio.
private struct SearchPanel: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppNavigator.self) private var navigator

    private var query: String {
        (navigator.searchFiltersInPlace ? navigator.expenseQuery : navigator.searchText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [Categoria] {
        ExpenseSearch.suggestedCategories(catalog: store.categorias, expenses: store.gastos)
    }

    private typealias CategoryMatch = (category: Categoria, count: Int, total: Double)

    private func matchingCategories(for query: String) -> [CategoryMatch] {
        guard !query.isEmpty else { return [] }
        let source = store.categorias.isEmpty ? Array(Set(store.gastos.map(\.categoria))) : store.categorias
        let matching = source.filter { ExpenseSearch.matches($0, query: query) }
        guard !matching.isEmpty else { return [] }
        // Una sola pasada por los gastos para todas las categorías.
        let ids = Set(matching.map(\.id))
        var stats: [Int: (count: Int, total: Double)] = [:]
        for expense in store.gastos where ids.contains(expense.categoriaId) {
            stats[expense.categoriaId, default: (0, 0)].count += 1
            stats[expense.categoriaId, default: (0, 0)].total += expense.monto
        }
        return matching
            .map { ($0, stats[$0.id]?.count ?? 0, stats[$0.id]?.total ?? 0) }
            .sorted { $0.count > $1.count }
    }

    private func results(for query: String) -> [Expense] {
        guard !query.isEmpty else { return [] }
        return store.gastos
            .filter { ExpenseSearch.matches($0, query: query) }
            .sorted { $0.fecha > $1.fecha }
    }

    var body: some View {
        // Se busca una vez por evaluación: antes cada sección volvía a
        // recorrer todos los gastos varias veces por tecla.
        let query = query
        let matchingCategories = matchingCategories(for: query)
        let results = results(for: query)
        return VStack(alignment: .leading, spacing: 14) {
            if query.isEmpty {
                suggestionsView
            } else if matchingCategories.isEmpty && results.isEmpty {
                VStack(spacing: 6) {
                    Text("Sin resultados para «\(query)»")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(ExpenseSearch.hint)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !matchingCategories.isEmpty { categoriesSection(matchingCategories) }
                        if !results.isEmpty { expensesSection(results) }
                    }
                }
                .frame(maxHeight: 440)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(PanelBackground())
        .animation(AppMotion.fade, value: query.isEmpty)
        .task { await store.loadCatalogsIfNeeded() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Resultados de búsqueda")
    }

    // MARK: - Sugerencias

    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Categorías")
            ChipFlowLayout(spacing: 8) {
                ForEach(suggestions) { category in
                    Button { pick(category) } label: {
                        HStack(spacing: 8) {
                            Circle().fill(category.color).frame(width: 8, height: 8)
                            Text(category.nombre)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Capsule().fill(AppTheme.insetSurface))
                    }
                    .buttonStyle(.pressable(scale: 0.95))
                }
            }
            Text(ExpenseSearch.hint)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }

    /// En Gastos filtra la lista por la categoría; en el resto la busca.
    private func pick(_ category: Categoria) {
        if navigator.searchFiltersInPlace {
            navigator.expenseQuery = category.nombre
            navigator.closePanel()
        } else {
            navigator.searchText = category.nombre
        }
    }

    // MARK: - Resultados

    private func categoriesSection(_ matchingCategories: [CategoryMatch]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Categorías")
            VStack(spacing: 0) {
                ForEach(Array(matchingCategories.enumerated()), id: \.element.category.id) { index, item in
                    Button { navigator.showExpenses(matching: item.category.nombre) } label: {
                        HStack(spacing: 12) {
                            CategoryGlyph(categoria: item.category, size: 34, tint: item.category.color,
                                background: item.category.color.opacity(0.16), isCircular: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.category.nombre)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(item.count == 1 ? "1 gasto" : "\(item.count) gastos")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }
                            Spacer(minLength: 8)
                            Text(money(item.total))
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.primaryText)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.tertiaryText)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < matchingCategories.count - 1 { AppHairline() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.surface))
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }

    private func expensesSection(_ results: [Expense]) -> some View {
        let shown = Array(results.prefix(30))
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionLabel(results.count == 1 ? "1 gasto" : "\(results.count) gastos")
                Spacer()
                Text(money(results.reduce(0) { $0 + $1.monto }))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.trailing, 4)
            }
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { index, expense in
                    // Abre el gasto; el panel sigue detrás para volver a los resultados.
                    Button { navigator.expenseSheet = .detail(expense) } label: {
                        HStack(spacing: 12) {
                            CategoryGlyph(categoria: expense.categoria, size: 34, tint: expense.categoria.color,
                                background: expense.categoria.color.opacity(0.16), isCircular: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.descripcion)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)
                                Text("\(expense.categoria.nombre) · \(expense.fecha.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))))")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text("−" + money(expense.monto))
                                .font(.system(size: 15, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 56)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < shown.count - 1 { AppHairline() }
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.surface))
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(AppTheme.secondaryText)
            .padding(.horizontal, 4)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

