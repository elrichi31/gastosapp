import SwiftUI
import Charts

struct StatsView: View {
    @Environment(ExpenseStore.self) private var expenses
    @Environment(BudgetStore.self) private var budgets
    @State private var budgetDetailStore = BudgetDetailStore()
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var selectedCategoryID: Int?
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())
    @State private var selectedDailyBar: DailyExpenseBar?
    @State private var dashboardSnapshot = StatsDashboardSnapshot.placeholder()

    private let calendar = Calendar.current
    static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    summaryHero
                    categoryFilter
                    comparisonChartCard
                    recentDaysCard
                    smartBudgetCard
                    insightsCard
                    monthlyExplorerCard
                    categoryBreakdownCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            StatsHeaderBar(
                year: selectedYear,
                onPreviousYear: { changeYear(by: -1) },
                onNextYear: { changeYear(by: 1) }
            )
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 12)
        }
        .task { await loadData() }
        .onChange(of: selectedCategoryID) { _, _ in
            rebuildDashboardSnapshot()
            let changedMonth = normalizeSelectedMonth()
            if !changedMonth {
                Task { await loadSelectedBudgetDetail() }
            }
        }
        .onChange(of: selectedMonth) { _, _ in
            rebuildDashboardSnapshot()
            Task { await loadSelectedBudgetDetail() }
        }
        .onChange(of: selectedYear) { _, _ in
            rebuildDashboardSnapshot()
        }
        .onChange(of: expenses.gastos) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: expenses.categorias) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: budgets.budgets) {
            rebuildDashboardSnapshot()
        }
        .onChange(of: budgetDetailStore.categories) {
            rebuildDashboardSnapshot()
        }
    }

    private var summaryHero: some View {
        let isPositive = dashboardSnapshot.annualBalance >= 0
        let tint = isPositive ? AppTheme.accent : AppTheme.warning

        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    AppSectionLabel(text: "Balance del año")
                    Text(dashboardSnapshot.annualBalance, format: .currency(code: "USD").precision(.fractionLength(2)))
                        .font(AppTheme.number(42, .bold))
                        .monospacedDigit()
                        .kerning(-1.2)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    Text(dashboardSnapshot.balanceSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Image(systemName: isPositive ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(tint.opacity(0.14)))
            }

            AppHairline()

            HStack(spacing: 8) {
                summaryMetric(title: "Presupuesto", value: dashboardSnapshot.annualBudget.budgetCurrency)
                summaryMetric(title: "Gastado", value: dashboardSnapshot.annualSpent.budgetCurrency)
                summaryMetric(title: "Uso", value: dashboardSnapshot.budgetUsageLabel)
            }
        }
        .padding(22)
        .background(AppTheme.cardBackground(cornerRadius: 28))
        .accessibilityElement(children: .combine)
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            AppSectionLabel(text: title, size: 10)
            Text(value)
                .font(AppTheme.number(14, .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.insetBackground(cornerRadius: 14))
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                filterButton(title: "Todo", icon: "square.grid.2x2.fill", categoryID: nil)
                ForEach(dashboardSnapshot.categoriesWithSpending) { category in
                    filterButton(title: category.nombre, icon: category.icono, categoryID: category.id)
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -20)
    }

    private func filterButton(title: String, icon: String, categoryID: Int?) -> some View {
        let isSelected = selectedCategoryID == categoryID
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedCategoryID = categoryID
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .black : AppTheme.primaryText.opacity(0.72))
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(Capsule().fill(isSelected ? AppTheme.accent : AppTheme.controlSurface))
            .overlay(Capsule().stroke(isSelected ? Color.clear : AppTheme.strongBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var comparisonChartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Presupuestado vs real",
                subtitle: selectedCategoryID == nil ? "mes a mes" : "gasto filtrado por categoria"
            )

            Chart {
                ForEach(dashboardSnapshot.visibleMonthPoints) { point in
                    LineMark(
                        x: .value("Mes", point.date, unit: .month),
                        y: .value("Presupuestado", point.budgeted),
                        series: .value("Serie", "Presupuestado")
                    )
                    .foregroundStyle(AppTheme.accent)
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Mes", point.date, unit: .month),
                        y: .value("Presupuestado", point.budgeted)
                    )
                    .foregroundStyle(AppTheme.accent)
                    .symbolSize(point.month == selectedMonth ? 70 : 26)
                }

                ForEach(dashboardSnapshot.visibleMonthPoints) { point in
                    LineMark(
                        x: .value("Mes", point.date, unit: .month),
                        y: .value("Gastado", point.spent),
                        series: .value("Serie", "Gastado real")
                    )
                    .foregroundStyle(AppTheme.secondaryAccent)
                    .interpolationMethod(.monotone)

                    PointMark(
                        x: .value("Mes", point.date, unit: .month),
                        y: .value("Gastado", point.spent)
                    )
                    .foregroundStyle(AppTheme.secondaryAccent)
                    .symbolSize(point.month == selectedMonth ? 70 : 26)
                }

                if let point = dashboardSnapshot.selectedPoint {
                    RuleMark(x: .value("Seleccion", point.date, unit: .month))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.18))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                }
            }
            .chartXAxis {
                AxisMarks(values: dashboardSnapshot.visibleMonthPoints.map(\.date)) { _ in
                    AxisGridLine().foregroundStyle(AppTheme.primaryText.opacity(0.05))
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.45))
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(AppTheme.primaryText.opacity(0.06))
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(shortCurrency(amount))
                                .foregroundStyle(AppTheme.primaryText.opacity(0.45))
                        }
                    }
                }
            }
            .chartYScale(domain: 0...dashboardSnapshot.chartUpperBound)
            .frame(height: 230)
            .accessibilityLabel("Gráfica de líneas de presupuesto contra gasto real")
            .overlay {
                if dashboardSnapshot.visibleMonthPoints.isEmpty {
                    Text("Sin meses con registros para este filtro.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.48))
                }
            }

            legendRow
            selectedMonthDetail
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var legendRow: some View {
        HStack(spacing: 14) {
            legendItem(color: AppTheme.accent, title: "Presupuestado")
            legendItem(color: AppTheme.secondaryAccent, title: "Gastado real")
            Spacer()
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.62))
        }
    }

    private var selectedMonthDetail: some View {
        let point = dashboardSnapshot.selectedPoint ?? dashboardSnapshot.visibleMonthPoints.first
        return HStack(spacing: 10) {
            statPill(title: point?.monthName ?? "Mes", value: point?.varianceLabel ?? "$0.00", tint: point?.isOverBudget == true ? AppTheme.warning : AppTheme.accent)
            statPill(title: "Gastos", value: "\(point?.expenseCount ?? 0)", tint: AppTheme.secondaryAccent)
            statPill(title: "Uso", value: point?.usageLabel ?? "0%", tint: AppTheme.primaryText.opacity(0.72))
        }
    }

    /// Serie diaria de los últimos 30 días. Vivía en el Inicio detrás de un
    /// toggle de "Ver análisis"; su lugar natural es esta pestaña.
    private var recentDaysCard: some View {
        HomeRecent30DaysSection(
            bars: DailyExpenseBar.recentBars(from: expenses.gastos, calendar: calendar),
            selectedBar: $selectedDailyBar,
            dayLabel: dayLabel(for:),
            accessibilityLabel: dailyBarAccessibilityLabel
        )
    }

    private func dayLabel(for date: Date?) -> String {
        guard let date else { return "" }
        let components = calendar.dateComponents([.day, .month], from: date)
        guard
            let day = components.day,
            let month = components.month,
            Self.spanishMonthSymbols.indices.contains(month - 1)
        else {
            return ""
        }
        return "\(day) \(Self.spanishMonthSymbols[month - 1].prefix(3))"
    }

    private func dailyBarAccessibilityLabel(_ bar: DailyExpenseBar) -> String {
        guard bar.total > 0 else { return "\(dayLabel(for: bar.date)), sin gastos" }
        let categories = bar.segments
            .map { "\($0.categoryName) \($0.amount.budgetCurrency)" }
            .joined(separator: ", ")
        return "\(dayLabel(for: bar.date)), total \(bar.total.budgetCurrency), \(categories)"
    }

    private var highestExpenseInSelectedMonth: Double {
        expenses.gastos
            .filter {
                calendar.component(.year, from: $0.fecha) == selectedYear
                    && calendar.component(.month, from: $0.fecha) == selectedMonth
            }
            .map(\.monto)
            .max() ?? 0
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.primaryText.opacity(0.42))
            Text(value)
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }

    private var insightsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Lecturas utiles", subtitle: "senales de tus datos")

            VStack(spacing: 10) {
                ForEach(dashboardSnapshot.insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(insight.tint)
                            .frame(width: 30, height: 30)
                            .background(insight.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(insight.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text(insight.message)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText.opacity(0.52))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.insetSurface)
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                    )
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var smartBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Presupuesto inteligente", subtitle: dashboardSnapshot.selectedMonthName)

            HStack(spacing: 10) {
                statPill(title: "Proyección", value: dashboardSnapshot.selectedProjection.budgetCurrency, tint: dashboardSnapshot.selectedProjection > dashboardSnapshot.selectedMonthBudget ? AppTheme.warning : AppTheme.accent)
                statPill(title: "A este ritmo", value: dashboardSnapshot.projectionDeltaLabel, tint: dashboardSnapshot.selectedProjection > dashboardSnapshot.selectedMonthBudget ? AppTheme.warning : AppTheme.secondaryAccent)
                statPill(title: "Uso esperado", value: dashboardSnapshot.expectedUsageLabel, tint: dashboardSnapshot.selectedMonthIsAheadOfPace ? AppTheme.warning : AppTheme.accent)
                statPill(title: "Mayor gasto", value: highestExpenseInSelectedMonth.budgetCurrency, tint: AppTheme.secondaryAccent)
            }

            VStack(spacing: 10) {
                ForEach(dashboardSnapshot.smartBudgetSignals) { signal in
                    smartSignalRow(signal)
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private func smartSignalRow(_ signal: SmartBudgetSignal) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: signal.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(signal.tint)
                .frame(width: 30, height: 30)
                .background(signal.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(signal.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(signal.message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.52))
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
        )
    }

    private var monthlyExplorerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Explorar por mes", subtitle: "solo meses con registros")

            VStack(spacing: 8) {
                if dashboardSnapshot.visibleMonthPoints.isEmpty {
                    Text("No hay gastos registrados para explorar en este filtro.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.48))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                } else {
                    ForEach(dashboardSnapshot.visibleMonthPoints) { point in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                                selectedMonth = point.month
                            }
                        } label: {
                            MonthlyStatsRow(point: point, isSelected: selectedMonth == point.month)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "Categorías", subtitle: dashboardSnapshot.selectedMonthName)

            if dashboardSnapshot.selectedMonthCategoryTotals.isEmpty {
                Text("Sin gastos registrados en este mes.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.48))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
            } else {
                VStack(spacing: 14) {
                    ForEach(dashboardSnapshot.selectedMonthCategoryTotals) { item in
                        categoryRow(item)
                    }
                }
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private func categoryRow(_ item: CategoryTotal) -> some View {
        let percentage = dashboardSnapshot.selectedMonthSpent > 0 ? item.amount / dashboardSnapshot.selectedMonthSpent : 0
        return VStack(spacing: 8) {
            HStack(spacing: 11) {
                Image(systemName: item.category.icono)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 34, height: 34)
                    .background(item.category.color, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(item.category.nombre)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Spacer()
                Text(item.amount, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(Int(round(percentage * 100)))%")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                    .frame(width: 42, alignment: .trailing)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.insetSurface)
                    Capsule()
                        .fill(item.category.color)
                        .frame(width: max(proxy.size.width * percentage, item.amount > 0 ? 8 : 0))
                }
            }
            .frame(height: 6)
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title3, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
            Spacer()
            Text(subtitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.42))
                .lineLimit(1)
        }
    }

    private func changeYear(by delta: Int) {
        selectedYear += delta
        selectedCategoryID = nil
        selectedMonth = selectedYear == calendar.component(.year, from: Date())
            ? calendar.component(.month, from: Date())
            : 1
        Task { await loadData(force: true) }
    }

    private func loadData(force: Bool = false) async {
        let needsBudgetRefresh = force || budgets.selectedYear != selectedYear || budgets.budgets.allSatisfy { $0.anio != selectedYear }
        budgets.selectedYear = selectedYear
        await budgets.loadBudgets(using: expenses, force: needsBudgetRefresh)
        if force {
            await expenses.loadExpenses(force: true)
        } else {
            await expenses.loadExpensesIfNeeded()
        }
        rebuildDashboardSnapshot()
        let changedMonth = normalizeSelectedMonth()
        if !changedMonth {
            await loadSelectedBudgetDetail()
        }
    }

    private func loadSelectedBudgetDetail() async {
        guard let budget = dashboardSnapshot.selectedMonthBudgetRecord else {
            budgetDetailStore.categories = []
            rebuildDashboardSnapshot()
            return
        }
        await budgetDetailStore.loadDetail(using: expenses, budgetID: budget.id)
        rebuildDashboardSnapshot()
    }

    @discardableResult
    private func normalizeSelectedMonth() -> Bool {
        let normalizedMonth = dashboardSnapshot.normalizedSelectedMonth(currentMonth: calendar.component(.month, from: Date()))
        guard normalizedMonth != selectedMonth else { return false }
        selectedMonth = normalizedMonth
        return true
    }

    private func rebuildDashboardSnapshot() {
        dashboardSnapshot = StatsDashboardSnapshot(
            budgets: budgets.budgets,
            expenses: expenses.gastos,
            categories: expenses.categorias,
            budgetDetailCategories: budgetDetailStore.categories,
            selectedYear: selectedYear,
            selectedMonth: selectedMonth,
            selectedCategoryID: selectedCategoryID,
            calendar: calendar
        )
    }

    private func shortCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return "$\(Int(value / 1000))k"
        }
        return "$\(Int(value))"
    }
}

private struct StatsHeaderBar: View {
    let year: Int
    let onPreviousYear: () -> Void
    let onNextYear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Estadisticas")
                .font(.system(.title3, design: .default, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)

            Spacer()
            yearSelector
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
        .background(headerBackground)
    }

    private var yearSelector: some View {
        HStack(spacing: 2) {
            yearButton(icon: "chevron.left", action: onPreviousYear, label: "Año anterior")
            Text(verbatim: "\(year)")
                .font(.caption.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
                .frame(minWidth: 42)
            yearButton(icon: "chevron.right", action: onNextYear, label: "Año siguiente")
        }
        .padding(3)
        .background(
            Capsule()
                .fill(AppTheme.controlSurface)
                .overlay(Capsule().stroke(AppTheme.border, lineWidth: 1))
        )
    }

    private func yearButton(icon: String, action: @escaping () -> Void, label: String) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.8))
                .frame(width: 26, height: 26)
                .background(Circle().fill(AppTheme.insetSurface))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(AppTheme.chromeSurface)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.primaryText.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
    }
}

