import SwiftUI

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
    @State private var presentedSheet: PresentedSheet?
    @State private var budgetToDelete: BudgetMonthly?
    @State private var path: [Route] = []
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                background.ignoresSafeArea()
                budgetList

                if let toastMessage = budgets.saveStatusMessage {
                    TransientStatusToast(text: toastMessage, tint: AppTheme.accent, icon: "checkmark.circle.fill")
                        .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                        .padding(.bottom, 92)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
            .safeAreaInset(edge: .top, spacing: 0) {
                BudgetsHeaderBar(
                    year: budgets.selectedYear,
                    onPreviousYear: showPreviousYear,
                    onNextYear: showNextYear,
                    onAddTap: { presentedSheet = .addBudget }
                )
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, AppScreenMetrics.headerBottomPadding)
                .background(AppTheme.backgroundTop.ignoresSafeArea(edges: .top))
            }
            .task { await loadAnnualData() }
        }
        .alert("Eliminar presupuesto", isPresented: deleteAlertBinding) {
            Button("Cancelar", role: .cancel) { budgetToDelete = nil }
            Button("Eliminar", role: .destructive, action: deleteSelectedBudget)
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

    private var budgetList: some View {
        List {
            headerRow { statusCard }

            headerRow {
                annualSummaryCard
            }

            headerRow {
                annualStatsRow
            }

            headerRow {
                monthsSectionHeader
            }

            ForEach(monthRows, id: \.month) { row in
                Button {
                    path.append(.detail(row.budget))
                } label: {
                    BudgetMonthAnnualRow(
                        month: row.month,
                        year: budgets.selectedYear,
                        budget: row.budget
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Abre el detalle del presupuesto")
                .listRowInsets(EdgeInsets(top: 5, leading: AppScreenMetrics.horizontalPadding, bottom: 5, trailing: AppScreenMetrics.horizontalPadding))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if row.budget.gastosRegistrados == 0 {
                        Button(role: .destructive) { budgetToDelete = row.budget } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }

            headerRow {
                hintCard
            }

            bottomSafeRow
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await loadAnnualData(force: true) }
    }

    @ViewBuilder
    private var statusCard: some View {
        if budgets.isLoadingBudgets && budgets.budgets.isEmpty {
            messageCard(icon: "hourglass", tint: AppTheme.accent, title: "Cargando presupuestos", message: "Estamos trayendo tus meses configurados.")
        } else if budgets.budgets.isEmpty {
            emptyBudgetCard
        }
    }

    private var emptyBudgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            messageCard(icon: "target", tint: AppTheme.accent, title: "Todavía no tienes presupuestos", message: "Crea el primero para empezar a medir tu ritmo del mes.")

            Button {
                presentedSheet = .addBudget
            } label: {
                Label("Crear primer mes", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Capsule().fill(AppTheme.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var annualSummaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total presupuestado")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.statementSecondary)
                    Text(annualTotal, format: .currency(code: "USD").precision(.fractionLength(2)))
                        .font(AppTheme.number(42, .bold))
                        .monospacedDigit()
                        .kerning(-1.2)
                        .foregroundStyle(AppTheme.onStatement)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                    Text("Plan anual creado: \(annualTotal.budgetCurrency)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.statementSecondary)
                }

                Spacer()

                Text("\(createdMonthCount) / 12")
                    .font(AppTheme.number(13, .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(Capsule().fill(AppTheme.accent.opacity(0.14)))
            }

            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(monthRows, id: \.month) { row in
                        VStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(monthCellColor(row))
                                .frame(height: 38)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .strokeBorder(
                                            isCurrentMonth(year: row.budget.anio, month: row.budget.mes)
                                                ? AppTheme.accent
                                                : AppTheme.onStatementFaint,
                                            lineWidth: 1
                                        )
                                )
                            Text(monthSingleLetter(row.month))
                                .font(AppTheme.label(10))
                                .foregroundStyle(AppTheme.statementSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                HStack(spacing: 6) {
                    Text("Actividad del año")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundStyle(AppTheme.statementSecondary)
                    Spacer(minLength: 0)
                    Text("menos")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.statementSecondary)
                    ForEach([0.12, 0.3, 0.55, 0.85], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(AppTheme.accent.opacity(level))
                            .frame(width: 10, height: 10)
                    }
                    Text("más")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppTheme.statementSecondary)
                }
            }
        }
        .padding(24)
        .background(AppTheme.statementBackground(cornerRadius: 32))
        .accessibilityElement(children: .combine)
    }

    private var annualStatsRow: some View {
        LazyVGrid(columns: metricColumns, spacing: 10) {
            AnnualBudgetMetricCard(title: "Ahorro", value: annualSavings.budgetCurrency, subtitle: annualSavingsSubtitle)
            AnnualBudgetMetricCard(title: "Gastado", value: annualSpent.budgetCurrency, subtitle: "en el año")
            AnnualBudgetMetricCard(title: "Promedio", value: monthlyAverage.budgetCurrency, subtitle: "por mes")
            AnnualBudgetMetricCard(title: "Gastos", value: "\(annualExpenseCount)", subtitle: "registrados")
        }
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }

    private var monthsSectionHeader: some View {
        AppSectionTitle(title: "Meses", trailingText: "creados")
            .padding(.top, 4)
    }

    private var hintCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppTheme.accent)
            Text("Usa el botón + para crear los meses que faltan.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        )
    }

    private var selectedYearBudgets: [BudgetMonthly] {
        budgets.budgets.filter { $0.anio == budgets.selectedYear }
    }

    private var monthRows: [(month: Int, budget: BudgetMonthly)] {
        selectedYearBudgets.map { ($0.mes, $0) }
    }

    private var annualTotal: Double {
        selectedYearBudgets.reduce(0) { $0 + $1.total }
    }

    private var createdMonthCount: Int {
        selectedYearBudgets.count
    }

    private var annualExpenseCount: Int {
        selectedYearBudgets.reduce(0) { $0 + $1.gastosRegistrados }
    }

    private var annualSpent: Double {
        session.gastos
            .filter { Calendar.current.component(.year, from: $0.fecha) == budgets.selectedYear }
            .reduce(0) { $0 + $1.monto }
    }

    private var annualSavings: Double {
        annualTotal - annualSpent
    }

    private var annualSavingsSubtitle: String {
        annualSavings >= 0 ? "vs gastos del año" : "por encima"
    }

    private var monthlyAverage: Double {
        createdMonthCount > 0 ? annualTotal / Double(createdMonthCount) : 0
    }

    private var maxMonthlyTotal: Double {
        max(selectedYearBudgets.map(\.total).max() ?? 0, 1)
    }

    private func monthCellColor(_ row: (month: Int, budget: BudgetMonthly)) -> Color {
        let budget = row.budget
        guard budget.total > 0 else { return AppTheme.onStatementFaint }
        let intensity = 0.22 + min(0.68, budget.total / maxMonthlyTotal * 0.68)
        return AppTheme.accent.opacity(intensity)
    }

    private func monthSingleLetter(_ month: Int) -> String {
        guard Self.spanishMonthSymbols.indices.contains(month - 1) else { return "—" }
        return String(Self.spanishMonthSymbols[month - 1].prefix(1)).uppercased()
    }

    private func isCurrentMonth(year: Int, month: Int) -> Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == year && now.month == month
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { budgetToDelete != nil }, set: { if !$0 { budgetToDelete = nil } })
    }

    private var background: some View {
        LinearGradient(
            colors: [AppTheme.backgroundTop, AppTheme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func headerRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .listRowInsets(EdgeInsets(top: 8, leading: AppScreenMetrics.horizontalPadding, bottom: 8, trailing: AppScreenMetrics.horizontalPadding))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var bottomSafeRow: some View {
        Color.clear
            .frame(height: 28)
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .accessibilityHidden(true)
    }

    private func messageCard(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(AppTheme.primaryText)
                Text(message).font(.caption).foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
        )
    }

    private func showPreviousYear() {
        budgets.selectedYear -= 1
        Task { await loadAnnualData(force: true) }
    }

    private func showNextYear() {
        budgets.selectedYear += 1
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

private struct AnnualBudgetMetricCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(value)
                .font(.system(.headline, design: .default, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.70)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
        )
    }
}

private struct BudgetMonthAnnualRow: View {
    let month: Int
    let year: Int
    let budget: BudgetMonthly?
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

    var body: some View {
        HStack(spacing: 14) {
            monthBadge

            VStack(alignment: .leading, spacing: 7) {
                titleLine
                footerLine
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(rowBackground)
        .opacity(budget == nil ? 0.58 : 1)
        .accessibilityElement(children: .combine)
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(monthName)
                .font(.system(.headline, design: .default, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            if isCurrentMonth {
                Text("MES ACTUAL")
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.accent)
            }

            Spacer(minLength: 8)

            if let budget {
                Text(budget.total, format: .currency(code: "USD").precision(.fractionLength(2)))
                    .font(.system(.headline, design: .default, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } else {
                Text("—")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AppTheme.placeholderText)
            }
        }
    }

    private var footerLine: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(footerText)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            Text(statusText)
                .font(.caption.weight(.bold))
                .foregroundStyle(statusTextColor)
                .lineLimit(1)
        }
    }

    private var monthBadge: some View {
        VStack(spacing: 2) {
            Text(monthAbbreviation)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.tertiaryText)
                .tracking(0.7)
            Text(String(format: "%02d", month))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .frame(width: 52)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(budget == nil ? AppTheme.insetSurface : AppTheme.surface)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.border, lineWidth: 1))
            .shadow(color: .black.opacity(budget == nil ? 0.025 : 0.045), radius: 10, y: 4)
    }

    private var footerText: String {
        guard let budget else { return "Sin presupuesto creado" }
        return "\(budget.gastosRegistrados == 1 ? "1 gasto" : "\(budget.gastosRegistrados) gastos") registrados"
    }

    private var statusText: String {
        guard budget != nil else { return "Pendiente" }
        if isCurrentMonth { return "Disponible este mes" }
        return isPastMonth ? "Mes cerrado" : "Por venir"
    }

    private var statusTextColor: Color {
        guard budget != nil else { return AppTheme.placeholderText }
        if isCurrentMonth { return AppTheme.accent.opacity(0.90) }
        return AppTheme.secondaryText
    }

    private var isCurrentMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        return now.year == year && now.month == month
    }

    private var isPastMonth: Bool {
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        guard let nowYear = now.year, let nowMonth = now.month else { return false }
        if year < nowYear { return true }
        if year > nowYear { return false }
        return month < nowMonth
    }

    private var monthName: String {
        Self.spanishMonthSymbols.indices.contains(month - 1) ? Self.spanishMonthSymbols[month - 1].capitalized : "Mes"
    }

    private var monthAbbreviation: String {
        Self.spanishMonthSymbols.indices.contains(month - 1) ? String(Self.spanishMonthSymbols[month - 1].prefix(3)).uppercased() : "—"
    }
}

#Preview {
    BudgetsView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
