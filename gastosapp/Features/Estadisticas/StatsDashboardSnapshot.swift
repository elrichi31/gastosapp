import Foundation

struct StatsDashboardSnapshot {
    let selectedYear: Int
    let selectedMonth: Int
    let selectedCategoryID: Int?

    let yearBudgets: [BudgetMonthly]
    let yearExpenses: [Expense]
    let filteredYearExpenses: [Expense]
    let annualBudget: Double
    let annualSpent: Double
    let annualBalance: Double
    let balanceSubtitle: String
    let budgetUsageLabel: String

    let monthPoints: [MonthlyComparisonPoint]
    let visibleMonthPoints: [MonthlyComparisonPoint]
    let selectedPoint: MonthlyComparisonPoint?
    let chartUpperBound: Double
    let categoriesWithSpending: [Categoria]

    let selectedMonthExpenses: [Expense]
    let selectedMonthTotalSpent: Double
    let selectedMonthSpent: Double
    let selectedMonthSpentByCategory: [Int: Double]
    let selectedMonthBudget: Double
    let selectedMonthBudgetRecord: BudgetMonthly?
    let selectedMonthIsCurrentMonth: Bool
    let selectedMonthElapsedDays: Int
    let selectedMonthTotalDays: Int
    let selectedProjection: Double
    let selectedExpectedSpendToDate: Double
    let selectedMonthIsAheadOfPace: Bool
    let projectionDeltaLabel: String
    let expectedUsageLabel: String
    let selectedMonthName: String

    let selectedBudgetCategoryPlans: [CategoryBudgetPlan]
    let smartBudgetSignals: [SmartBudgetSignal]
    let selectedMonthCategoryTotals: [CategoryTotal]
    let insights: [StatsInsight]
    let topYearCategory: CategoryTotal?