private struct MonthlyStatsRow: View {
    let point: MonthlyComparisonPoint
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(point.shortMonthName)
                .font(.caption.weight(.bold))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.primaryText.opacity(0.52))
                .frame(width: 36, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 5) {
                    progressTrack(ratio: point.budgetRatio, color: AppTheme.accent)
                    progressTrack(ratio: point.spentRatio, color: AppTheme.secondaryAccent)
                }

                Text(point.expenseCount == 1 ? "1 gasto" : "\(point.expenseCount) gastos")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isSelected ? AppTheme.primaryText.opacity(0.72) : AppTheme.primaryText.opacity(0.42))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 4) {
                Text(point.spent, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                Text(point.varianceLabel)
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(point.varianceColor)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? AppTheme.surface : AppTheme.insetSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isSelected ? AppTheme.accent.opacity(0.72) : AppTheme.border, lineWidth: isSelected ? 1.5 : 1)
                )
        )
    }

    private func progressTrack(ratio: Double, color: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.controlSurface)
                Capsule()
                    .fill(color.opacity(isSelected ? 0.95 : 0.82))
                    .frame(width: max(proxy.size.width * ratio, ratio > 0 ? 8 : 0))
            }
        }
        .frame(height: 9)
    }
}

struct MonthlyComparisonPoint: Identifiable {
    let month: Int
    let date: Date
    let budgeted: Double
    let spent: Double
    let expenseCount: Int
    let monthName: String

