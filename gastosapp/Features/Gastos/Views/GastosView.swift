import SwiftUI

struct GastosView: View {
    private enum Route: Hashable {
        case addExpense
    }

    @Environment(ExpenseStore.self) private var store
    @Environment(TabBarChrome.self) private var chrome: TabBarChrome?
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
    @State private var sectionMode: GastosSectionMode = .movimientos
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                currentSection

                if let toastMessage {
                    TransientStatusToast(text: toastMessage.text, tint: toastMessage.tint, icon: toastMessage.icon)
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.bottom, AppScreenMetrics.toastBottomPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(2)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .addExpense:
                    AddExpenseSheet { shouldOpenRecurringSection in
                        path.removeAll()
                        updateSectionAfterSave(shouldOpenRecurringSection)
                    }
                    .floatingTabBarInset()
                }
            }
            .appTopBarPanels()
            .safeAreaInset(edge: .top, spacing: 0) {
                // Sólo la barra queda fija; el título va dentro del contenido.
                Group {
                    if navigator != nil {
                        AppTopBar(mode: sectionMode == .movimientos ? .filter : .panel)
                            .padding(.horizontal, -4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, AppScreenMetrics.headerBottomPadding)
                .background {
                    AppHeaderScrim()
                        .opacity(chrome?.isScrolled == true ? 1 : 0)
                }
            }
        }
        .onAppear(perform: consumePendingSection)
        .onChange(of: navigator?.pendingGastosSection) { consumePendingSection() }
    }

    /// Abre la sección que pidió la bandeja o la búsqueda desde otra pestaña.
    private func consumePendingSection() {
        guard let section = navigator?.pendingGastosSection else { return }
        navigator?.pendingGastosSection = nil
        path.removeAll()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            sectionMode = section
        }
    }

    private var sectionHeader: AnyView {
        AnyView(
            GastosHeaderBar(
                sectionMode: $sectionMode,
                onAddTap: navigator == nil ? { path.append(.addExpense) } : nil
            )
        )
    }

    private var toastMessage: (text: String, tint: Color, icon: String)? {
        if let message = store.syncStatusMessage {
            return (message, AppTheme.accent, "checkmark.circle.fill")
        }
        if let message = store.expensesErrorMessage ?? store.recurringExpensesErrorMessage {
            return (message, AppTheme.negative, "exclamationmark.triangle.fill")
        }
        return nil
    }

    @ViewBuilder
    private var currentSection: some View {
        switch sectionMode {
        case .movimientos:
            ExpensesListView(header: sectionHeader)
        case .recurrentes:
            RecurringExpensesListView(header: sectionHeader)
        case .correo:
            EmailReviewView(header: sectionHeader)
        }
    }

    private func updateSectionAfterSave(_ shouldOpenRecurringSection: Bool) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            sectionMode = shouldOpenRecurringSection ? .recurrentes : .movimientos
        }
    }
}

#Preview {
    GastosView()
        .environment(ExpenseStore())
}