    init(
        budgets: [BudgetMonthly],
        expenses: [Expense],
        categories: [Categoria],
        budgetDetailCategories: [BudgetCategoryDetail],
        selectedYear: Int,
        selectedMonth: Int,
        selectedCategoryID: Int?,
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.selectedYear = selectedYear
        self.selectedMonth = selectedMonth
        self.selectedCategoryID = selectedCategoryID

        yearBudgets = budgets.filter { $0.anio == selectedYear }

        if
            let start = calendar.date(from: DateComponents(year: selectedYear, month: 1, day: 1)),
            let end = calendar.date(byAdding: .year, value: 1, to: start)
        {
            yearExpenses = expenses.filter { $0.fecha >= start && $0.fecha < end }
        } else {
            yearExpenses = []
        }

        if let selectedCategoryID {
            filteredYearExpenses = yearExpenses.filter { $0.categoriaId == selectedCategoryID }
        } else {
            filteredYearExpenses = yearExpenses
        }

        annualBudget = yearBudgets.reduce(0) { $0 + $1.total }
        annualSpent = filteredYearExpenses.reduce(0) { $0 + $1.monto }
        annualBalance = annualBudget - annualSpent
        if annualBudget <= 0 {
            balanceSubtitle = "Crea presupuestos para comparar contra tus gastos reales."
        } else {
            balanceSubtitle = annualBalance >= 0 ? "Disponible frente al plan anual" : "Por encima del plan anual"
        }
        if annualBudget > 0 {
            budgetUsageLabel = "\(Int(round((annualSpent / annualBudget) * 100)))%"
        } else {
            budgetUsageLabel = "0%"
        }

        let budgetsByMonth = Dictionary(grouping: yearBudgets, by: \.mes)
            .mapValues { $0.reduce(0) { $0 + $1.total } }
        let expensesByMonth = Dictionary(grouping: filteredYearExpenses) { expense in
            calendar.component(.month, from: expense.fecha)
        }
        monthPoints = (1...12).compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: selectedYear, month: month, day: 1)) else { return nil }
            let spentExpenses = expensesByMonth[month] ?? []
            let spent = spentExpenses.reduce(0) { $0 + $1.monto }
            return MonthlyComparisonPoint(
                month: month,
                date: date,
                budgeted: budgetsByMonth[month] ?? 0,
                spent: spent,
                expenseCount: spentExpenses.count,
                monthName: Self.monthName(month)
            )
        }
        visibleMonthPoints = monthPoints.filter { $0.expenseCount > 0 }
        selectedPoint = visibleMonthPoints.first { $0.month == selectedMonth }
        let maxValue = visibleMonthPoints.flatMap { [$0.budgeted, $0.spent] }.max() ?? 0
        chartUpperBound = max(maxValue * 1.18, 100)

        let categoryIDsWithSpending = Set(yearExpenses.map(\.categoriaId))
        categoriesWithSpending = categories
            .filter { categoryIDsWithSpending.contains($0.id) }
            .sorted { $0.nombre.localizedCaseInsensitiveCompare($1.nombre) == .orderedAscending }

        let selectedMonthRange: Range<Date>? = {
            guard
                let start = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)),
                let end = calendar.date(byAdding: .month, value: 1, to: start)
            else {
                return nil
            }
            return start..<end
        }()

        if let selectedMonthRange {
            selectedMonthExpenses = filteredYearExpenses.filter { selectedMonthRange.contains($0.fecha) }
            let selectedMonthAllExpenses = yearExpenses.filter { selectedMonthRange.contains($0.fecha) }
            selectedMonthTotalSpent = selectedMonthAllExpenses.reduce(0) { $0 + $1.monto }
            selectedMonthSpentByCategory = Dictionary(grouping: selectedMonthAllExpenses, by: \.categoriaId)
                .mapValues { $0.reduce(0) { $0 + $1.monto } }
        } else {
            selectedMonthExpenses = []
            selectedMonthTotalSpent = 0
            selectedMonthSpentByCategory = [:]
        }

        selectedMonthSpent = selectedMonthExpenses.reduce(0) { $0 + $1.monto }
        selectedMonthBudget = monthPoints.first { $0.month == selectedMonth }?.budgeted ?? 0
        selectedMonthBudgetRecord = yearBudgets.first { $0.mes == selectedMonth }

        let nowComponents = calendar.dateComponents([.year, .month], from: now)
        selectedMonthIsCurrentMonth = nowComponents.year == selectedYear && nowComponents.month == selectedMonth
        if let monthDate = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth, day: 1)) {
            selectedMonthTotalDays = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? 30
        } else {
            selectedMonthTotalDays = 30
        }
        selectedMonthElapsedDays = selectedMonthIsCurrentMonth ? max(calendar.component(.day, from: now), 1) : selectedMonthTotalDays
        if selectedMonthElapsedDays > 0, selectedMonthTotalSpent > 0, selectedMonthIsCurrentMonth {
            selectedProjection = selectedMonthTotalSpent / Double(selectedMonthElapsedDays) * Double(selectedMonthTotalDays)
        } else {
            selectedProjection = selectedMonthTotalSpent
        }
        if selectedMonthBudget > 0, selectedMonthTotalDays > 0 {
            selectedExpectedSpendToDate = selectedMonthBudget * (Double(selectedMonthElapsedDays) / Double(selectedMonthTotalDays))
        } else {
            selectedExpectedSpendToDate = 0
        }
        selectedMonthIsAheadOfPace = selectedMonthBudget > 0 && selectedMonthTotalSpent > selectedExpectedSpendToDate
        if selectedMonthBudget > 0 {
            let delta = selectedMonthBudget - selectedProjection
            projectionDeltaLabel = (delta >= 0 ? "+" : "-") + abs(delta).budgetCurrency
        } else {
            projectionDeltaLabel = "$0.00"
        }
        if selectedExpectedSpendToDate > 0 {
            expectedUsageLabel = "\(Int(round((selectedMonthTotalSpent / selectedExpectedSpendToDate) * 100)))%"
        } else {
            expectedUsageLabel = "0%"
        }
        selectedMonthName = Self.monthName(selectedMonth)

        let computedSelectedMonthSpentByCategory = selectedMonthSpentByCategory
        let computedSelectedMonthIsCurrentMonth = selectedMonthIsCurrentMonth
        let computedSelectedMonthElapsedDays = selectedMonthElapsedDays
        let computedSelectedMonthTotalDays = selectedMonthTotalDays
        let computedSelectedBudgetCategoryPlans = budgetDetailCategories.map { category in
            let spent = computedSelectedMonthSpentByCategory[category.categoriaId] ?? 0
            return CategoryBudgetPlan(
                category: category.displayCategory,
                budgeted: category.budgetedAmount,
                spent: spent,
                projected: Self.projectedAmount(
                    spent,
                    isCurrentMonth: computedSelectedMonthIsCurrentMonth,
                    elapsedDays: computedSelectedMonthElapsedDays,
                    totalDays: computedSelectedMonthTotalDays
                )
            )
        }
        .sorted { lhs, rhs in
            if lhs.riskScore != rhs.riskScore { return lhs.riskScore > rhs.riskScore }
            return lhs.category.nombre.localizedCaseInsensitiveCompare(rhs.category.nombre) == .orderedAscending
        }

        var computedSignals: [SmartBudgetSignal] = []
        if selectedMonthBudget <= 0 {
            computedSignals = [
                SmartBudgetSignal(
                    icon: "target",
                    tint: AppTheme.secondaryAccent,
                    title: "Crea un presupuesto para este mes",
                    message: "Con un presupuesto mensual puedo calcular alertas tempranas y proyecciones de cierre."
                )
            ]
        } else {
            if selectedProjection > selectedMonthBudget {
                computedSignals.append(
                    SmartBudgetSignal(
                        icon: "exclamationmark.triangle.fill",
                        tint: AppTheme.warning,
                        title: "Alerta antes de pasarte",
                        message: "A este ritmo terminaras en \(selectedProjection.budgetCurrency), \(abs(selectedMonthBudget - selectedProjection).budgetCurrency) por encima del presupuesto."
                    )
                )
            } else if selectedMonthIsAheadOfPace {
                computedSignals.append(
                    SmartBudgetSignal(
                        icon: "speedometer",
                        tint: AppTheme.warning,
                        title: "Vas más rápido que el plan",
                        message: "Para el día \(selectedMonthElapsedDays) lo esperado era \(selectedExpectedSpendToDate.budgetCurrency), y ya vas en \(selectedMonthTotalSpent.budgetCurrency)."
                    )
                )
            } else {
                computedSignals.append(
                    SmartBudgetSignal(
                        icon: "checkmark.seal.fill",
                        tint: AppTheme.accent,
                        title: "Ritmo saludable",
                        message: "La proyección de cierre está dentro del presupuesto de \(selectedMonthBudget.budgetCurrency)."
                    )
                )
            }

            let categorySignals = computedSelectedBudgetCategoryPlans.compactMap { plan -> SmartBudgetSignal? in
                guard plan.budgeted > 0, plan.projected > plan.budgeted * 0.92 else { return nil }
                let adjustment = max(plan.projected - plan.budgeted, 0)
                if adjustment > 0 {
                    return SmartBudgetSignal(
                        icon: plan.category.icono,
                        tint: plan.category.color,
                        title: "Ajusta \(plan.category.nombre)",
                        message: "Proyecta \(plan.projected.budgetCurrency) contra \(plan.budgeted.budgetCurrency). Considera subirla en \(adjustment.budgetCurrency) o recortar gasto."
                    )
                }
                return SmartBudgetSignal(
                    icon: plan.category.icono,
                    tint: plan.category.color,
                    title: "\(plan.category.nombre) está cerca del límite",
                    message: "Ya consumio \(plan.usageLabel) del presupuesto. Conviene frenar antes de cruzar el 100%."
                )
            }
            computedSignals.append(contentsOf: categorySignals.prefix(2))

            if computedSignals.count == 1, budgetDetailCategories.isEmpty {
                computedSignals.append(
                    SmartBudgetSignal(
                        icon: "square.grid.2x2.fill",
                        tint: AppTheme.secondaryAccent,
                        title: "Agrega categorías al presupuesto",
                        message: "Cuando el mes tenga categorías presupuestadas, puedo recomendar dónde subir o bajar montos."
                    )
                )
            }
        }
        selectedBudgetCategoryPlans = computedSelectedBudgetCategoryPlans
        smartBudgetSignals = Array(computedSignals.prefix(3))

        selectedMonthCategoryTotals = Dictionary(grouping: selectedMonthExpenses, by: \.categoria)
            .map { category, items in
                CategoryTotal(category: category, amount: items.reduce(0) { $0 + $1.monto })
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                return lhs.category.nombre.localizedCaseInsensitiveCompare(rhs.category.nombre) == .orderedAscending
            }

        topYearCategory = Dictionary(grouping: filteredYearExpenses, by: \.categoria)
            .map { category, items in
                CategoryTotal(category: category, amount: items.reduce(0) { $0 + $1.monto })
            }
            .max { $0.amount < $1.amount }

        var computedInsights: [StatsInsight] = []
        if let highestMonth = visibleMonthPoints.max(by: { $0.spent < $1.spent }), highestMonth.spent > 0 {
            computedInsights.append(
                StatsInsight(
                    icon: "flame.fill",
                    tint: AppTheme.warning,
                    title: "Mes con mas gasto: \(highestMonth.monthName)",
                    message: "Ese mes suma \(highestMonth.spent.budgetCurrency), con \(highestMonth.expenseCount) movimientos registrados."
                )
            )
        }

        if let worstVariance = visibleMonthPoints.min(by: { $0.variance < $1.variance }), worstVariance.budgeted > 0, worstVariance.variance < 0 {
            computedInsights.append(
                StatsInsight(
                    icon: "arrow.up.forward.circle.fill",
                    tint: AppTheme.negative,
                    title: "Mayor desvio del presupuesto",
                    message: "\(worstVariance.monthName) se pasó por \((-worstVariance.variance).budgetCurrency). Revisa categorías de ese mes abajo."
                )
            )
        } else if annualBudget > 0 {
            computedInsights.append(
                StatsInsight(
                    icon: "checkmark.circle.fill",
                    tint: AppTheme.accent,
                    title: "Sin meses por encima del plan",
                    message: "Con los datos cargados, el gasto real se mantiene dentro de lo presupuestado."
                )
            )
        }

        if let topYearCategory {
            computedInsights.append(
                StatsInsight(
                    icon: topYearCategory.category.icono,
                    tint: topYearCategory.category.color,
                    title: "Categoría dominante: \(topYearCategory.category.nombre)",
                    message: "Representa \(topYearCategory.amount.budgetCurrency) del gasto anual filtrado."
                )
            )
        }

        if computedInsights.isEmpty {
            computedInsights.append(
                StatsInsight(
                    icon: "chart.line.uptrend.xyaxis",
                    tint: AppTheme.secondaryAccent,
                    title: "Aun faltan datos para leer patrones",
                    message: "Cuando registres gastos y presupuestos, esta sección mostrará desvíos, categorías fuertes y oportunidades."
                )
            )
        }
        insights = Array(computedInsights.prefix(3))
    }

    static func placeholder(
        selectedYear: Int = Calendar.current.component(.year, from: Date()),
        selectedMonth: Int = Calendar.current.component(.month, from: Date()),
        selectedCategoryID: Int? = nil
    ) -> StatsDashboardSnapshot {
        StatsDashboardSnapshot(
            budgets: [],
            expenses: [],
            categories: [],
            budgetDetailCategories: [],
            selectedYear: selectedYear,
            selectedMonth: selectedMonth,
            selectedCategoryID: selectedCategoryID
        )
    }

    func normalizedSelectedMonth(currentMonth: Int) -> Int {
        if visibleMonthPoints.contains(where: { $0.month == selectedMonth }) {
            return selectedMonth
        }
        if let currentYearPoint = visibleMonthPoints.first(where: { $0.month == currentMonth }) {
            return currentYearPoint.month
        }
        return visibleMonthPoints.first?.month ?? selectedMonth
    }

    private static func projectedAmount(_ spent: Double, isCurrentMonth: Bool, elapsedDays: Int, totalDays: Int) -> Double {
        guard spent > 0 else { return 0 }
        if isCurrentMonth, elapsedDays > 0 {
            return spent / Double(elapsedDays) * Double(totalDays)
        }
        return spent
    }

    private static func monthName(_ month: Int) -> String {
        guard StatsView.spanishMonthSymbols.indices.contains(month - 1) else { return "Mes" }
        return StatsView.spanishMonthSymbols[month - 1].capitalized
    }
}
