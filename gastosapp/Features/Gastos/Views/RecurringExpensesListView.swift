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

    @State private var expandedID: RecurringExpense.ID?

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if store.isLoadingRecurringExpenses && store.recurringExpenses.isEmpty {
                        ProgressView()
                            .tint(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                    } else if store.recurringExpenses.isEmpty {
                        emptyCard
                    } else {
                        summary
                        filtersRow
                        if let error = store.saveErrorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.negative)
                        }
                        listCard
                        NavigationLink {
                            RecurringPriceHistoryView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.secondaryText)
                                Text("Historial de precios")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                            .padding(.horizontal, 16)
                            .frame(minHeight: 52)
                            .background(groupBackground)
                        }
                        .buttonStyle(.pressable(scale: 0.98))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
            }
            .tracksScrollChrome()
            .floatingTabBarInset()
            .refreshable {
                await store.loadRecurringExpenses(force: true)
            }
        }
        .confirmationDialog("¿Saltar el próximo cobro?", isPresented: Binding(get: { recurringToSkip != nil }, set: { if !$0 { recurringToSkip = nil } }), titleVisibility: .visible) {
            if let item = recurringToSkip {
                Button("Saltar cobro de " + item.descripcion) { Task { _ = await store.skipRecurringCharge(item); recurringToSkip = nil } }
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
                .safeAreaInset(edge: .top, spacing: 0) {
                    FormSheetHeader(title: recurring.isSubscriptionLike ? "Editar suscripción" : "Editar recurrente") {
                        recurringToEdit = nil
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .background(AppTheme.backgroundTop)
                }
                .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Resumen

    /// Costo anual de los activos repartido por categoría, de mayor a menor.
    private var annualByCategory: [(category: Categoria, total: Double)] {
        Dictionary(grouping: store.recurringExpenses.filter(\.activo), by: \.categoria)
            .map { ($0.key, $0.value.reduce(0) { $0 + $1.estimatedMonthlyAmount * 12 }) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    private var summary: some View {
        let activeCount = store.recurringExpenses.filter(\.activo).count
        let monthly = store.recurringExpenses.filter(\.activo).reduce(0) { $0 + $1.estimatedMonthlyAmount }
        let segments = annualByCategory
        let annual = segments.reduce(0) { $0 + $1.total }

        return VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Al mes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.tertiaryText)
                splitAmount(monthly)
                Text("\(currency(annual)) al año · \(activeCount == 1 ? "1 activo" : "\(activeCount) activos")")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            if !segments.isEmpty {
                GeometryReader { proxy in
                    let available = proxy.size.width - CGFloat(max(segments.count - 1, 0)) * 3
                    HStack(spacing: 3) {
                        ForEach(segments, id: \.category.id) { segment in
                            Capsule()
                                .fill(segment.category.color)
                                .frame(width: max(6, available * segment.total / max(annual, 0.01)))
                        }
                    }
                }
                .frame(height: 10)
                .accessibilityHidden(true)

                ChipFlowLayout(spacing: 16) {
                    ForEach(segments, id: \.category.id) { segment in
                        HStack(spacing: 6) {
                            Circle().fill(segment.category.color).frame(width: 8, height: 8)
                            Text("\(segment.category.nombre) · \(Int((segment.total / max(annual, 0.01) * 100).rounded()))%")
                        }
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Reparto del costo anual por categoría")
            }
        }
    }

    private var filtersRow: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { item in
                let isSelected = filter == item
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) { filter = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : AppTheme.popoverSurface))
                }
                .buttonStyle(.pressable(scale: 0.95))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    // MARK: - Lista

    @ViewBuilder
    private var listCard: some View {
        if items.isEmpty {
            Text("No hay cargos en este filtro.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(groupBackground)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                    if index < items.count - 1 { AppHairline() }
                }
            }
            .background(groupBackground)
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
    }

    private func row(_ item: RecurringExpense) -> some View {
        let isOpen = expandedID == item.id
        let color = item.categoria.color
        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    expandedID = isOpen ? nil : item.id
                }
            } label: {
                HStack(spacing: 12) {
                    CategoryGlyph(categoria: item.categoria, size: 44, tint: color, background: color.opacity(0.16), isCircular: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.descripcion)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        Text(item.activo ? "\(item.frecuencia.title) · \(nextChargeRelativeLabel(for: item))" : "Pausado · \(item.frecuencia.title)")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.tertiaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(currency(item.monto))
                        .font(.system(size: 16, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .opacity(item.activo ? 1 : 0.55)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Muestra detalles y acciones")
            .accessibilityValue(isOpen ? "Desplegado" : "Plegado")

            if isOpen {
                details(item)
                    .transition(.opacity)
            }
        }
    }

    private func details(_ item: RecurringExpense) -> some View {
        let shortDate = Date.FormatStyle().day().month(.abbreviated).year().locale(Locale(identifier: "es"))
        let facts: [(String, String)] = [
            ("Próximo cobro", item.nextChargeDate.map { $0.formatted(shortDate) } ?? "—"),
            ("Costo anual", currency(item.estimatedMonthlyAmount * 12)),
            ("Método", item.metodoPago.shortLabel),
            (item.fechaFin == nil ? "Desde" : "Hasta", (item.fechaFin ?? item.fechaInicio).formatted(shortDate))
        ]
        return VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(facts, id: \.0) { fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.0)
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                        Text(fact.1)
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.insetSurface))
                    .accessibilityElement(children: .combine)
                }
            }

            Toggle(isOn: Binding(
                get: { item.activo },
                set: { _ in Task { _ = await store.toggleRecurring(item) } }
            )) {
                Text(item.activo ? "Activo" : "Pausado")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .tint(AppTheme.accent)
            .disabled(store.isSavingExpense)
            .padding(.leading, 14)
            .padding(.trailing, 12)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.insetSurface))

            HStack(spacing: 8) {
                if item.activo {
                    actionButton("Saltar", icon: "forward.end", tint: AppTheme.primaryText, fill: AppTheme.popoverSurface) {
                        recurringToSkip = item
                    }
                    .accessibilityLabel("Saltar el próximo cobro de \(item.descripcion)")
                }
                actionButton("Editar", icon: "pencil", tint: AppTheme.primaryText, fill: AppTheme.popoverSurface) {
                    recurringToEdit = item
                }
                .accessibilityLabel("Editar \(item.descripcion)")
                actionButton("Eliminar", icon: "trash", tint: AppTheme.negative, fill: AppTheme.negative.opacity(0.14)) {
                    recurringToDelete = item
                }
                .accessibilityLabel("Eliminar \(item.descripcion)")
            }
            .disabled(store.isSavingExpense)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 16)
    }

    private func actionButton(_ title: String, icon: String, tint: Color, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(fill))
        }
        .buttonStyle(.pressable(scale: 0.96))
    }

    private var groupBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
    }

    private func splitAmount(_ value: Double) -> some View {
        let whole = Double(Int(value)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = (Locale.current.decimalSeparator ?? ".") + String(format: "%02d", Int((value * 100).rounded()) % 100)
        return (Text(whole).font(.system(size: 52, weight: .semibold)).foregroundStyle(AppTheme.primaryText)
                + Text(cents).font(.system(size: 30, weight: .semibold)).foregroundStyle(AppTheme.tertiaryText))
            .tracking(-1.8)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
            .accessibilityLabel(currency(value))
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

    private var emptyCard: some View {
        VStack(spacing: 10) {
            Text("Sin recurrentes")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
            Text("Se registran solos cada semana, mes o año. Crea uno con el botón +.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 36)
        .background(groupBackground)
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
