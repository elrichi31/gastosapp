import SwiftUI

struct HomeView: View {
    private enum QuickActionSheet: String, Identifiable {
        case expense
        case recurring
        case budget

        var id: String { rawValue }
    }

    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetStore.self) private var budgetStore
    /// Cambia de pestaña desde los enlaces «Ver todos» y «Ajustar».
    var onOpenTab: (MainTabView.Tab) -> Void = { _ in }
    @State private var budgetDetailStore = BudgetDetailStore()
    @State private var selectedCategory: Categoria?
    /// Separada de `selectedCategory`, que usa la hoja de detalle del mes:
    /// las dos hojas no pueden colgar del mismo estado.
    @State private var homeSelectedCategory: Categoria?
    @State private var presentedQuickAction: QuickActionSheet?
    @State private var selectedRecentBar: DailyExpenseBar?
    @State private var showsProfile = false
    @State private var showsMonthDetails = false
    /// Conecta el avatar con la pantalla de Perfil para la transición de zoom.
    @Namespace private var profileTransition
    @State private var isLoadingHomeData = true
    @State private var dashboardSnapshot = HomeDashboardSnapshot.placeholder()
    @State private var pulse = HomeMonthPulse.placeholder()
    @State private var selectedCalendarDay: Int?
    @State private var emailReview = EmailReviewStore()
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
    @Environment(AppInbox.self) private var inbox: AppInbox?
    @State private var showsEmailReview = false
    @AppStorage(SavingsGoalSettings.enabledKey) private var savingsGoalEnabled = false
    @AppStorage(SavingsGoalSettings.monthlyTargetKey) private var monthlySavingsTarget = 0.0

    private let cal = Calendar.current
    private static let spanishShortMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.shortMonthSymbols ?? formatter.monthSymbols ?? []
    }()

    private var presupuestoActual: BudgetMonthly? {
        let mes = cal.component(.month, from: Date())
        let anio = cal.component(.year, from: Date())
        return budgetStore.budgets.first { $0.anio == anio && $0.mes == mes }
    }

    private var diasDelMesActual: Int {
        cal.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    private var diasRestantesIncluyendoHoy: Int {
        let currentDay = cal.component(.day, from: Date())
        return max(diasDelMesActual - currentDay + 1, 1)
    }

    private var objetivoAhorroConfigurado: Bool {
        savingsGoalEnabled && monthlySavingsTarget > 0
    }

    private func smartInsights(using snapshot: HomeDashboardSnapshot) -> [HomeSmartInsight] {
        var items: [HomeSmartInsight] = []

        if let topCategory = snapshot.monthCategoryTotals.first, snapshot.monthTotal > 0 {
            let percent = Int(round((topCategory.1 / snapshot.monthTotal) * 100))
            items.append(
                HomeSmartInsight(
                    title: "\(topCategory.0.nombre) concentra \(percent)%",
                    message: "Es tu categoría más alta del mes con \(currencyLabel(topCategory.1)).",
                    icon: topCategory.0.icono,
                    tint: topCategory.0.color
                )
            )
        }

        let currentWeekTotal = snapshot.currentWeekTotal
        let previousWeekTotal = snapshot.previousWeekTotal
        if previousWeekTotal > 0 {
            let delta = ((currentWeekTotal - previousWeekTotal) / previousWeekTotal) * 100
            let isHigher = delta >= 0
            items.append(
                HomeSmartInsight(
                    title: isHigher ? "Esta semana vas \(Int(round(delta)))% arriba" : "Esta semana vas \(abs(Int(round(delta))))% abajo",
                    message: "Comparado con los 7 días anteriores.",
                    icon: isHigher ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                    tint: isHigher ? AppTheme.warning : AppTheme.accent
                )
            )
        }

        if let metrics = snapshot.budgetMetrics, metrics.budgeted > 0 {
            let percentage = Int(round(metrics.progressPercentage))
            items.append(
                HomeSmartInsight(
                    title: "Presupuesto usado al \(percentage)%",
                    message: metrics.isOverBudget
                        ? "Te pasaste por \(currencyLabel(abs(metrics.difference)))."
                        : "Te quedan \(currencyLabel(metrics.remaining)) para este mes.",
                    icon: metrics.isOverBudget ? "exclamationmark.triangle.fill" : "target",
                    tint: metrics.isOverBudget ? AppTheme.warning : AppTheme.accent
                )
            )

            if let categoryAlert = snapshot.budgetCategoryAlert,
               categoryAlert.metrics.progressPercentage >= 80 {
                items.append(
                    HomeSmartInsight(
                        title: "\(categoryAlert.category.displayCategory.nombre) va al \(Int(round(categoryAlert.metrics.progressPercentage)))%",
                        message: categoryAlert.metrics.isOverBudget
                            ? "Ya superó su presupuesto mensual."
                            : "Quedan \(currencyLabel(categoryAlert.metrics.remaining)) en esa categoría.",
                        icon: categoryAlert.category.displayCategory.icono,
                        tint: categoryAlert.metrics.isOverBudget ? AppTheme.negative : AppTheme.warning
                    )
                )
            }
        }

        if items.isEmpty {
            return [
                HomeSmartInsight(
                    title: "Registra tus primeros gastos",
                    message: "Con unos cuantos movimientos podré detectar tendencias y avisarte a tiempo.",
                    icon: "sparkles",
                    tint: AppTheme.accent
                )
            ]
        }

        return Array(items.prefix(1))
    }

    var body: some View {
        let snapshot = dashboardSnapshot

        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    summaryContent(snapshot)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
                .animation(AppMotion.fade, value: isLoadingHomeData)
            }
            .tracksScrollChrome()
            .floatingTabBarInset()
        }
        .appTopBarPanels()
        .safeAreaInset(edge: .top, spacing: 0) {
            Group {
                if navigator != nil { AppTopBar() } else { barraSuperior }
            }
                .padding(.horizontal, 16)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, AppScreenMetrics.headerBottomPadding)
                .background {
                    ScrollAwareHeaderScrim()
                }
        }
        .task {
            await loadHomeData()
        }
        .task {
            guard inbox == nil else { return }
            emailReview.tab = "nuevos"
            await emailReview.load(using: store)
        }
        .onChange(of: store.gastos) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: store.recurringExpenses) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: budgetStore.budgets) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: budgetDetailStore.categories) {
            rebuildDashboardSnapshot()
        }
        .sheet(isPresented: $showsProfile) {
            ProfileView(onClose: { showsProfile = false })
                .navigationTransition(.zoom(sourceID: Self.profileTransitionID, in: profileTransition))
        }
        .sheet(isPresented: $showsMonthDetails) {
            monthDetails
        }
        .sheet(item: $homeSelectedCategory) { category in
            HomeCategoryExpenseDetailSheet(category: category, expenses: dashboardSnapshot.expenses(for: category))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsEmailReview, onDismiss: {
            Task {
                if inbox == nil { await emailReview.load(using: store) }
            }
        }) {
            NavigationStack {
                EmailReviewView()
                    .navigationTitle("Correo")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { showsEmailReview = false }
                        }
                    }
            }
        }
        .sheet(item: $presentedQuickAction) { action in
            switch action {
            case .expense:
                NavigationStack {
                    AddExpenseSheet { _ in
                        presentedQuickAction = nil
                    }
                }
            case .recurring:
                NavigationStack {
                    AddExpenseSheet(startInRecurringMode: true) { _ in
                        presentedQuickAction = nil
                    }
                }
            case .budget:
                AddBudgetSheet(defaultYear: budgetStore.selectedYear)
                    .environment(budgetStore)
                    .environment(store)
                    .presentationDetents([.height(360)])
                    .presentationDragIndicator(.visible)
            }
        }
        .overlay(alignment: .bottom) {
            if let toastMessage {
                TransientStatusToast(text: toastMessage.text, tint: toastMessage.tint, icon: toastMessage.icon)
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.bottom, AppScreenMetrics.toastBottomPadding)
                    .transition(AppMotion.toast)
            }
        }
    }

    /// Fila de botones flotantes: cuenta a la izquierda y alta rápida a la derecha.
    private var barraSuperior: some View {
        HStack(spacing: 10) {
            Button {
                showsProfile = true
            } label: {
                Text(initials)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.chromeButtonSurface)
                            .overlay(Circle().strokeBorder(AppTheme.strongBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
                    )
            }
            .buttonStyle(.pressable)
            .matchedTransitionSource(id: Self.profileTransitionID, in: profileTransition) { source in
                source.clipShape(RoundedRectangle(cornerRadius: 22, style: .circular))
            }
            .accessibilityLabel("Cuenta: perfil, conexiones y ajustes")

            Spacer(minLength: 0)

            Menu {
                Button("Nuevo gasto", systemImage: "plus") { presentedQuickAction = .expense }
                Button("Nuevo recurrente", systemImage: "repeat") { presentedQuickAction = .recurring }
                Button("Nuevo presupuesto", systemImage: "chart.pie") { presentedQuickAction = .budget }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(AppTheme.chromeButtonSurface)
                            .overlay(Circle().strokeBorder(AppTheme.strongBorder, lineWidth: 1))
                            .shadow(color: .black.opacity(0.18), radius: 7, y: 4)
                    )
            } primaryAction: {
                presentedQuickAction = .expense
            }
            .accessibilityLabel("Nuevo gasto")
            .accessibilityHint("Mantén pulsado para más opciones")
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Self.headerDateFormatter.string(from: Date()).capitalizingFirstLetter)
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Text("Resumen")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func summaryContent(_ snapshot: HomeDashboardSnapshot) -> some View {
        // Mientras carga, esqueleto: el resumen vacío diría «no hay gastos»
        // antes de saberlo.
        if (isLoadingHomeData || store.isLoadingExpenses) && snapshot.monthExpenses.isEmpty {
            HomeLoadingSkeleton()
        } else if snapshot.monthExpenses.isEmpty {
            if pendingEmailCount > 0 {
                HomeEmailBanner(count: pendingEmailCount) { showsEmailReview = true }
            }
            HomeEmptyMonthState(
                monthName: currentMonthName,
                onAddExpense: { presentedQuickAction = .expense },
                onBudget: { presentedQuickAction = .budget },
                onRecurring: { presentedQuickAction = .recurring },
                onEmail: { showsEmailReview = true }
            )
        } else {
            if pendingEmailCount > 0 {
                HomeEmailBanner(count: pendingEmailCount) { showsEmailReview = true }
            }

            HomeMonthSpendHero(
                total: snapshot.monthTotal,
                delta: pulse.monthDelta,
                comparisonLabel: "que del \(pulse.previousPeriodLabel)"
            )

            HomePaceSection(pulse: pulse)

            if let metrics = snapshot.budgetMetrics, metrics.budgeted > 0 {
                HomeBudgetStatusSection(
                    metrics: metrics,
                    dailyAllowance: dailyBudgetAllowance(using: snapshot),
                    lines: pulse.budgetLines,
                    onAdjust: { openTab(.presupuestos) }
                )
            } else {
                HomeNoBudgetCard { presentedQuickAction = .budget }
            }

            HomeSpendingCalendar(pulse: pulse, selectedDay: $selectedCalendarDay)

            HomeCategorySpendSection(
                totals: snapshot.monthCategoryTotals,
                counts: Dictionary(grouping: snapshot.monthExpenses, by: \.categoriaId).mapValues(\.count),
                total: snapshot.monthTotal,
                onSelect: { homeSelectedCategory = $0 }
            )

            HomeRecentExpensesSection(
                expenses: Array(snapshot.monthExpenses.prefix(5)),
                onSeeAll: { openTab(.gastos) }
            )

            let upcoming = upcomingRecurring
            if !upcoming.items.isEmpty {
                HomeUpcomingRecurringSection(
                    items: upcoming.items,
                    committedTotal: upcoming.total,
                    onSeeAll: { showsMonthDetails = true }
                )
            }

            Button { showsMonthDetails = true } label: {
                HStack {
                    Text("Ver detalle del mes").font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(AppTheme.accent)
                .padding(.horizontal, 4)
                .frame(minHeight: 48)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private func openTab(_ tab: MainTabView.Tab) {
        if let navigator { navigator.open(tab) } else { onOpenTab(tab) }
    }

    private var pendingEmailCount: Int {
        if let inbox { return inbox.pendingEmailCount }
        guard emailReview.isEnabled == true else { return 0 }
        return emailReview.counts["nuevos"] ?? 0
    }

    private var currentMonthName: String {
        Date().formatted(.dateTime.month(.wide).locale(Locale(identifier: "es")))
    }

    /// Recurrentes activos cuyo próximo cobro cae de hoy a fin de mes.
    ///
    /// Sólo cuenta el próximo cobro de cada uno: un semanal puede cobrar más
    /// veces antes de fin de mes, por eso el total se presenta como previsto.
    private var upcomingRecurring: (items: [HomeRecurringPreview], total: Double) {
        let today = cal.startOfDay(for: Date())
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: today)) ?? today
        let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart) ?? today
        let inMonth = store.recurringExpenses
            .filter { $0.activo }
            .compactMap { recurring -> HomeRecurringPreview? in
                guard let date = recurring.nextChargeDate, date >= today, date < monthEnd else { return nil }
                return HomeRecurringPreview(expense: recurring, date: date)
            }
            .sorted { $0.date < $1.date }
        return (Array(inMonth.prefix(4)), inMonth.reduce(0) { $0 + $1.expense.monto })
    }

    private static let headerDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter
    }()

    private static let profileTransitionID = "perfil"

    /// Iniciales del usuario para el avatar, como en cualquier app de banca.
    private var initials: String {
        let name = store.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private var monthDetails: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    MonthlyCommitmentsCard()
                    HomeRecent30DaysSection(
                        bars: dashboardSnapshot.recent30DayBars,
                        totalValue: dashboardSnapshot.monthTotal.budgetCurrency,
                        selectedBar: $selectedRecentBar,
                        dayLabel: compactDayLabel,
                        accessibilityLabel: recentBarAccessibilityLabel
                    )
                    upcomingChargesCard(dashboardSnapshot)
                    categoriasCard(dashboardSnapshot)
                    if objetivoAhorroConfigurado {
                        savingsGoalCard(dashboardSnapshot)
                    }
                    smartInsightsCard(dashboardSnapshot)
                }
                .padding(20)
            }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Detalle del mes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showsMonthDetails = false }
                }
            }
            .sheet(item: $selectedCategory) { category in
                HomeCategoryExpenseDetailSheet(category: category, expenses: dashboardSnapshot.expenses(for: category))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func upcomingChargesCard(_ snapshot: HomeDashboardSnapshot) -> some View {
        HomeUpcomingChargesSection(
            upcomingItems: snapshot.upcomingRecurringItems,
            dueSoonValue: snapshot.recurringDueSoonTotal.budgetCurrency,
            monthlyEstimateValue: snapshot.monthlyRecurringEstimate.budgetCurrency,
            dayLabel: { $0.relativeNextChargeLabel(calendar: cal) }
        )
    }

    private func smartInsightsCard(_ snapshot: HomeDashboardSnapshot) -> some View {
        HomeInsightsSection(insights: smartInsights(using: snapshot))
    }

    private func savingsGoalCard(_ snapshot: HomeDashboardSnapshot) -> some View {
        let budgetBase = budgetBaseForSavings(using: snapshot)
        let spendableAllowance = spendableAllowanceForSavings(using: snapshot)
        let availableAllowance = availableWithoutTouchingSavings(using: snapshot)
        let suggestedDaily = suggestedDailySpendForSavings(using: snapshot)
        let allowanceProgress = savingsAllowanceProgress(using: snapshot)

        return HomeSavingsGoalSection(
            monthlyTargetValue: currencyLabel(monthlySavingsTarget),
            budgetBase: budgetBase,
            monthlyTarget: monthlySavingsTarget,
            spendableAllowanceValue: currencyLabel(spendableAllowance),
            suggestedDailyValue: currencyLabel(suggestedDaily),
            availableAllowance: availableAllowance,
            allowanceProgress: allowanceProgress,
            statusMessage: savingsStatusMessage(availableAllowance)
        )
    }

    private func savingsStatusMessage(_ availableAllowance: Double) -> String {
        if availableAllowance >= 0 {
            return "Vas dentro del plan: quedan \(currencyLabel(availableAllowance)) para gastar sin tocar tu ahorro."
        }
        return "Ya tocaste la reserva por \(currencyLabel(abs(availableAllowance))). Ajusta el ritmo o la meta."
    }

    private func categoriasCard(_ snapshot: HomeDashboardSnapshot) -> some View {
        HomeCategoriesSection(
            title: "Por categoría",
            trailingText: snapshot.scopedCategoryTitle,
            totals: snapshot.scopedCategoryTotals,
            totalAmount: snapshot.scopedTotal,
            onSelectCategory: { selectedCategory = $0 }
        )
    }

    private func compactDayLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))
    }

    private func recentBarAccessibilityLabel(_ bar: DailyExpenseBar) -> String {
        "\(compactDayLabel(bar.date)), \(currencyLabel(bar.total)) gastados"
    }

    private func budgetBaseForSavings(using snapshot: HomeDashboardSnapshot) -> Double {
        snapshot.monthlyBudgetTarget ?? 0
    }

    private func spendableAllowanceForSavings(using snapshot: HomeDashboardSnapshot) -> Double {
        max(0, budgetBaseForSavings(using: snapshot) - monthlySavingsTarget)
    }

    private func availableWithoutTouchingSavings(using snapshot: HomeDashboardSnapshot) -> Double {
        spendableAllowanceForSavings(using: snapshot) - snapshot.monthTotal
    }

    private func suggestedDailySpendForSavings(using snapshot: HomeDashboardSnapshot) -> Double {
        max(0, availableWithoutTouchingSavings(using: snapshot)) / Double(diasRestantesIncluyendoHoy)
    }

    private func savingsAllowanceProgress(using snapshot: HomeDashboardSnapshot) -> Double {
        let spendableAllowance = spendableAllowanceForSavings(using: snapshot)
        guard spendableAllowance > 0 else { return snapshot.monthTotal > 0 ? 1 : 0 }
        return min(max(snapshot.monthTotal / spendableAllowance, 0), 1)
    }

    private func dailyBudgetAllowance(using snapshot: HomeDashboardSnapshot) -> Double? {
        if objetivoAhorroConfigurado, budgetBaseForSavings(using: snapshot) > monthlySavingsTarget {
            return suggestedDailySpendForSavings(using: snapshot)
        }
        if let metrics = snapshot.budgetMetrics, metrics.budgeted > 0 {
            return max(0, metrics.remaining) / Double(diasRestantesIncluyendoHoy)
        }
        if let currentBudget = snapshot.currentBudget, currentBudget.total > 0 {
            return max(0, currentBudget.total - snapshot.monthTotal) / Double(diasRestantesIncluyendoHoy)
        }
        return nil
    }

    private func loadHomeData() async {
        isLoadingHomeData = true
        defer { isLoadingHomeData = false }
        // Lo que ya está en el dispositivo se ve al momento; el servidor lo
        // actualiza después.
        rebuildDashboardSnapshot()

        await store.loadExpensesIfNeeded()
        await store.loadRecurringExpensesIfNeeded()
        let currentYear = cal.component(.year, from: Date())
        let shouldForceBudgetLoad = budgetStore.selectedYear != currentYear
        if shouldForceBudgetLoad {
            budgetStore.selectedYear = currentYear
        }
        await budgetStore.loadBudgets(using: store, force: shouldForceBudgetLoad)
        guard let presupuestoActual else {
            budgetDetailStore.categories = []
            rebuildDashboardSnapshot()
            return
        }
        await budgetDetailStore.loadDetail(using: store, budgetID: presupuestoActual.id)
        rebuildDashboardSnapshot()
    }

    private func rebuildDashboardSnapshot() {
        dashboardSnapshot = HomeDashboardSnapshot(
            expenses: store.gastos,
            recurringExpenses: store.recurringExpenses,
            budget: presupuestoActual,
            budgetCategories: budgetDetailStore.categories,
            scope: .month,
            calendar: cal
        )
        WidgetSummaryPublisher.publish(budget: dashboardSnapshot.monthlyBudgetTarget, calendar: cal)
        pulse = HomeMonthPulse(
            expenses: store.gastos,
            monthTotal: dashboardSnapshot.monthTotal,
            budget: presupuestoActual,
            budgetCategories: budgetDetailStore.categories,
            calendar: cal
        )
    }

    private func dayLabel(for date: Date?) -> String {
        guard let date else { return "" }
        let components = cal.dateComponents([.day, .month], from: date)
        guard
            let day = components.day,
            let month = components.month,
            Self.spanishShortMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(day) \(Self.spanishShortMonthSymbols[month - 1])"
    }

    private func currencyLabel(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private var toastMessage: (text: String, tint: Color, icon: String)? {
        if let message = budgetStore.saveStatusMessage {
            return (message, AppTheme.accent, "checkmark.circle.fill")
        }
        if let message = store.syncStatusMessage {
            return (message, AppTheme.accent, "checkmark.circle.fill")
        }
        return nil
    }
}

