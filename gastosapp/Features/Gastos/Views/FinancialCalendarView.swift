import SwiftUI

struct FinancialCalendarView: View {
    @Environment(ExpenseStore.self) private var store
    @State private var visibleMonth = FinancialCalendarView.startOfMonth(Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())

    private static let calendar = Calendar.current
    private static let shortWeekdays = [
        FinancialWeekday(id: 1, title: "L"),
        FinancialWeekday(id: 2, title: "M"),
        FinancialWeekday(id: 3, title: "M"),
        FinancialWeekday(id: 4, title: "J"),
        FinancialWeekday(id: 5, title: "V"),
        FinancialWeekday(id: 6, title: "S"),
        FinancialWeekday(id: 7, title: "D")
    ]
    private static let spanishMonthSymbols: [String] = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        return formatter.monthSymbols
    }()

    private var monthEnd: Date {
        Self.calendar.date(byAdding: .month, value: 1, to: visibleMonth) ?? visibleMonth
    }

    private var monthExpenses: [Expense] {
        store.gastos.filter { $0.fecha >= visibleMonth && $0.fecha < monthEnd }
    }

    private var recurringOccurrences: [FinancialRecurringOccurrence] {
        store.recurringExpenses.flatMap { occurrences(for: $0) }
    }

    private var selectedExpenses: [Expense] {
        expenses(on: selectedDate).sorted { $0.monto > $1.monto }
    }

    private var selectedRecurring: [FinancialRecurringOccurrence] {
        recurringOccurrences
            .filter { Self.calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.expense.monto > $1.expense.monto }
    }

    private var monthSpent: Double {
        monthExpenses.reduce(0) { $0 + $1.monto }
    }

    private var monthScheduled: Double {
        recurringOccurrences.reduce(0) { $0 + $1.expense.monto }
    }

    private var nextScheduledOccurrence: FinancialRecurringOccurrence? {
        recurringOccurrences
            .filter { $0.date >= Self.calendar.startOfDay(for: Date()) }
            .sorted { $0.date < $1.date }
            .first
    }

    private var highestSpendingDay: FinancialCalendarDay? {
        calendarDays
            .filter { $0.spent > 0 }
            .max { $0.spent < $1.spent }
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppScreenMetrics.sectionSpacing) {
                    summaryCard
                    agendaCard
                    calendarCard
                    selectedDayCard
                }
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, 32)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            monthSelector
                .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                .padding(.top, AppScreenMetrics.headerTopPadding)
                .padding(.bottom, AppScreenMetrics.headerBottomPadding)
                .background(AppTheme.backgroundTop.ignoresSafeArea(edges: .top))
        }
        .task {
            await store.loadExpensesIfNeeded()
            await store.loadRecurringExpensesIfNeeded()
        }
        .onChange(of: visibleMonth) { _, newValue in
            if !Self.calendar.isDate(selectedDate, equalTo: newValue, toGranularity: .month) {
                selectedDate = newValue
            }
        }
    }

    private var monthSelector: some View {
        AppScreenHeader(eyebrow: "Calendario financiero", title: monthTitle) {
            AppPeriodStepper(
                label: "",
                onPrevious: { moveMonth(-1) },
                onNext: { moveMonth(1) },
                previousLabel: "Mes anterior",
                nextLabel: "Mes siguiente"
            )
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            summaryMetric(title: "Gastado", value: monthSpent, tint: AppTheme.accent)
            Rectangle()
                .fill(AppTheme.onStatementFaint)
                .frame(width: 1, height: 44)
            summaryMetric(title: "Programado", value: monthScheduled, tint: AppTheme.secondaryAccent)
        }
        .padding(24)
        .background(AppTheme.statementBackground(cornerRadius: 32))
        .accessibilityElement(children: .combine)
    }

    private func summaryMetric(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.statementSecondary)
            }

            Text(value, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(AppTheme.number(24, .bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.onStatement)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 2)
    }

    private var agendaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Agenda del mes")
                    .font(.title2.bold())
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(spacing: 10) {
                if let nextScheduledOccurrence {
                    agendaRow(
                        icon: "repeat.circle.fill",
                        tint: AppTheme.secondaryAccent,
                        title: "Próximo cargo",
                        value: nextScheduledOccurrence.expense.descripcion,
                        detail: "\(shortDate(nextScheduledOccurrence.date)) • \(nextScheduledOccurrence.expense.monto.budgetCurrency)"
                    )
                } else {
                    agendaRow(
                        icon: "checkmark.seal.fill",
                        tint: AppTheme.accent,
                        title: "Próximo cargo",
                        value: "Sin cargos pendientes",
                        detail: "No hay recurrentes activos este mes."
                    )
                }

                if let highestSpendingDay, let date = highestSpendingDay.date {
                    agendaRow(
                        icon: "chart.line.uptrend.xyaxis",
                        tint: AppTheme.warning,
                        title: "Día más alto",
                        value: shortDate(date),
                        detail: "Gastaste \(highestSpendingDay.spent.budgetCurrency)"
                    )
                } else {
                    agendaRow(
                        icon: "calendar.badge.checkmark",
                        tint: AppTheme.accent,
                        title: "Día más alto",
                        value: "Sin gastos aún",
                        detail: "Aparecerá cuando registres movimientos."
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func agendaRow(icon: String, tint: Color, title: String, value: String, detail: String) -> some View {
        HStack(spacing: 12) {
            ExpenseIconBadge(systemName: icon, color: tint)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(AppTheme.tertiaryText)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(detail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }

    private var calendarCard: some View {
        VStack(spacing: 16) {
            calendarLegend

            HStack {
                ForEach(Self.shortWeekdays) { day in
                    Text(day.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 7), spacing: 7) {
                ForEach(calendarDays) { day in
                    calendarCell(day)
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var calendarLegend: some View {
        HStack(spacing: 12) {
            legendItem(color: AppTheme.accent, title: "Gastado")
            legendItem(color: AppTheme.secondaryAccent, title: "Programado")
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedDayTitle)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(selectedDaySubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
            }

            selectedDayTotals

            if selectedExpenses.isEmpty && selectedRecurring.isEmpty {
                emptyDayView
            } else {
                VStack(spacing: 10) {
                    ForEach(selectedExpenses) { expense in
                        calendarExpenseRow(expense)
                    }
                    ForEach(selectedRecurring) { occurrence in
                        recurringRow(occurrence.expense)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var selectedDayTotals: some View {
        HStack(spacing: 10) {
            selectedTotalPill(title: "Gastado", value: selectedExpenses.reduce(0) { $0 + $1.monto }, tint: AppTheme.accent)
            selectedTotalPill(title: "Programado", value: selectedRecurring.reduce(0) { $0 + $1.expense.monto }, tint: AppTheme.secondaryAccent)
        }
    }

    private func selectedTotalPill(title: String, value: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.tertiaryText)
            Text(value, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.14))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.25), lineWidth: 1))
        )
    }

    private var emptyDayView: some View {
        HStack(spacing: 12) {
            ExpenseIconBadge(systemName: "checkmark.seal.fill", color: AppTheme.accent)
            Text("No hay movimientos ni cargos programados para este día.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.insetSurface)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
        )
    }

    private func calendarCell(_ day: FinancialCalendarDay) -> some View {
        Group {
            if let date = day.date {
                let isSelected = Self.calendar.isDate(date, inSameDayAs: selectedDate)
                let isToday = Self.calendar.isDateInToday(date)
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        selectedDate = date
                    }
                } label: {
                    VStack(spacing: 7) {
                        Text("\(Self.calendar.component(.day, from: date))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isSelected ? .black : AppTheme.primaryText)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(isToday && !isSelected ? AppTheme.controlSurface : Color.clear)
                            )

                        eventIndicators(for: day)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(calendarCellFill(day: day, isSelected: isSelected))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(calendarCellStroke(day: day, isSelected: isSelected), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.accessibilityLabel)
            } else {
                Color.clear
                    .frame(height: 52)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func eventIndicators(for day: FinancialCalendarDay) -> some View {
        if day.hasActivity {
            HStack(spacing: 4) {
                if day.spent > 0 {
                    Capsule()
                        .fill(AppTheme.accent)
                        .frame(width: day.scheduled > 0 ? 12 : 20, height: 5)
                }
                if day.scheduled > 0 {
                    Capsule()
                        .fill(AppTheme.secondaryAccent)
                        .frame(width: day.spent > 0 ? 12 : 20, height: 5)
                }
            }
            .frame(height: 8)
        } else {
            Capsule()
                .fill(AppTheme.controlSurface)
                .frame(width: 5, height: 5)
                .frame(height: 8)
        }
    }

    private func calendarCellFill(day: FinancialCalendarDay, isSelected: Bool) -> Color {
        if isSelected {
            return AppTheme.accent
        }
        if day.hasActivity {
            return AppTheme.insetSurface
        }
        return Color.clear
    }

    private func calendarCellStroke(day: FinancialCalendarDay, isSelected: Bool) -> Color {
        if isSelected {
            return Color.clear
        }
        return day.hasActivity ? AppTheme.strongBorder : AppTheme.border.opacity(0.35)
    }

    private func calendarExpenseRow(_ expense: Expense) -> some View {
        HStack(spacing: 12) {
            ExpenseIconBadge(systemName: expense.categoria.icono, color: AppTheme.primaryText)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.descripcion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("\(expense.categoria.nombre) • \(expense.metodoPago.shortLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(expense.monto, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(12)
        .background(rowBackground)
    }

    private func recurringRow(_ expense: RecurringExpense) -> some View {
        HStack(spacing: 12) {
            ExpenseIconBadge(systemName: "repeat", color: AppTheme.secondaryAccent)
            VStack(alignment: .leading, spacing: 3) {
                Text(expense.descripcion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Programado • \(expense.cadenceLabel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            Text(expense.monto, format: .currency(code: "USD").precision(.fractionLength(2)))
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryAccent)
        }
        .padding(12)
        .background(rowBackground)
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(AppTheme.insetSurface)
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
    }

    private var calendarDays: [FinancialCalendarDay] {
        let daysRange = Self.calendar.range(of: .day, in: .month, for: visibleMonth) ?? 1..<1
        let firstWeekday = mondayBasedWeekday(visibleMonth)
        let leadingBlanks = max(firstWeekday - 1, 0)
        var days: [FinancialCalendarDay] = (0..<leadingBlanks).map { FinancialCalendarDay.placeholder(index: $0) }

        for day in daysRange {
            guard let date = Self.calendar.date(byAdding: .day, value: day - 1, to: visibleMonth) else { continue }
            let spent = expenses(on: date).reduce(0) { $0 + $1.monto }
            let scheduled = recurringOccurrences
                .filter { Self.calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.expense.monto }
            days.append(FinancialCalendarDay(date: date, spent: spent, scheduled: scheduled))
        }

        return days
    }

    private var monthTitle: String {
        let month = Self.calendar.component(.month, from: visibleMonth)
        let year = Self.calendar.component(.year, from: visibleMonth)
        let name = Self.spanishMonthSymbols.indices.contains(month - 1) ? Self.spanishMonthSymbols[month - 1] : "Mes"
        return "\(name.capitalized) \(year)"
    }

    private var selectedDayTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "EEEE d 'de' MMMM"
        return formatter.string(from: selectedDate).capitalized
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).capitalized
    }

    private var selectedDaySubtitle: String {
        let movementCount = selectedExpenses.count
        let scheduledCount = selectedRecurring.count
        return "\(movementCount) movimientos • \(scheduledCount) programados"
    }

    private func expenses(on date: Date) -> [Expense] {
        monthExpenses.filter { Self.calendar.isDate($0.fecha, inSameDayAs: date) }
    }

    private func occurrences(for expense: RecurringExpense) -> [FinancialRecurringOccurrence] {
        guard expense.activo else { return [] }
        let start = max(Self.calendar.startOfDay(for: expense.fechaInicio), visibleMonth)
        let end = min(expense.fechaFin.map { Self.calendar.startOfDay(for: $0) } ?? monthEnd, monthEnd)
        guard start < end else { return [] }

        switch expense.frecuencia {
        case .mensual:
            let desiredDay = min(max(expense.diaMes ?? Self.calendar.component(.day, from: expense.fechaInicio), 1), 28)
            guard let date = Self.calendar.date(from: DateComponents(
                year: Self.calendar.component(.year, from: visibleMonth),
                month: Self.calendar.component(.month, from: visibleMonth),
                day: desiredDay,
                hour: 12
            )) else { return [] }
            return date >= start && date < end ? [FinancialRecurringOccurrence(date: date, expense: expense)] : []
        case .semanal:
            let desiredWeekday = expense.diaSemana ?? mondayBasedWeekday(expense.fechaInicio)
            var cursor = start
            var results: [FinancialRecurringOccurrence] = []
            while cursor < end {
                if mondayBasedWeekday(cursor) == desiredWeekday {
                    results.append(FinancialRecurringOccurrence(date: cursor, expense: expense))
                }
                guard let next = Self.calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }
            return results
        }
    }

    private func monthButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AppTheme.controlSurface))
        }
        .buttonStyle(.plain)
    }

    private func moveMonth(_ value: Int) {
        guard let newMonth = Self.calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            visibleMonth = Self.startOfMonth(newMonth)
        }
    }

    private func mondayBasedWeekday(_ date: Date) -> Int {
        let weekday = Self.calendar.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }
}

private struct FinancialCalendarDay: Identifiable {
    let id: String
    let date: Date?
    let spent: Double
    let scheduled: Double

    init(date: Date, spent: Double, scheduled: Double) {
        self.id = "day-\(date.timeIntervalSince1970)"
        self.date = date
        self.spent = spent
        self.scheduled = scheduled
    }

    private init(id: String) {
        self.id = id
        self.date = nil
        self.spent = 0
        self.scheduled = 0
    }

    static func placeholder(index: Int) -> FinancialCalendarDay {
        FinancialCalendarDay(id: "blank-\(index)")
    }

    var hasActivity: Bool {
        spent > 0 || scheduled > 0
    }

    var accessibilityLabel: String {
        guard let date else { return "" }
        let day = Calendar.current.component(.day, from: date)
        return "Día \(day), gastado \(spent.budgetCurrency), programado \(scheduled.budgetCurrency)"
    }
}

private struct FinancialWeekday: Identifiable {
    let id: Int
    let title: String
}

private struct FinancialRecurringOccurrence: Identifiable {
    let date: Date
    let expense: RecurringExpense

    var id: String {
        "\(expense.id)-\(date.timeIntervalSince1970)"
    }
}