    var id: Int { month }
    var variance: Double { budgeted - spent }
    var isOverBudget: Bool { budgeted > 0 && spent > budgeted }
    var usageLabel: String {
        guard budgeted > 0 else { return "0%" }
        return "\(Int(round((spent / budgeted) * 100)))%"
    }
    var varianceLabel: String {
        if variance == 0 { return "$0.00" }
        let prefix = variance > 0 ? "+" : "-"
        return prefix + abs(variance).budgetCurrency
    }
    var varianceColor: Color {
        variance >= 0 ? AppTheme.accent : AppTheme.warning
    }
    var shortMonthName: String {
        String(monthName.prefix(3)).uppercased()
    }
    var budgetRatio: Double {
        maxRatioValue > 0 ? min(1, budgeted / maxRatioValue) : 0
    }
    var spentRatio: Double {
        maxRatioValue > 0 ? min(1, spent / maxRatioValue) : 0
    }
    private var maxRatioValue: Double {
        max(budgeted, spent)
    }
}

struct CategoryTotal: Identifiable {
    let category: Categoria
    let amount: Double

    var id: Int { category.id }
}

struct CategoryBudgetPlan: Identifiable {
    let category: Categoria
    let budgeted: Double
    let spent: Double
    let projected: Double

    var id: Int { category.id }
    var usage: Double {
        guard budgeted > 0 else { return 0 }
        return spent / budgeted
    }
    var usageLabel: String {
        "\(Int(round(usage * 100)))%"
    }
    var riskScore: Double {
        guard budgeted > 0 else { return 0 }
        return projected / budgeted
    }
}

struct StatsInsight: Identifiable {
    let icon: String
    let tint: Color
    let title: String
    let message: String

    var id: String { "\(title)-\(message)" }
}

struct SmartBudgetSignal: Identifiable {
    let icon: String
    let tint: Color
    let title: String
    let message: String

    var id: String { "\(title)-\(message)" }
}

#Preview {
    StatsView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