#Preview {
    let store = ExpenseStore()
    let categoriaComida = Categoria(id: 1, nombre: "Alimentación")
    let categoriaTransporte = Categoria(id: 2, nombre: "Transporte")
    let categoriaSalud = Categoria(id: 5, nombre: "Salud")
    let pagoEfectivo = ExpensePaymentMethod(id: 1, nombre: "Efectivo")
    let pagoDebito = ExpensePaymentMethod(id: 2, nombre: "Débito")
    let pagoCredito = ExpensePaymentMethod(id: 3, nombre: "Crédito")

    store.add(Expense(descripcion: "Almuerzo", monto: 12.5, fecha: Date(), categoria: categoriaComida, metodoPago: pagoEfectivo))
    store.add(Expense(descripcion: "Uber", monto: 8.3, fecha: Date(), categoria: categoriaTransporte, metodoPago: pagoCredito))
    store.add(Expense(descripcion: "Mercado", monto: 65, fecha: Date().addingTimeInterval(-86_400 * 7), categoria: categoriaComida, metodoPago: pagoDebito))
    store.add(Expense(descripcion: "Farmacia", monto: 18, fecha: Date().addingTimeInterval(-86_400 * 5), categoria: categoriaSalud, metodoPago: pagoEfectivo))

    return HomeView()
        .environment(store)
        .environment(BudgetStore())
}

private extension String {
    /// «martes, 14 de octubre» → «Martes, 14 de octubre».
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}
