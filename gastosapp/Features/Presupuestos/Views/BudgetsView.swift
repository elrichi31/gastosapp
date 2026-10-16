import SwiftUI

/// Plan: presupuesto mes a mes, según el canvas «Plan».
///
/// Arriba el gasto registrado del año con tres cifras de apoyo y la evolución
/// mensual; debajo, una tarjeta por mes creado con su variación.
struct BudgetsView: View {
    private enum Route: Hashable {
        case detail(BudgetMonthly)
    }

    private enum PresentedSheet: String, Identifiable {
        case addBudget

        var id: String { rawValue }
    }

    @Environment(ExpenseStore.self) private var session
    @Environment(BudgetStore.self) private var budgets
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
    @State private var presentedSheet: PresentedSheet?
    @State private var budgetToDelete: BudgetMonthly?
    @State private var path: [Route] = []

    private static let cal = Calendar.current
    private static let monthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols.map(\.capitalized)
    }()
    private static let monthInitials = ["E", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]

    private var currentYear: Int { Self.cal.component(.year, from: Date()) }
    private var currentMonth: Int { Self.cal.component(.month, from: Date()) }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AppTheme.screenBackground.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 4) {
                            header
                            intro
                        }
                        content
                            .animation(AppMotion.fade, value: budgets.isLoadingBudgets)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, AppScreenMetrics.contentBottomPadding)
                }
                .tracksScrollChrome()
                .floatingTabBarInset()
                .refreshable { await loadAnnualData(force: true) }

                if let toastMessage = budgets.saveStatusMessage {
                    TransientStatusToast(text: toastMessage, tint: AppTheme.accent, icon: "checkmark.circle.fill")
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.bottom, AppScreenMetrics.toastBottomPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(AppMotion.toast)
                        .zIndex(2)
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case let .detail(budget):
                    BudgetDetailView(budget: budget)
                        .onDisappear(perform: refreshBudgets)
                        .floatingTabBarInset()
                }
            }
            .appTopBarPanels()
            .safeAreaInset(edge: .top, spacing: 0) {
                // Sólo la barra queda fija; el título va dentro del contenido.
                Group {
                    if navigator != nil {
                        AppTopBar()
                            .padding(.horizontal, -4)
                    }
                }
                    .padding(.horizontal, 20)
                    .padding(.top, AppScreenMetrics.headerTopPadding)
                    .padding(.bottom, AppScreenMetrics.headerBottomPadding)
                    .background {
                        ScrollAwareHeaderScrim()
                    }
            }
            .task { await loadAnnualData() }
        }
        .alert("Quitar mes", isPresented: deleteAlertBinding) {
            Button("Cancelar", role: .cancel) { budgetToDelete = nil }
            Button("Quitar", role: .destructive, action: deleteSelectedBudget)
        } message: {
            Text("Se eliminará el presupuesto de ese mes.")
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .addBudget:
                AddBudgetSheet(defaultYear: budgets.selectedYear)
                    .presentationDetents([.height(360)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 8) {
            Text("Plan")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if canAddMonths {
                AppCircleButton(icon: "plus", label: "Agregar mes") { presentedSheet = .addBudget }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tu presupuesto mes a mes, por categoría.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
            yearSelector
        }
    }

    /// Año anterior, actual y siguiente; si se eligió otro, se añade.
    private var years: [Int] {
        Array(Set([currentYear - 1, currentYear, currentYear + 1, budgets.selectedYear])).sorted()
    }

    private var yearSelector: some View {
        HStack(spacing: 0) {
            ForEach(years, id: \.self) { year in
                let isSelected = year == budgets.selectedYear
                Button {
                    selectYear(year)
                } label: {
                    Text(verbatim: "\(year)")
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(AppTheme.popoverSurface))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Año")
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        if budgets.isLoadingBudgets && budgets.budgets.isEmpty {
            ListRowsSkeleton(label: "Cargando presupuestos")
                .transition(.opacity)
        } else if yearBudgets.isEmpty {
            emptyYear
        } else {
            yearSummary
            monthlyEvolution
            VStack(spacing: 12) {
                ForEach(yearBudgets) { budget in
                    monthCard(budget)
                }
                if canAddMonths {
                    addMonthButton
                }
            }
        }
    }

    private var yearSummary: some View {
        let stats = yearStats
        return VStack(alignment: .leading, spacing: 10) {
            (Text("Gasto registrado ") + Text("· \(String(budgets.selectedYear))").fontWeight(.regular).foregroundColor(AppTheme.secondaryText))
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.primaryText)
                .padding(.bottom, 2)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total \(String(budgets.selectedYear))")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                    splitAmount(stats.total, size: 44)
                }
                Spacer(minLength: 8)
                Text(yearBudgets.count == 1 ? "1 mes" : "\(yearBudgets.count) meses")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.2)))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.statementBackground())
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                statTile(
                    icon: "chart.bar",
                    tint: AppTheme.info,
                    label: "Promedio mensual",
                    value: money(stats.average),
                    foot: "\(stats.monthsWithSpending) con movimiento"
                )
                statTile(
                    icon: "list.bullet.rectangle",
                    tint: AppTheme.secondaryAccent,
                    label: "Gastos registrados",
                    value: "\(stats.count)",
                    foot: stats.count > 0 ? "\(money(stats.total / Double(stats.count))) promedio" : "—"
                )
            }

            HStack(spacing: 14) {
                roundGlyph("arrow.up.right", tint: AppTheme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mes más alto")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                    Text(stats.highest.map { Self.monthSymbols[$0.month - 1] } ?? "sin datos")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                }
                Spacer(minLength: 8)
                Text(stats.highest.map { money($0.total) } ?? "—")
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(AppTheme.cardBackground())
            .accessibilityElement(children: .combine)
        }
    }

    private func statTile(icon: String, tint: Color, label: String, value: String, foot: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            roundGlyph(icon, tint: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(foot)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground())
        .accessibilityElement(children: .combine)
    }

    private var monthlyEvolution: some View {
        let totals = monthlySpending
        let maxTotal = max(totals.map(\.total).max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Evolución mensual · \(String(budgets.selectedYear))")
                .font(.system(size: 17, weight: .semibold))
                .tracking(-0.2)
                .foregroundStyle(AppTheme.primaryText)

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<12, id: \.self) { index in
                    let total = totals[index].total
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                        .fill(total > 0 ? AppTheme.info : AppTheme.popoverSurface)
                        .frame(height: total > 0 ? max(6, CGFloat(total / maxTotal) * 110) : 3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gasto registrado por mes de \(String(budgets.selectedYear))")

            HStack(spacing: 5) {
                ForEach(0..<12, id: \.self) { index in
                    Text(Self.monthInitials[index])
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.caption2)
            .foregroundStyle(AppTheme.tertiaryText)
            .accessibilityHidden(true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
        )
    }

    private func monthCard(_ budget: BudgetMonthly) -> some View {
        let spending = monthlySpending[budget.mes - 1]
        let isCurrent = budget.anio == currentYear && budget.mes == currentMonth
        let isUpcoming = (budget.anio, budget.mes) > (currentYear, currentMonth)
        let canRemove = spending.count == 0 && budget.gastosRegistrados == 0 && !isCurrent
        let variation = variation(for: budget, spent: spending.total, isCurrent: isCurrent)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        return ZStack(alignment: .topTrailing) {
            Button {
                path.append(.detail(budget))
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.tertiaryText)
                        Text(Self.monthSymbols[budget.mes - 1])
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer(minLength: 8)
                        if isCurrent || isUpcoming {
                            Text(isCurrent ? "Actual" : "Próximo")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isCurrent ? AppTheme.accent : AppTheme.secondaryText)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(isCurrent ? AppTheme.accent.opacity(0.16) : AppTheme.popoverSurface))
                        }
                    }
                    .padding(.trailing, canRemove ? 40 : 0)
                    .padding(.bottom, 14)

                    Text(money(spending.total))
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.8)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                    Text(countText(spending: spending, budget: budget))
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.tertiaryText)
                        .padding(.top, 4)

                    AppHairline()
                        .padding(.top, 14)
                    HStack(spacing: 6) {
                        if let variation, abs(variation.percent) >= 1 {
                            let isUp = variation.percent > 0
                            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isUp ? AppTheme.negative : AppTheme.positive)
                            (Text("\(Int(abs(variation.percent).rounded()))%").fontWeight(.semibold).foregroundColor(isUp ? AppTheme.negative : AppTheme.positive)
                             + Text(" \(variation.suffix)"))
                        } else if variation != nil {
                            Text("Sin cambios")
                        } else {
                            Text(spending.count > 0 ? "Sin base de comparación" : "Configura tus categorías")
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 12)
                }
                .padding(16)
                .background(
                    shape
                        .fill(isCurrent ? AppTheme.accent.opacity(0.06) : AppTheme.surface)
                        .overlay(shape.strokeBorder(isCurrent ? AppTheme.accent.opacity(0.4) : AppTheme.separator, lineWidth: 1))
                )
                .contentShape(shape)
            }
            .buttonStyle(.pressable(scale: 0.98))
            .accessibilityHint("Abre el plan del mes")

            if canRemove {
                Button {
                    budgetToDelete = budget
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .padding(8)
                .accessibilityLabel("Quitar \(Self.monthSymbols[budget.mes - 1])")
            }
        }
    }

    private var addMonthButton: some View {
        Button {
            presentedSheet = .addBudget
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                Text("Agregar mes")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(AppTheme.secondaryText)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.primaryText.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(AppTheme.strongBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                    )
            )
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }

    @ViewBuilder
    private var emptyYear: some View {
        if canAddMonths {
            VStack(spacing: 10) {
                Text("Aún no tienes meses en \(String(budgets.selectedYear))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Agrega un mes para empezar a planificar y seguir tu gasto.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(maxWidth: 260)
                Button {
                    presentedSheet = .addBudget
                } label: {
                    Text("Agregar mes")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.backgroundTop)
                        .padding(.horizontal, 20)
                        .frame(height: 44)
                        .background(Capsule().fill(AppTheme.primaryText))
                }
                .buttonStyle(.pressable(scale: 0.96))
                .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.strongBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        } else {
            Text("No puedes crear presupuestos para años anteriores.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.tertiaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        }
    }

    // MARK: - Datos

    private struct MonthSpending {
        let total: Double
        let count: Int
    }

    private var yearBudgets: [BudgetMonthly] {
        budgets.budgets
            .filter { $0.anio == budgets.selectedYear }
            .sorted { $0.mes < $1.mes }
    }

    private var canAddMonths: Bool {
        budgets.selectedYear >= currentYear
    }

    /// Gasto y número de gastos por mes del año elegido, de enero a diciembre.
    private var monthlySpending: [MonthSpending] {
        let year = budgets.selectedYear
        let grouped = Dictionary(grouping: session.gastos.filter { Self.cal.component(.year, from: $0.fecha) == year }) {
            Self.cal.component(.month, from: $0.fecha)
        }
        return (1...12).map { month in
            let items = grouped[month] ?? []
            return MonthSpending(total: items.reduce(0) { $0 + $1.monto }, count: items.count)
        }
    }

    private var yearStats: (total: Double, count: Int, average: Double, monthsWithSpending: Int, highest: (month: Int, total: Double)?) {
        let created = Set(yearBudgets.map(\.mes))
        let entries = monthlySpending.enumerated()
            .filter { created.contains($0.offset + 1) }
            .map { (month: $0.offset + 1, spending: $0.element) }
        let total = entries.reduce(0) { $0 + $1.spending.total }
        let count = entries.reduce(0) { $0 + $1.spending.count }
        let withSpending = entries.filter { $0.spending.count > 0 }
        let average = withSpending.isEmpty ? 0 : withSpending.reduce(0) { $0 + $1.spending.total } / Double(withSpending.count)
        let highest = entries.max { $0.spending.total < $1.spending.total }
            .flatMap { $0.spending.total > 0 ? (month: $0.month, total: $0.spending.total) : nil }
        return (total, count, average, withSpending.count, highest)
    }

    /// Mes en curso contra el mismo tramo del anterior; el resto, contra el mes anterior entero.
    private func variation(for budget: BudgetMonthly, spent: Double, isCurrent: Bool) -> (percent: Double, suffix: String)? {
        guard spent > 0,
              let monthStart = Self.cal.date(from: DateComponents(year: budget.anio, month: budget.mes, day: 1)),
              let previousStart = Self.cal.date(byAdding: .month, value: -1, to: monthStart)
        else { return nil }

        let previousName = Self.monthSymbols[Self.cal.component(.month, from: previousStart) - 1]
        let end: Date
        let suffix: String
        if isCurrent {
            let day = Self.cal.component(.day, from: Date())
            let previousDays = Self.cal.range(of: .day, in: .month, for: previousStart)?.count ?? 30
            end = Self.cal.date(byAdding: .day, value: min(day, previousDays), to: previousStart) ?? monthStart
            suffix = "vs. 1–\(day) \(previousName.prefix(3).lowercased())"
        } else {
            end = monthStart
            suffix = "vs. mes anterior"
        }
        let base = session.gastos
            .filter { $0.fecha >= previousStart && $0.fecha < end }
            .reduce(0) { $0 + $1.monto }
        guard let percent = HomeMonthPulse.change(from: base, to: spent) else { return nil }
        return (percent, suffix)
    }

    private func countText(spending: MonthSpending, budget: BudgetMonthly) -> String {
        let plan = budget.total > 0 ? " · plan \(money(budget.total))" : ""
        guard spending.count > 0 else { return "Sin gastos" + plan }
        let count = spending.count == 1 ? "1 gasto" : "\(spending.count) gastos"
        return "\(count) · \(money(spending.total / Double(spending.count))) promedio" + plan
    }

    // MARK: - Piezas

    private func splitAmount(_ value: Double, size: CGFloat) -> some View {
        let whole = Double(Int(value)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = (Locale.current.decimalSeparator ?? ".") + String(format: "%02d", Int((value * 100).rounded()) % 100)
        return (Text(whole).font(.system(size: size, weight: .semibold)).foregroundStyle(AppTheme.primaryText)
                + Text(cents).font(.system(size: size * 0.6, weight: .semibold)).foregroundStyle(AppTheme.tertiaryText))
            .tracking(-1.5)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityLabel(money(value))
    }

    private func roundGlyph(_ systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(Circle().fill(tint.opacity(0.18)))
            .accessibilityHidden(true)
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    // MARK: - Acciones

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { budgetToDelete != nil }, set: { if !$0 { budgetToDelete = nil } })
    }

    private func selectYear(_ year: Int) {
        guard year != budgets.selectedYear else { return }
        withAnimation(AppMotion.standard) {
            budgets.selectedYear = year
        }
        Task { await loadAnnualData(force: true) }
    }

    private func deleteSelectedBudget() {
        guard let budget = budgetToDelete else { return }
        budgetToDelete = nil
        Task { await budgets.deleteBudget(using: session, budget: budget) }
    }

    private func refreshBudgets() {
        Task { await loadAnnualData(force: true) }
    }

    private func loadAnnualData(force: Bool = false) async {
        await budgets.loadBudgets(using: session, force: force)
        if force {
            await session.loadExpenses(force: true)
        } else {
            await session.loadExpensesIfNeeded()
        }
    }
}

#Preview {
    BudgetsView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
