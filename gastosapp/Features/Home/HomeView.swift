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
    @State private var budgetDetailStore = BudgetDetailStore()
    @State private var selectedCategory: Categoria?
    @State private var presentedQuickAction: QuickActionSheet?
    @State private var isLoadingHomeData = true
    @State private var dashboardSnapshot = HomeDashboardSnapshot.placeholder()
    @AppStorage(SavingsGoalSettings.enabledKey) private var savingsGoalEnabled = false
    @AppStorage(SavingsGoalSettings.monthlyTargetKey) private var monthlySavingsTarget = 0.0

    private let cal = Calendar.current
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()
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
            fondo.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    homeDecisionHero(snapshot)
                    quickActionsCard
                    upcomingChargesCard(snapshot)
                    categoriasCard(snapshot)
                    if objetivoAhorroConfigurado {
                        savingsGoalCard(snapshot)
                    }
                    smartInsightsCard(snapshot)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            barraSuperior
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 12)
                .background {
                    AppTheme.backgroundTop
                        .overlay(alignment: .bottom) {
                            LinearGradient(
                                colors: [AppTheme.backgroundTop, AppTheme.backgroundTop.opacity(0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 16)
                            .offset(y: 16)
                        }
                        .ignoresSafeArea(edges: .top)
                }
        }
        .task {
            await loadHomeData()
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
        .sheet(item: $selectedCategory) { category in
            HomeCategoryExpenseDetailSheet(category: category, expenses: snapshot.expenses(for: category))
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var barraSuperior: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                AppSectionLabel(text: saludo, size: 10)
                Text("Resumen")
                    .font(AppTheme.number(26, .bold))
                    .foregroundStyle(AppTheme.primaryText)
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Circle()
                    .fill(store.isAuthenticated ? AppTheme.accent : AppTheme.warning)
                    .frame(width: 6, height: 6)
                Text(nombreMesActual.capitalized)
                    .font(AppTheme.number(13, .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(AppTheme.controlSurface)
                    .overlay(Capsule().strokeBorder(AppTheme.border, lineWidth: 1))
            )
            .accessibilityLabel(store.isAuthenticated ? "Sesión activa, \(nombreMesActual)" : "Sin sesión, \(nombreMesActual)")
        }
        .padding(.vertical, 2)
    }

    private var saludo: String {
        let hora = cal.component(.hour, from: Date())
        switch hora {
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private func homeDecisionHero(_ snapshot: HomeDashboardSnapshot) -> some View {
        let state = decisionState(using: snapshot)
        let target = snapshot.monthlyBudgetTarget
        let delta = projectedBudgetDelta(using: snapshot)

        return HomeMonthHeroCard(
            state: state,
            daysRemaining: diasRestantesIncluyendoHoy,
            spentValue: snapshot.monthTotal.budgetCurrency,
            projectionValue: projectedMonthClosing(using: snapshot).budgetCurrency,
            budgetValue: target?.budgetCurrency,
            outcomeMessage: outcomeMessage(target: target, delta: delta),
            outcomeIsPositive: delta.map { $0 >= 0 },
            nextRecurringTitle: snapshot.nextRecurringPreview?.expense.descripcion,
            nextRecurringDateLabel: dayLabel(for: snapshot.nextRecurringPreview?.date)
        )
    }

    private func outcomeMessage(target: Double?, delta: Double?) -> String? {
        guard let target, let delta else { return nil }
        return delta >= 0
            ? "Si sigues así, cerrarías con \(delta.budgetCurrency) de aire sobre tu presupuesto."
            : "Si sigues así, te pasarías por \(abs(delta).budgetCurrency) del presupuesto de \(target.budgetCurrency)."
    }

    private var quickActionsCard: some View {
        HomeQuickActionsSection(
            onExpenseTap: { presentedQuickAction = .expense },
            onRecurringTap: { presentedQuickAction = .recurring },
            onBudgetTap: { presentedQuickAction = .budget }
        )
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

    private var fondo: some View {
        LinearGradient(
            colors: [
                AppTheme.backgroundTop,
                AppTheme.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var nombreMesActual: String {
        let components = cal.dateComponents([.year, .month], from: Date())
        guard
            let year = components.year,
            let month = components.month,
            Self.spanishMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(Self.spanishMonthSymbols[month - 1]) \(year)"
    }

    private func projectedMonthClosing(using snapshot: HomeDashboardSnapshot) -> Double {
        snapshot.monthAveragePerDay * Double(diasDelMesActual)
    }

    private func projectedBudgetDelta(using snapshot: HomeDashboardSnapshot) -> Double? {
        guard let target = snapshot.monthlyBudgetTarget else { return nil }
        return target - projectedMonthClosing(using: snapshot)
    }

    private func decisionState(using snapshot: HomeDashboardSnapshot) -> HomeDecisionState {
        if isLoadingHomeData || store.isLoadingExpenses || budgetStore.isLoadingBudgets || budgetDetailStore.isLoading {
            return HomeDecisionState(
                title: "Cargando tu mes",
                subtitle: "Estoy revisando tus gastos y presupuesto para mostrarte el estado correcto.",
                icon: "hourglass",
                tint: AppTheme.secondaryAccent,
                isLoading: true
            )
        }

        if let metrics = snapshot.budgetMetrics, metrics.budgeted > 0, metrics.isOverBudget {
            return HomeDecisionState(
                title: "Baja el ritmo hoy",
                subtitle: "Ya superaste el presupuesto por \(currencyLabel(abs(metrics.difference))).",
                icon: "exclamationmark.triangle.fill",
                tint: AppTheme.warning
            )
        }

        let availableAllowance = availableWithoutTouchingSavings(using: snapshot)
        if objetivoAhorroConfigurado, availableAllowance < 0 {
            return HomeDecisionState(
                title: "Protege tu ahorro",
                subtitle: "La reserva ya se tocó por \(currencyLabel(abs(availableAllowance))).",
                icon: "shield.lefthalf.filled",
                tint: AppTheme.warning
            )
        }

        if let dailyAllowance = dailyBudgetAllowance(using: snapshot) {
            return HomeDecisionState(
                title: "Puedes gastar hoy",
                subtitle: "Manteniendo tu ritmo, este es tu cupo diario sugerido.",
                icon: "checkmark.seal.fill",
                tint: AppTheme.accent,
                amount: dailyAllowance
            )
        }

        return HomeDecisionState(
            title: "Crea tu presupuesto",
            subtitle: "Así puedo decirte cuánto gastar por día y avisarte antes.",
            icon: "target",
            tint: AppTheme.secondaryAccent
        )
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

    private func formatear(_ valor: Double) -> String {
        MoneyInput.format(valor)
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
