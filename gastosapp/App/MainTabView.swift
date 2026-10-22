import SwiftUI

struct MainTabView: View {
    enum Tab: Hashable {
        case inicio, gastos, presupuestos, stats
    }

    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetStore.self) private var budgets
    @State private var navigator = AppNavigator()
    @State private var inbox = AppInbox()
    @State private var chrome = TabBarChrome()
    @Namespace private var profileNamespace
    /// Fallo al borrar desde el buscador. Plan y Análisis no tienen aviso
    /// propio, así que sin esto el gasto volvía a la lista sin explicación.
    @State private var deleteErrorMessage: String?

    var body: some View {
        @Bindable var navigator = navigator
        currentTabView
        .environment(\.floatingTabBarHeight, FloatingTabBarMetrics.reservedHeight)
        .environment(chrome)
        .environment(navigator)
        .environment(inbox)
        .environment(\.profileTransitionNamespace, profileNamespace)
        // La barra va en un `overlay`, no en un `safeAreaInset`: así no inyecta
        // ningún espacio implícito en el contenido. Todo el hueco bajo la barra
        // lo pide cada pantalla con `.floatingTabBarInset()`, que es lo único
        // que reserva sitio en toda la app. Con `safeAreaInset` había dos
        // fuentes de hueco —la implícita, que SwiftUI no propaga a lo que
        // empuja un `NavigationStack`, y la explícita— y unas pantallas
        // quedaban tapadas mientras otras reservaban el doble.
        .overlay(alignment: .bottom) {
            // La barra lee `chrome` por su cuenta: así al contraerse sólo se
            // recalcula ella y no la vista principal con la pantalla activa.
            FloatingTabBar(seleccion: $navigator.selectedTab, chrome: chrome)
        }
        // Notificaciones entra desde la derecha y tapa también la barra de
        // pestañas, como una pantalla empujada.
        .overlay {
            if navigator.showsNotifications {
                NotificationsScreenContainer {
                    withAnimation(AppMotion.expand) { navigator.showsNotifications = false }
                }
                // Este overlay va por fuera de los `.environment` de arriba,
                // que sólo alcanzan al contenido de la pestaña: sin pasarlos
                // aquí la pantalla no encontraba el navegador y se cerraba la app.
                .environment(navigator)
                .environment(inbox)
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: navigator.selectedTab)
        .onChange(of: navigator.selectedTab) { _, _ in
            // `closePanel` y no sólo `panel = nil`: también vacía el buscador,
            // que si no se quedaba con el texto en la pestaña nueva.
            navigator.closePanel()
            navigator.showsNotifications = false
            withAnimation(AppMotion.standard) {
                chrome.isCompact = false
            }
        }
        // Tocar un widget abre Resumen, con lo que hubiera encima ya cerrado.
        .onOpenURL { url in
            guard url == WidgetSummaryStore.widgetURL else { return }
            navigator.showsProfile = false
            navigator.showsNewExpense = false
            navigator.expenseSheet = nil
            navigator.showsNotifications = false
            navigator.open(.inicio)
        }
        .sheet(isPresented: $navigator.showsProfile) {
            ProfileView(onClose: { navigator.showsProfile = false })
                .navigationTransition(.zoom(sourceID: ProfileTransition.sourceID, in: profileNamespace))
        }
        .sheet(isPresented: $navigator.showsNewExpense) {
            NavigationStack {
                AddExpenseSheet { _ in navigator.showsNewExpense = false }
            }
        }
        // Un gasto tocado en el buscador se abre aquí, encima de la pestaña en
        // la que estés, en lugar de llevarte a Gastos.
        .sheet(item: $navigator.expenseSheet) { sheet in
            NavigationStack {
                switch sheet {
                case let .detail(expense):
                    ExpenseDetailSheet(
                        expense: expense,
                        onClose: { navigator.expenseSheet = nil },
                        onEdit: { navigator.expenseSheet = .edit(expense) },
                        onDelete: {
                            navigator.expenseSheet = nil
                            Task {
                                if await !store.deleteExpense(id: expense.id) {
                                    deleteErrorMessage = store.expensesErrorMessage ?? "No se pudo eliminar el gasto."
                                }
                            }
                        }
                    )
                case let .edit(expense):
                    AddExpenseView(editingExpense: expense) { navigator.expenseSheet = nil }
                        .safeAreaInset(edge: .top, spacing: 0) {
                            FormSheetChrome {
                                FormSheetHeader(title: "Editar gasto") { navigator.expenseSheet = nil }
                            }
                        }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .alert(
            "No se pudo eliminar",
            isPresented: Binding(get: { deleteErrorMessage != nil }, set: { if !$0 { deleteErrorMessage = nil } })
        ) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .openEmailReview)) { _ in
            openEmailReviewIfPending()
        }
        .onAppear { openEmailReviewIfPending() }
        .task(id: store.canAccessProtectedEndpoints) {
            await inbox.refresh(store: store, budgets: budgets)
        }
        .onChange(of: budgets.budgets) { Task { await inbox.refresh(store: store, budgets: budgets) } }
        .onChange(of: store.gastos) { inbox.rebuild(store: store) }
        .onChange(of: store.recurringExpenses) { inbox.rebuild(store: store) }

    }

    /// Al tocar la notificación de un consumo detectado se abre Correo.
    private func openEmailReviewIfPending() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: NotificationRouting.pendingEmailReviewKey) else { return }
        defaults.set(false, forKey: NotificationRouting.pendingEmailReviewKey)
        navigator.showsProfile = false
        navigator.showsNotifications = false
        navigator.open(.gastos, section: .correo)
    }

    private var currentTabView: some View {
        tabContent
            .screenSwap(navigator.selectedTab)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch navigator.selectedTab {
        case .inicio:
            HomeView()
        case .gastos:
            GastosView()
        case .presupuestos:
            BudgetsView()
        case .stats:
            StatsView()
        }
    }
}

