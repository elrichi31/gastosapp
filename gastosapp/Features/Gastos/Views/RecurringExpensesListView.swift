import SwiftUI

struct RecurringExpensesListView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all
        case subscriptions
        case recurring

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "Todos"
            case .subscriptions: return "Suscripciones"
            case .recurring: return "Recurrentes"
            }
        }
    }

    @Environment(ExpenseStore.self) private var store
    @State private var recurringToSkip: RecurringExpense?
    @State private var filter: Filter = .all
    @State private var recurringToDelete: RecurringExpense?
    @State private var recurringToEdit: RecurringExpense?

    private var items: [RecurringExpense] {
        store.recurringExpenses.filter { item in
            switch filter {
            case .all:
                return true
            case .subscriptions:
                return item.isSubscriptionLike
            case .recurring:
                return !item.isSubscriptionLike
            }
        }
        .sorted { lhs, rhs in
            switch (lhs.nextChargeDate, rhs.nextChargeDate) {
            case let (left?, right?):
                return left < right
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.descripcion.localizedCaseInsensitiveCompare(rhs.descripcion) == .orderedAscending
            }
        }
    }

    private var activeItems: [RecurringExpense] {
        store.recurringExpenses.filter { $0.activo && $0.nextChargeDate != nil }
    }

    private var upcomingItems: [RecurringExpense] {
        Array(activeItems.sorted { ($0.nextChargeDate ?? .distantFuture) < ($1.nextChargeDate ?? .distantFuture) }.prefix(3))
    }

    private var monthlyFixedEstimate: Double {
        activeItems.reduce(0) { $0 + monthlyEstimate(for: $1) }
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            List {
                headerRow {
                    filtersCard
                }

                if store.isLoadingRecurringExpenses && store.recurringExpenses.isEmpty {
                    headerRow {
                        loadingCard
                    }
                } else if items.isEmpty {
                    headerRow {
                        emptyCard
                    }
                } else {
                    headerRow {
                        upcomingSummaryCard
                    }

                    headerRow { NavigationLink("Historial de precios") { RecurringPriceHistoryView() } }
                    if let error = store.saveErrorMessage { headerRow { Text(error).foregroundStyle(AppTheme.negative) } }
                    ForEach(items) { item in
                        RecurringExpenseCard(item: item)
                            .contentShape(Rectangle())
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button(item.activo ? "Pausar" : "Reanudar") { Task { _ = await store.toggleRecurring(item) } }.tint(AppTheme.secondaryAccent)
                                if item.activo {
                                    Button("Omitir cobro") { recurringToSkip = item }.tint(AppTheme.warning)
                                }
                            }
                            .disabled(store.isSavingExpense)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    recurringToEdit = item
                                } label: {
                                    nativeSwipeIcon("pencil", tint: AppTheme.accent)
                                }
                                .tint(AppTheme.backgroundBottom)
                                .accessibilityLabel("Editar")

                                Button(role: .destructive) {
                                    recurringToDelete = item
                                } label: {
                                    nativeSwipeIcon("trash", tint: AppTheme.negative)
                                }
                                .tint(AppTheme.backgroundBottom)
                                .accessibilityLabel("Eliminar")
                            }
                    }
                }

                bottomSafeRow
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .tracksScrollChrome()
            .floatingTabBarInset()
            .refreshable {
                await store.loadRecurringExpenses(force: true)
            }
        }
        .confirmationDialog("¿Omitir el próximo cobro?", isPresented: Binding(get: { recurringToSkip != nil }, set: { if !$0 { recurringToSkip = nil } }), titleVisibility: .visible) {
            if let item = recurringToSkip {
                Button("Omitir cobro de " + item.descripcion) { Task { _ = await store.skipRecurringCharge(item); recurringToSkip = nil } }
            }
        } message: { Text("La regla seguirá activa para los siguientes cobros.") }
        .task {
            await store.loadCatalogsIfNeeded()
            await store.loadRecurringExpensesIfNeeded()
        }
        .sheet(item: $recurringToEdit) { recurring in
            NavigationStack {
                AddRecurringExpenseView(
                    kind: recurring.isSubscriptionLike ? .suscripcion : .recurrente,
                    existingExpense: recurring,
                    onSaved: closeEditorAndRefresh
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { recurringToEdit = nil }
                    }
                }
            }
        }
        .appConfirmationDialog(
            isPresented: Binding(
            get: { recurringToDelete != nil },
            set: { if !$0 { recurringToDelete = nil } }
        ),
            title: "Eliminar cargo recurrente",
            message: deleteRecurringMessage
        ) {
                let id = recurringToDelete?.id
                recurringToDelete = nil
                guard let id else { return }
                Task {
                    await store.deleteRecurringExpense(id: id)
                }
        }
    }

    private func headerRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var bottomSafeRow: some View {
        Color.clear
            .frame(height: AppScreenMetrics.contentBottomPadding)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private var filtersCard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(filter == item ? .black : AppTheme.primaryText)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(
                                Capsule()
                                    .fill(filter == item ? AppTheme.accent : AppTheme.controlSurface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var upcomingSummaryCard: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Text("Fijos estimados")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.secondaryText)

                Text("Costo anual: " + currency(activeItems.reduce(0) { $0 + $1.estimatedMonthlyAmount * 12 }))
                    .font(.caption).foregroundStyle(AppTheme.secondaryText)
                Text(currency(monthlyFixedEstimate))
                    .font(AppTheme.number(44, .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: monthlyFixedEstimate))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)

            if upcomingItems.isEmpty {
                Text("No tienes cargos activos próximos.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 10) {
                    ForEach(upcomingItems) { item in
                        upcomingRow(item)
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func upcomingRow(_ item: RecurringExpense) -> some View {
        HStack(spacing: 12) {
            CategoryGlyph(categoria: item.categoria, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.descripcion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(nextChargeRelativeLabel(for: item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 8)

            Text(currency(item.monto))
                .font(AppTheme.number(15, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.vertical, 8)
    }

    private func closeEditorAndRefresh() {
        recurringToEdit = nil
        refreshRecurringExpenses()
    }

    private func refreshRecurringExpenses() {
        Task {
            await store.loadRecurringExpenses(force: true)
            await store.loadExpenses(force: true)
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(AppTheme.accent)
            Text("Cargando programados")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .background(AppTheme.cardBackground())
    }

    private var emptyCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "repeat.circle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppTheme.placeholderText)
            Text("Sin cargos programados")
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text("Crea un recurrente o una suscripción y aparecerá aquí.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppTheme.cardBackground())
    }

    private func monthlyEstimate(for item: RecurringExpense) -> Double {
        item.estimatedMonthlyAmount
    }

    private func nextChargeRelativeLabel(for item: RecurringExpense) -> String {
        item.relativeNextChargeLabel()
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private func nativeSwipeIcon(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .font(.system(size: 21, weight: .bold))
            .frame(width: 30, height: 30)
    }

    private var deleteRecurringMessage: String {
        guard let recurringToDelete else {
            return "Este cargo dejará de generarse automáticamente."
        }
        return "\"\(recurringToDelete.descripcion)\" dejará de generarse automáticamente."
    }
}

#Preview {
    RecurringExpensesListView()
        .environment(ExpenseStore())
}
