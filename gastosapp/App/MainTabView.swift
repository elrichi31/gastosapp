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
        .ignoresSafeArea(.keyboard)
        .sensoryFeedback(.selection, trigger: navigator.selectedTab)
        .onChange(of: navigator.selectedTab) { _, _ in
            navigator.panel = nil
            withAnimation(AppMotion.standard) {
                chrome.isCompact = false
            }
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
                            Task { await store.deleteExpense(id: expense.id) }
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
        .task(id: store.canAccessProtectedEndpoints) {
            await inbox.refresh(store: store, budgets: budgets)
        }
        .onChange(of: budgets.budgets) { Task { await inbox.refresh(store: store, budgets: budgets) } }
        .onChange(of: store.gastos) { inbox.rebuild(store: store) }
        .onChange(of: store.recurringExpenses) { inbox.rebuild(store: store) }
        .onChange(of: navigator.panel) { _, panel in
            if panel == .inbox { Task { await inbox.refresh(store: store, budgets: budgets) } }
        }
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

/// Barra de pestañas del canvas: cápsula oscura translúcida, la pestaña activa
/// con un fondo claro sutil y, al desplazar, más estrecha y sin rótulos.
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
        .background(AppTheme.chromeBackground(Capsule()))
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

#Preview {
    MainTabView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