private struct FloatingTabBar: View {
    @Binding var seleccion: MainTabView.Tab
    /// Se pasa directo: el `overlay` queda fuera del `.environment(chrome)`.
    let chrome: TabBarChrome

    var body: some View {
        PillTabBar(seleccion: $seleccion, isCompact: chrome.isCompact)
            .padding(.horizontal, chrome.isCompact ? FloatingTabBarMetrics.compactHorizontalInset : FloatingTabBarMetrics.horizontalInset)
            .padding(.bottom, FloatingTabBarMetrics.outerVerticalPadding)
    }
}

/// Barra de pestañas del canvas: cápsula de Liquid Glass (material translúcido
/// antes de iOS 26), la pestaña activa con un fondo claro sutil y, al
/// desplazar, más estrecha y sin rótulos.
private struct PillTabBar: View {
    @Binding var seleccion: MainTabView.Tab
    let isCompact: Bool
    @Namespace private var indicator

    private let items: [(tab: MainTabView.Tab, icon: String, title: String)] = [
        (.inicio, "house.fill", "Resumen"),
        (.gastos, "doc.text.fill", "Gastos"),
        (.presupuestos, "chart.pie.fill", "Plan"),
        (.stats, "chart.bar.fill", "Análisis")
    ]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.tab) { item in
                botonTab(tab: item.tab, icono: item.icon, titulo: item.title)
            }
        }
        .padding(FloatingTabBarMetrics.innerPadding)
        .tabBarGlass()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Principal")
    }

    private func botonTab(tab: MainTabView.Tab, icono: String, titulo: String) -> some View {
        let activo = seleccion == tab
        return Button {
            withAnimation(AppMotion.standard) {
                seleccion = tab
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icono)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(height: 24)
                if !isCompact {
                    Text(titulo)
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.1)
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(activo ? AppTheme.primaryText : AppTheme.secondaryText)
            .frame(maxWidth: .infinity)
            .frame(height: isCompact ? FloatingTabBarMetrics.compactItemHeight : FloatingTabBarMetrics.itemHeight)
            .background {
                if activo {
                    Capsule()
                        .fill(AppTheme.primaryText.opacity(0.1))
                        .matchedGeometryEffect(id: "tab", in: indicator)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.9))
        .accessibilityLabel(titulo)
        .accessibilityAddTraits(activo ? .isSelected : [])
    }
}

private extension View {
    /// Liquid Glass en iOS 26: refracta lo que pasa por debajo. Antes, el
    /// fondo translúcido de siempre. No es interactivo para que el cristal no
    /// se quede con los toques de las pestañas (ver `chromeGlass`).
    @ViewBuilder
    func tabBarGlass() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: .capsule)
                .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        } else {
            background(AppTheme.chromeBackground(Capsule()))
        }
    }
}

#Preview {
    MainTabView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}

/// Notificaciones a pantalla completa, con el gesto de volver desde el borde
/// izquierdo: la pantalla sigue al dedo y se cierra si pasa de un tercio.
private struct NotificationsScreenContainer: View {
    let onClose: () -> Void
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            AppNotificationsView(onClose: onClose)
                .overlay(alignment: .leading) {
                    Color.clear
                        .frame(width: 24)
                        .contentShape(.rect)
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { dragOffset = max(0, $0.translation.width) }
                                .onEnded { value in
                                    let width = proxy.size.width
                                    if value.translation.width > width / 3 || value.predictedEndTranslation.width > width / 2 {
                                        onClose()
                                    }
                                    withAnimation(AppMotion.expand) { dragOffset = 0 }
                                }
                        )
                }
                // La sombra la hace un rectángulo detrás: sombrear la pantalla
                // entera obligaba a dibujar su silueta en cada cuadro del gesto.
                .background {
                    if dragOffset > 0 {
                        Rectangle()
                            .fill(AppTheme.backgroundTop)
                            .shadow(color: .black.opacity(0.25), radius: 16)
                    }
                }
                .offset(x: dragOffset)
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
