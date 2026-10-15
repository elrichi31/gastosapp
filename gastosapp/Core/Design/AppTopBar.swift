import SwiftUI

/// Barra superior del canvas, igual en las cuatro pestañas: cuenta, buscador,
/// bandeja de avisos y gasto nuevo.
///
/// En Gastos el buscador filtra la lista en su sitio (`.filter`); en el resto
/// abre un panel de resultados debajo (`.panel`).
struct AppTopBar: View {
    enum Mode { case panel, filter }

    var mode: Mode = .panel

    @Environment(ExpenseStore.self) private var store
    @Environment(AppNavigator.self) private var navigator
    @Environment(AppInbox.self) private var inbox
    @FocusState private var searchFocused: Bool

    private var query: Binding<String> {
        Binding(
            get: { mode == .filter ? navigator.expenseQuery : navigator.searchText },
            set: { value in
                if mode == .filter {
                    navigator.expenseQuery = value
                } else {
                    navigator.searchText = value
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
                        .background(chromeCircle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Cuenta: perfil, conexiones y ajustes")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            searchField

            if isSearching {
                Button("Cancelar") {
                    searchFocused = false
                    if mode == .filter { navigator.expenseQuery = "" }
                    navigator.closePanel()
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AppTheme.accent)
                .frame(height: 44)
                .padding(.horizontal, 2)
                .buttonStyle(.plain)
                .transition(.opacity)
            } else {
                inboxButton
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                Button {
                    navigator.closePanel()
                    navigator.showsNewExpense = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(width: 44, height: 44)
                        .background(chromeCircle)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Nuevo gasto")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: isSearching)
        .onChange(of: searchFocused) { _, focused in
            if focused, mode == .panel { navigator.panel = .search }
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
        .background(
            Capsule()
                .fill(AppTheme.chromeButtonSurface)
                .overlay(Capsule().strokeBorder(AppTheme.strongBorder, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
        )
        .contentShape(Capsule())
        .onTapGesture { searchFocused = true }
    }

    private var inboxButton: some View {
        let isOpen = navigator.panel == .inbox
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                navigator.panel = isOpen ? nil : .inbox
            }
        } label: {
            Image(systemName: "tray")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isOpen ? AppTheme.backgroundTop : AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isOpen ? AnyShapeStyle(AppTheme.primaryText) : AnyShapeStyle(AppTheme.chromeButtonSurface))
                        .overlay(Circle().strokeBorder(AppTheme.strongBorder, lineWidth: isOpen ? 0 : 1))
                        .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
                )
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
        .accessibilityLabel(inbox.unreadCount > 0 ? "Bandeja, \(inbox.unreadCount) sin leer" : "Bandeja")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
    }

    private var chromeCircle: some View {
        Circle()
            .fill(AppTheme.chromeButtonSurface)
            .overlay(Circle().strokeBorder(AppTheme.strongBorder, lineWidth: 1))
            .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
    }
}

// MARK: - Paneles

extension View {
    /// Paneles de la barra superior (resultados y bandeja) sobre el contenido.
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
            if let navigator, let panel = navigator.panel {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { navigator.closePanel() }
                        .accessibilityLabel("Cerrar")
                        .accessibilityAddTraits(.isButton)
                    Group {
                        switch panel {
                        case .search: SearchPanel()
                        case .inbox: InboxPanel()
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
private struct SearchPanel: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(AppNavigator.self) private var navigator

    private var trimmed: String { navigator.searchText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var results: [Expense] {
        guard !trimmed.isEmpty else { return [] }
        return store.gastos
            .filter {
                $0.descripcion.localizedStandardContains(trimmed)
                    || $0.categoria.nombre.localizedStandardContains(trimmed)
                    || MoneyInput.format($0.monto).contains(trimmed)
            }
            .sorted { $0.fecha > $1.fecha }
    }

    private var categories: [Categoria] {
        Dictionary(grouping: store.gastos, by: \.categoria)
            .sorted { $0.value.count > $1.value.count }
            .prefix(6)
            .map(\.key)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if trimmed.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Filtrar por categoría")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.secondaryText)
                    ChipFlowLayout(spacing: 8) {
                        ForEach(categories) { category in
                            Button {
                                navigator.searchText = category.nombre
                            } label: {
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
                    Text("Busca por comercio, categoría o monto.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            } else if results.isEmpty {
                VStack(spacing: 6) {
                    Text("Sin resultados para «\(trimmed)»")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Prueba con otro comercio, una categoría o un monto.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            } else {
                HStack {
                    Text(results.count == 1 ? "1 resultado" : "\(results.count) resultados")
                    Spacer()
                    Text(money(results.reduce(0) { $0 + $1.monto }))
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.primaryText)
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 4)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(results.prefix(30).enumerated()), id: \.element.id) { index, expense in
                            Button {
                                navigator.showExpenses(matching: trimmed)
                            } label: {
                                HStack(spacing: 12) {
                                    Circle().fill(expense.categoria.color).frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(expense.descripcion)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(AppTheme.primaryText)
                                            .lineLimit(1)
                                        Text("\(expense.categoria.nombre) · \(expense.fecha.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                    Spacer(minLength: 8)
                                    Text(money(expense.monto))
                                        .font(.system(size: 15, weight: .semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(AppTheme.primaryText)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 56)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            if index < min(results.count, 30) - 1 { AppHairline() }
                        }
                    }
                }
                .frame(maxHeight: 380)
                .fixedSize(horizontal: false, vertical: true)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.surface))
                .clipShape(.rect(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(12)
        .background(PanelBackground())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Resultados de búsqueda")
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

/// Bandeja de avisos: cada aviso lleva a la pantalla donde se resuelve.
private struct InboxPanel: View {
    @Environment(AppNavigator.self) private var navigator
    @Environment(AppInbox.self) private var inbox

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Bandeja")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if inbox.hasUnread {
                    Button("Marcar como leído") { inbox.markRead() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(height: 40)
                        .padding(.horizontal, 12)
                        .buttonStyle(.plain)
                }
            }
            .padding(.leading, 12)
            .padding(.trailing, 4)
            .padding(.vertical, 6)

            if inbox.items.isEmpty {
                VStack(spacing: 6) {
                    Text("Todo al día")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Aquí verás movimientos del correo, avisos de presupuesto y cobros recurrentes.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.top, 20)
                .padding(.bottom, 24)
            } else {
                ForEach(inbox.items) { item in
                    Button {
                        inbox.markRead()
                        switch item.kind {
                        case .mail: navigator.open(.gastos, section: .correo)
                        case .budget: navigator.open(.presupuestos)
                        case .recurring: navigator.open(.gastos, section: .recurrentes)
                        }
                    } label: {
                        row(item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: 360)
        .background(PanelBackground())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bandeja de avisos")
    }

    private func row(_ item: AppInbox.Item) -> some View {
        let (icon, tint): (String, Color) = switch item.kind {
        case .mail: ("tray", AppTheme.accent)
        case .budget: ("exclamationmark.circle", AppTheme.warning)
        case .recurring: ("repeat", AppTheme.secondaryAccent)
        }
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.2)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: inbox.hasUnread ? .semibold : .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                Text(item.subtitle)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer(minLength: 8)
            Circle()
                .fill(AppTheme.negative)
                .frame(width: 8, height: 8)
                .opacity(inbox.hasUnread ? 1 : 0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 68)
        .contentShape(.rect)
    }
}
