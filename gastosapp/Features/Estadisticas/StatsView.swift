import SwiftUI
import Charts

/// Análisis, según el canvas «Análisis»: un período elegido con su total,
/// evolución, cifras clave, categorías y grupos plegables de detalle; y la
/// proyección de cierre del mes en una segunda pestaña.
struct StatsView: View {
    private enum Tab: String, CaseIterable {
        case detail = "Detalle"
        case projection = "Proyección"
    }

    private enum Section: Hashable { case habits, payments, top }

    @Environment(ExpenseStore.self) private var expenses
    @Environment(AppNavigator.self) private var navigator: AppNavigator?
    @State private var tab: Tab = .detail
    @State private var period: StatsPeriod = .month(
        year: Calendar.current.component(.year, from: Date()),
        month: Calendar.current.component(.month, from: Date())
    )
    @State private var analysis = StatsPeriodAnalysis(period: .all, allExpenses: [])
    @State private var availablePeriods: [StatsPeriod] = StatsPeriodAnalysis.availablePeriods(from: [])
    @State private var openGroups: Set<Section> = []
    @State private var selectedWeekday: Int?
    @State private var weeksPerDay = false
    @State private var sizesByCount = false
    @State private var forecastModel = ExpenseForecastStore()

    private static let weekdayInitials = ["L", "M", "X", "J", "V", "S", "D"]
    private static let weekdayNames = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábados", "domingos"]

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                            .padding(.horizontal, 20)
                        tabPicker
                    }
                    switch tab {
                    case .detail: detailContent
                    case .projection: projectionContent
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
                .animation(AppMotion.fade, value: tab)
            }
            .tracksScrollChrome()
            .floatingTabBarInset()
            .refreshable {
                if tab == .detail {
                    await expenses.loadExpenses(force: true)
                } else {
                    await forecastModel.load(using: expenses)
                }
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
        .task {
            await expenses.loadExpensesIfNeeded()
            availablePeriods = StatsPeriodAnalysis.availablePeriods(from: expenses.gastos)
            rebuild()
        }
        .task(id: tab) {
            if tab == .projection, forecastModel.forecast == nil, !forecastModel.isLoading {
                await forecastModel.load(using: expenses)
            }
        }
        .onChange(of: expenses.gastos) {
            availablePeriods = StatsPeriodAnalysis.availablePeriods(from: expenses.gastos)
            rebuild()
        }
        .onChange(of: period) {
            selectedWeekday = nil
            rebuild()
        }
    }

    private func rebuild() {
        let next = StatsPeriodAnalysis(period: period, allExpenses: expenses.gastos)
        withAnimation(AppMotion.standard) { analysis = next }
    }

    // MARK: - Encabezado

    private var header: some View {
        HStack(spacing: 12) {
            Text("Análisis")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppTheme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            Menu {
                Picker("Período", selection: $period) {
                    ForEach(availablePeriods) { option in
                        Text(title(for: option)).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                    Text(analysis.period == period ? analysis.shortTitle : "")
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Capsule().fill(AppTheme.popoverSurface))
            }
            .accessibilityLabel("Período: \(analysis.title)")
        }
    }

    private func title(for option: StatsPeriod) -> String {
        switch option {
        case .all:
            return "Todo el historial"
        case let .month(year, month):
            return "\(SpanishCalendar.monthSymbols[month - 1].capitalized) \(year)"
        }
    }

    private var tabPicker: some View {
        segmented(Tab.allCases, selection: $tab, height: 40, fontSize: 14) { $0.rawValue }
            .padding(.horizontal, 20)
    }

    // MARK: - Detalle

    @ViewBuilder
    private var detailContent: some View {
        if analysis.expenses.isEmpty {
            VStack(spacing: 6) {
                Text("No hay gastos en este período")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Prueba otro período o registra un gasto para ver tus patrones.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.strongBorder, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
            .padding(.horizontal, 20)
        } else {
            // Vista propia: arrastrar por el gráfico sólo recalcula el gráfico,
            // no todas las secciones de Análisis.
            StatsEvolutionSection(analysis: analysis)
                .id(analysis.period)
            ledger
            highlights
            categorySection
            groupHeader(.habits, icon: "calendar.day.timeline.left", title: "Hábitos", subtitle: "Días, semanas y tamaño de compras")
            if openGroups.contains(.habits) { habitsContent }
            groupHeader(.payments, icon: "creditcard", title: "Pagos", subtitle: "Tarjetas y recurrentes")
            if openGroups.contains(.payments) { paymentsContent }
            groupHeader(.top, icon: "arrow.up.right", title: "Mayores gastos", subtitle: "Los más altos del período")
            if openGroups.contains(.top) { topContent }
        }
    }

    private var ledger: some View {
        VStack(spacing: 0) {
            ledgerRow(
                analysis.isInProgress ? "Promedio diario (a hoy)" : "Promedio diario",
                value: analysis.elapsedDays > 0 ? money(analysis.dailyAverage) : "—",
                delta: analysis.dailyAverageDelta,
                neutral: false
            )
            ledgerRow("Transacciones", value: "\(analysis.expenses.count)", delta: analysis.countDelta, neutral: true)
            ledgerRow("Ticket promedio", value: money(analysis.averageTicket), delta: analysis.ticketDelta, neutral: false)
        }
        .padding(.horizontal, 20)
    }

    private func ledgerRow(_ label: String, value: String, delta: Double?, neutral: Bool) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 8)
            if let delta, abs(delta) >= 1 {
                let isUp = delta > 0
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 10, weight: .heavy))
                        .rotationEffect(.degrees(isUp ? 0 : 180))
                    Text("\(Int(abs(delta).rounded()))%")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(neutral ? AppTheme.secondaryText : (isUp ? AppTheme.negative : AppTheme.positive))
            }
            Text(value)
                .font(.system(size: 17, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { AppHairline() }
        .accessibilityElement(children: .combine)
    }

    private var highlights: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Qué destaca")
                .padding(.bottom, 4)

            if let change = analysis.biggestChange {
                let diff = change.total - (change.previousTotal ?? 0)
                insightCard(
                    label: "Mayor cambio en dinero",
                    text: "\(change.category.nombre): \(diff > 0 ? "subió" : "bajó") \(money(abs(diff)))",
                    sub: "vs. período anterior"
                )
            } else if let top = analysis.categories.first {
                insightCard(
                    label: "Categoría principal",
                    text: top.category.nombre,
                    sub: "\(Int((top.share * 100).rounded()))% del total"
                )
            }

            if let peak = analysis.peakDay {
                insightCard(
                    label: "Día de mayor gasto",
                    text: "\(peak.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))) · \(money(peak.total))",
                    sub: peak.count == 1 ? "1 compra" : "\(peak.count) compras"
                )
            }

            if let small = analysis.buckets.first {
                insightCard(
                    label: "Compras de hasta $10",
                    text: "\(money(small.total)) en \(small.count) \(small.count == 1 ? "compra" : "compras")",
                    sub: "\(analysis.total > 0 ? Int((small.total / analysis.total * 100).rounded()) : 0)% del total"
                )
            }
        }
        .padding(.horizontal, 20)
    }

    private func insightCard(label: String, text: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.2)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
            Text(sub)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.cardBackground())
        .accessibilityElement(children: .combine)
    }

    private var categorySection: some View {
        let maxTotal = analysis.categories.first?.total ?? 0
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                sectionTitle("Gasto por categoría")
                if analysis.categories.count > 3 {
                    (Text("Las 3 principales concentran el ")
                     + Text("\(Int(analysis.concentration.rounded()))%").fontWeight(.semibold).foregroundColor(AppTheme.primaryText)
                     + Text(" del total"))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            ForEach(analysis.categories) { line in
                VStack(spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle().fill(line.category.color).frame(width: 9, height: 9)
                            Text(line.category.nombre)
                                .font(.system(size: 15))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        HomeSpendDelta(percent: line.delta)
                        Text(money(line.total))
                            .font(.system(size: 15, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryText)
                    }
                    HStack(spacing: 10) {
                        bar(fraction: maxTotal > 0 ? line.total / maxTotal : 0, tint: line.category.color)
                        Text("\(Int((line.share * 100).rounded()))% · \(line.count)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(minWidth: 62, alignment: .trailing)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 24)
        .overlay(alignment: .top) { AppHairline() }
        .padding(.horizontal, 20)
    }

    // MARK: - Grupos plegables

    private func groupHeader(_ group: Section, icon: String, title: String, subtitle: String) -> some View {
        let isOpen = openGroups.contains(group)
        return Button {
            withAnimation(AppMotion.standard) {
                if isOpen { openGroups.remove(group) } else { openGroups.insert(group) }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(AppTheme.popoverSurface))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.top, 18)
            .frame(minHeight: 56)
            .overlay(alignment: .top) { AppHairline() }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityValue(isOpen ? "Desplegado" : "Plegado")
    }

    private var habitsContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            weekdaySection
            if !analysis.weeks.isEmpty { weeksSection }
            sizesSection
            habitTiles
        }
        .padding(.horizontal, 20)
        .transition(.opacity)
    }

    private var weekdaySection: some View {
        let maxTotal = max(analysis.weekdayTotals.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                sectionTitle("Patrón semanal")
                Text(weekdayReadout)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
            }
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    let total = analysis.weekdayTotals[index]
                    let isSelected = index == selectedWeekday
                    Button {
                        selectedWeekday = isSelected ? nil : index
                    } label: {
                        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                            .fill(isSelected ? AppTheme.accent : AppTheme.primaryText.opacity(total == maxTotal ? 0.55 : 0.22))
                            .frame(height: max(4, CGFloat(total / maxTotal) * 116))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Self.weekdayNames[index].capitalized): \(money(total))")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .frame(height: 120)
            HStack(spacing: 8) {
                ForEach(Self.weekdayInitials.indices, id: \.self) { index in
                    Text(Self.weekdayInitials[index]).frame(maxWidth: .infinity)
                }
            }
            .font(.caption)
            .foregroundStyle(AppTheme.tertiaryText)
            .accessibilityHidden(true)
        }
        .padding(.top, 24)
        .overlay(alignment: .top) { AppHairline() }
    }

    private var weekdayReadout: String {
        let index = selectedWeekday ?? analysis.weekdayTotals.indices.max { analysis.weekdayTotals[$0] < analysis.weekdayTotals[$1] } ?? 0
        let total = analysis.weekdayTotals[index]
        let days = analysis.weekdayDays[index]
        let prefix = selectedWeekday == nil ? "Más gasto los \(Self.weekdayNames[index])" : Self.weekdayNames[index].capitalized
        guard days > 0 else { return "\(prefix): \(money(total))" }
        return "\(prefix): \(money(total)) · \(money(total / Double(days))) por día"
    }

    private var weeksSection: some View {
        let values = analysis.weeks.map { weeksPerDay ? $0.total / Double(max($0.days, 1)) : $0.total }
        let maxValue = max(values.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Gasto por semana")
                Spacer()
                segmented([false, true], selection: $weeksPerDay, height: 34, fontSize: 12) { $0 ? "Por día" : "Total" }
                    .fixedSize()
            }
            ForEach(Array(analysis.weeks.enumerated()), id: \.element.id) { index, week in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(week.label).fontWeight(.medium)
                        Spacer()
                        Text(money(values[index])).fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    bar(fraction: values[index] / maxValue, tint: AppTheme.accent)
                    Text(week.count == 1 ? "1 gasto" : "\(week.count) gastos")
                        .font(.caption)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 24)
        .overlay(alignment: .top) { AppHairline() }
    }

    private var sizesSection: some View {
        let values = analysis.buckets.map { sizesByCount ? Double($0.count) : $0.total }
        let maxValue = max(values.max() ?? 0, 1)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle("Tamaño de tus compras")
                Spacer()
                segmented([false, true], selection: $sizesByCount, height: 34, fontSize: 12) { $0 ? "Compras" : "Monto" }
                    .fixedSize()
            }
            ForEach(Array(analysis.buckets.enumerated()), id: \.element.id) { index, bucket in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(bucket.label)
                        Spacer()
                        Text(sizesByCount ? "\(bucket.count) compras" : money(bucket.total)).fontWeight(.semibold)
                    }
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    bar(fraction: values[index] / maxValue, tint: AppTheme.tertiaryText)
                    Text(sizesByCount ? money(bucket.total) : (bucket.count == 1 ? "1 compra" : "\(bucket.count) compras"))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                .accessibilityElement(children: .combine)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("Compra habitual (mediana)")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                Spacer()
                Text(money(analysis.median))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { AppHairline() }
        }
        .padding(.top, 24)
        .overlay(alignment: .top) { AppHairline() }
    }

    private var habitTiles: some View {
        let elapsed = analysis.isRange ? analysis.elapsedDays : 0
        let daysWith = analysis.daysWithSpending
        let daysWithout = max(elapsed - daysWith, 0)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            habitTile(
                label: "Días con gasto",
                value: "\(daysWith)",
                sub: elapsed > 0 ? "de \(elapsed) días transcurridos" : "fechas distintas con registros",
                fraction: elapsed > 0 ? Double(daysWith) / Double(elapsed) : nil
            )
            habitTile(
                label: "Días sin gastar",
                value: elapsed > 0 ? "\(daysWithout)" : "—",
                sub: elapsed > 0 ? "\(Int((Double(daysWithout) / Double(elapsed) * 100).rounded()))% del período" : "Requiere un mes",
                fraction: elapsed > 0 ? Double(daysWithout) / Double(elapsed) : nil
            )
            habitTile(
                label: "Categorías activas",
                value: "\(analysis.categories.count)",
                sub: analysis.categories.first.map { "Mayor: \($0.category.nombre)" } ?? "—",
                fraction: nil
            )
            habitTile(
                label: "Concentración",
                value: "\(Int(analysis.concentration.rounded()))%",
                sub: "en las 3 principales",
                fraction: analysis.concentration / 100
            )
        }
    }

    private func habitTile(label: String, value: String, sub: String, fraction: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.8)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
            if let fraction {
                bar(fraction: fraction, tint: AppTheme.primaryText, height: 4)
                    .padding(.vertical, 3)
            }
            Text(sub)
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
                .lineLimit(2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background(AppTheme.cardBackground())
        .accessibilityElement(children: .combine)
    }

    private var paymentsContent: some View {
        let total = max(analysis.total, 0.01)
        let recurring = analysis.recurring
        let oneTime = (total: analysis.total - recurring.total, count: analysis.expenses.count - recurring.count)
        let recurringShare = Int((recurring.total / total * 100).rounded())

        return VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle("Métodos de pago")
                stackedBar(analysis.payments.enumerated().map { (AppTheme.categoryColor(at: $0.offset), $0.element.total) })
                    .accessibilityLabel("Reparto del gasto por método de pago")
                ForEach(Array(analysis.payments.enumerated()), id: \.element.id) { index, payment in
                    HStack(spacing: 10) {
                        Circle().fill(AppTheme.categoryColor(at: index)).frame(width: 9, height: 9)
                        Text(payment.name)
                        Spacer(minLength: 8)
                        (Text(money(payment.total)).fontWeight(.semibold)
                         + Text(" · \(Int((payment.total / total * 100).rounded()))% · \(payment.count) gastos").foregroundColor(AppTheme.tertiaryText))
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, 24)
            .overlay(alignment: .top) { AppHairline() }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    sectionTitle("Recurrentes vs. puntuales")
                    (Text("El ") + Text("\(recurringShare)%").fontWeight(.semibold).foregroundColor(AppTheme.primaryText) + Text(" de tu gasto es recurrente"))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                stackedBar([(AppTheme.categoryColor(at: 2), recurring.total), (AppTheme.categoryColor(at: 0), oneTime.total)])
                    .accessibilityLabel("\(recurringShare)% recurrente")
                HStack(alignment: .top, spacing: 16) {
                    splitColumn(color: AppTheme.categoryColor(at: 2), label: "Recurrente", total: recurring.total, count: recurring.count)
                    splitColumn(color: AppTheme.categoryColor(at: 0), label: "Puntual", total: oneTime.total, count: oneTime.count)
                }
            }
            .padding(.top, 24)
            .overlay(alignment: .top) { AppHairline() }
        }
        .padding(.horizontal, 20)
        .transition(.opacity)
    }

    private func splitColumn(color: Color, label: String, total: Double, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(label)
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
            Text(money(total))
                .font(.system(size: 20, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
            Text(count == 1 ? "1 gasto" : "\(count) gastos")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var topContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Mayores gastos")
                .padding(.bottom, 6)
            ForEach(analysis.topExpenses) { expense in
                HStack(spacing: 12) {
                    Circle().fill(expense.categoria.color).frame(width: 9, height: 9)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.descripcion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        Text("\(expense.categoria.nombre) · \(expense.fecha.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))))")
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(money(expense.monto))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Text("\(analysis.total > 0 ? Int((expense.monto / analysis.total * 100).rounded()) : 0)% del total")
                            .font(.caption)
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                    .monospacedDigit()
                }
                .padding(.vertical, 12)
                .overlay(alignment: .top) { AppHairline() }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 24)
        .overlay(alignment: .top) { AppHairline() }
        .padding(.horizontal, 20)
        .transition(.opacity)
    }

    // MARK: - Proyección

    @ViewBuilder
    private var projectionContent: some View {
        HStack(spacing: 12) {
            Text("Mes actual completo; el período elegido no cambia esta estimación.")
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            Spacer(minLength: 8)
            Button {
                Task { await forecastModel.load(using: expenses) }
            } label: {
                Label("Actualizar", systemImage: "arrow.clockwise")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(Capsule().fill(AppTheme.popoverSurface))
            }
            .buttonStyle(.pressable(scale: 0.96))
            .disabled(forecastModel.isLoading)
            .opacity(forecastModel.isLoading ? 0.5 : 1)
        }
        .padding(.horizontal, 20)

        Group {
            if let forecast = forecastModel.forecast {
                ForecastContent(forecast: forecast, pendingExpenseCount: expenses.pendingExpenseCount)
            } else if forecastModel.isLoading {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cargando historial y recurrentes…")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.surface)
                        .frame(height: 300)
                        .overlay { ProgressView().tint(AppTheme.secondaryText) }
                }
                .accessibilityElement(children: .combine)
            }
            if let error = forecastModel.error {
                VStack(alignment: .leading, spacing: 12) {
                    Label("No pudimos actualizar la proyección", systemImage: "wifi.exclamationmark")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBackground())
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Piezas

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 17, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(AppTheme.primaryText)
            .accessibilityAddTraits(.isHeader)
    }

    private func segmented<Value: Hashable>(
        _ values: [Value],
        selection: Binding<Value>,
        height: CGFloat,
        fontSize: CGFloat,
        minWidth: CGFloat? = nil,
        label: @escaping (Value) -> String
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                let isSelected = selection.wrappedValue == value
                Button {
                    withAnimation(AppMotion.standard) { selection.wrappedValue = value }
                } label: {
                    Text(label(value))
                        .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(minWidth: minWidth, maxWidth: minWidth == nil && height >= 40 ? .infinity : nil, minHeight: height)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(height >= 40 ? 4 : 3)
        .background(Capsule().fill(AppTheme.popoverSurface))
    }

    private func bar(fraction: Double, tint: Color, height: CGFloat = 6) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.track)
                Capsule()
                    .fill(tint)
                    .frame(width: fraction > 0 ? max(proxy.size.width * min(fraction, 1), height) : 0)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func stackedBar(_ parts: [(Color, Double)]) -> some View {
        let total = max(parts.reduce(0) { $0 + $1.1 }, 0.01)
        return GeometryReader { proxy in
            let available = proxy.size.width - CGFloat(max(parts.count - 1, 0)) * 2
            HStack(spacing: 2) {
                ForEach(parts.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(parts[index].0)
                        .frame(width: max(4, available * parts[index].1 / total))
                }
            }
        }
        .frame(height: 12)
    }

    private func splitAmount(_ value: Double) -> some View {
        let whole = Double(Int(value)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = (Locale.current.decimalSeparator ?? ".") + String(format: "%02d", Int((value * 100).rounded()) % 100)
        return (Text(whole).font(.system(size: 44, weight: .semibold)).foregroundStyle(AppTheme.primaryText)
                + Text(cents).font(.system(size: 26, weight: .semibold)).foregroundStyle(AppTheme.tertiaryText))
            .tracking(-1.5)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
            .accessibilityLabel(money(value))
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

/// Total del período y gráfico de evolución con su propio estado.
///
/// Separado de `StatsView` porque `chartXSelection` cambia la selección en
/// cada movimiento del dedo: dentro de la pantalla grande eso recalculaba
/// todas las secciones de Análisis a cada fotograma.
private struct StatsEvolutionSection: View {
    private enum EvolutionMode: Hashable { case perPoint, cumulative }

    let analysis: StatsPeriodAnalysis
    @State private var evolutionMode: EvolutionMode = .perPoint
    @State private var selectedPoint: Int?
    @State private var showsDailyData = false

    var body: some View { totalSection }

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gasto total · \(analysis.title)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                splitAmount(analysis.total)
                HStack(spacing: 8) {
                    HomeSpendDelta(percent: analysis.totalDelta, style: .pill)
                    Text(analysis.comparisonText)
                }
                .font(.footnote)
                .foregroundStyle(AppTheme.secondaryText)
            }

            segmented(
                [EvolutionMode.perPoint, .cumulative],
                selection: $evolutionMode,
                height: 36,
                fontSize: 13,
                minWidth: 96
            ) { $0 == .perPoint ? (analysis.isRange ? "Por día" : "Por mes") : "Acumulado" }
            .fixedSize()

            Text(readout)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppTheme.primaryText)
                .frame(minHeight: 18, alignment: .leading)
                .contentTransition(.numericText())

            evolutionChart

            HStack {
                Text(analysis.points.first?.label ?? "")
                Spacer()
                Text(analysis.points.isEmpty ? "" : analysis.points[analysis.points.count / 2].label)
                Spacer()
                Text(analysis.points.last?.label ?? "")
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(AppTheme.tertiaryText)
            .padding(.top, -6)

            HStack(spacing: 18) {
                legend(color: AppTheme.accent, dashed: false, text: "Actual")
                if evolutionMode == .cumulative, let label = analysis.previousLabel {
                    legend(color: AppTheme.tertiaryText, dashed: true, text: label)
                }
                Spacer()
                Text("Máx. \(money(evolutionMax))")
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)

            dailyDataDisclosure
        }
        .padding(.horizontal, 20)
    }

    private var cumulative: [StatsPeriodAnalysis.CumulativePoint] { analysis.cumulative }
    private var previousCumulative: [StatsPeriodAnalysis.CumulativePoint] { analysis.previousCumulative }

    private var evolutionMax: Double {
        switch evolutionMode {
        case .perPoint: return analysis.points.map(\.total).max() ?? 0
        case .cumulative: return max(cumulative.last?.total ?? 0, previousCumulative.last?.total ?? 0)
        }
    }

    private var readout: String {
        guard let selectedPoint, let point = analysis.points.first(where: { $0.index == selectedPoint }) else {
            return analysis.isRange ? "Toca el gráfico para ver cada día" : "Toca el gráfico para ver cada mes"
        }
        if evolutionMode == .cumulative, let running = cumulative.first(where: { $0.index == selectedPoint }) {
            return "\(point.label) · \(money(running.total)) acumulado"
        }
        let count = point.count == 1 ? "1 gasto" : "\(point.count) gastos"
        return point.count == 0 ? "\(point.label) · sin gastos" : "\(point.label) · \(money(point.total)) · \(count)"
    }

    private var evolutionChart: some View {
        Chart {
            switch evolutionMode {
            case .perPoint:
                ForEach(analysis.points) { point in
                    BarMark(
                        x: .value("Día", String(point.index)),
                        y: .value("Gasto", point.isFuture ? 0 : point.total),
                        width: .ratio(0.62)
                    )
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
                    .foregroundStyle(barColor(point))
                }
            case .cumulative:
                ForEach(previousCumulative, id: \.index) { item in
                    LineMark(x: .value("Día", String(item.index)), y: .value("Acumulado", item.total), series: .value("Serie", "Anterior"))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        .interpolationMethod(.monotone)
                }
                ForEach(cumulative, id: \.index) { item in
                    LineMark(x: .value("Día", String(item.index)), y: .value("Acumulado", item.total), series: .value("Serie", "Actual"))
                        .foregroundStyle(AppTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                    AreaMark(x: .value("Día", String(item.index)), y: .value("Acumulado", item.total), series: .value("Serie", "Actual"))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.accent.opacity(0.22), .clear], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                }
            }
            if let selectedPoint {
                RuleMark(x: .value("Día", String(selectedPoint)))
                    .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXSelection(value: Binding(
            get: { selectedPoint.map(String.init) },
            set: { selectedPoint = $0.flatMap(Int.init) }
        ))
        .chartXScale(domain: analysis.points.map { String($0.index) })
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot
                .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.separator).frame(height: 1) }
                .overlay(alignment: .top) { Rectangle().fill(AppTheme.separator.opacity(0.5)).frame(height: 1) }
        }
        .frame(height: 150)
        .accessibilityLabel(analysis.isRange ? "Gasto diario de \(analysis.title)" : "Gasto mensual del historial")
    }

    private func barColor(_ point: StatsPeriodAnalysis.Point) -> Color {
        if point.index == selectedPoint { return AppTheme.primaryText }
        if analysis.isInProgress, point.index == analysis.elapsedDays { return AppTheme.accent }
        return analysis.isInProgress || !analysis.isRange ? AppTheme.primaryText.opacity(0.22) : AppTheme.accent.opacity(0.75)
    }

    private func legend(color: Color, dashed: Bool, text: String) -> some View {
        HStack(spacing: 7) {
            if dashed {
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .frame(width: 14, height: 0)
            } else {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 8)
            }
            Text(text)
        }
    }

    private var dailyDataDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(AppMotion.standard) { showsDailyData.toggle() }
            } label: {
                HStack {
                    Label(analysis.isRange ? "Ver datos por día" : "Ver datos por mes", systemImage: "tablecells")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .rotationEffect(.degrees(showsDailyData ? 180 : 0))
                }
                .foregroundStyle(AppTheme.primaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(AppTheme.popoverSurface))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if showsDailyData {
                VStack(spacing: 0) {
                    ForEach(analysis.points.filter { !$0.isFuture }.reversed()) { point in
                        HStack {
                            Text(point.label).foregroundStyle(AppTheme.secondaryText)
                            Spacer()
                            Text(point.count == 0 ? "—" : money(point.total)).foregroundStyle(AppTheme.primaryText)
                        }
                        .font(.footnote)
                        .monospacedDigit()
                        .padding(.vertical, 8)
                        .overlay(alignment: .top) { AppHairline() }
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private func segmented<Value: Hashable>(
        _ values: [Value],
        selection: Binding<Value>,
        height: CGFloat,
        fontSize: CGFloat,
        minWidth: CGFloat? = nil,
        label: @escaping (Value) -> String
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(values, id: \.self) { value in
                let isSelected = selection.wrappedValue == value
                Button {
                    withAnimation(AppMotion.standard) { selection.wrappedValue = value }
                } label: {
                    Text(label(value))
                        .font(.system(size: fontSize, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(minWidth: minWidth, maxWidth: minWidth == nil && height >= 40 ? .infinity : nil, minHeight: height)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(height >= 40 ? 4 : 3)
        .background(Capsule().fill(AppTheme.popoverSurface))
    }

    private func splitAmount(_ value: Double) -> some View {
        let whole = Double(Int(value)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = (Locale.current.decimalSeparator ?? ".") + String(format: "%02d", Int((value * 100).rounded()) % 100)
        return (Text(whole).font(.system(size: 44, weight: .semibold)).foregroundStyle(AppTheme.primaryText)
                + Text(cents).font(.system(size: 26, weight: .semibold)).foregroundStyle(AppTheme.tertiaryText))
            .tracking(-1.5)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: value))
            .accessibilityLabel(money(value))
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

#Preview {
    StatsView()
        .environment(ExpenseStore())
        .environment(BudgetStore())
}
