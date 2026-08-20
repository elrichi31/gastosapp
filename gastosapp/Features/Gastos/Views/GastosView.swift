import SwiftUI

struct GastosView: View {
    private enum Route: Hashable {
        case addExpense
    }

    @Environment(ExpenseStore.self) private var store
    @State private var sectionMode: GastosSectionMode = .movimientos
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                currentSection

                if let toastMessage {
                    TransientStatusToast(text: toastMessage.text, tint: toastMessage.tint, icon: toastMessage.icon)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 92)
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
            .safeAreaInset(edge: .top, spacing: 0) {
                GastosHeaderBar(
                    sectionMode: $sectionMode,
                    onAddTap: { path.append(.addExpense) }
                )
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
            }
        }
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
            ExpensesListView()
        case .recurrentes:
            RecurringExpensesListView()
        case .calendario:
            FinancialCalendarView()
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
