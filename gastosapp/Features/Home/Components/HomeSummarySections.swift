import SwiftUI

// Secciones de la pantalla Resumen, según el canvas «Control de Gastos — Inicio iOS».
// Tarjetas planas de radio 22, títulos de 17 pt y cifras con dígitos tabulares.

// MARK: - Piezas compartidas

private extension View {
    func homeCard(padding: EdgeInsets = EdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground())
    }
}

private func money(_ value: Double) -> String {
    value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
}

/// Título de tarjeta con subtítulo opcional y un enlace a la derecha.
private struct HomeCardHeader: View {
    let title: String
    var subtitle: Text?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.primaryText)
                if let subtitle {
                    subtitle
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(minHeight: 44)
                    .padding(.vertical, -12)
                    .contentShape(.rect)
                    .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// Variación de gasto: subir es malo (rosa) y bajar es bueno (verde).
///
/// Por debajo del 1 % no se muestra: es ruido, no una tendencia.
struct HomeSpendDelta: View {
    enum Style { case pill, inline }

    let percent: Double?
    var style: Style = .inline
    /// «vs. ayer»; sólo en estilo `inline`.
    var comparison: String?

    var body: some View {
        if let percent, abs(percent) >= 1 {
            let isUp = percent > 0
            let tint = isUp ? AppTheme.negative : AppTheme.positive
            let value = "\(Int(abs(percent).rounded()))%"

            switch style {
            case .pill:
                HStack(spacing: 4) {
                    arrow(isUp: isUp, size: 11)
                    Text("\(value) \(isUp ? "más" : "menos")")
                }
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Capsule().fill(tint.opacity(isUp ? 0.16 : 0.14)))
                .accessibilityLabel("\(value) \(isUp ? "más" : "menos")")
            case .inline:
                HStack(spacing: 2) {
                    arrow(isUp: isUp, size: 10)
                    Text(value).fontWeight(.semibold).foregroundStyle(tint)
                    if let comparison {
                        Text(" \(comparison)").foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(tint)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func arrow(isUp: Bool, size: CGFloat) -> some View {
        Image(systemName: "arrow.up")
            .font(.system(size: size, weight: .heavy))
            .rotationEffect(.degrees(isUp ? 0 : 180))
            .accessibilityHidden(true)
    }
}

/// Barra de progreso fina con riel.
private struct HomeProgressBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 6

    var body: some View {
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
}

/// Icono en círculo teñido, como los de las filas de «Ritmo del mes».
private struct HomeRoundGlyph: View {
    let systemName: String
    let tint: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(Circle().fill(tint.opacity(0.18)))
            .accessibilityHidden(true)
    }
}

// MARK: - Aviso de correo

struct HomeEmailBanner: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HomeRoundGlyph(systemName: "tray", tint: AppTheme.accent)
                Text(count == 1 ? "1 movimiento por revisar" : "\(count) movimientos por revisar")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    Text("Revisar")
                    Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(minHeight: 56)
            .background(Capsule().fill(AppTheme.surface))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(scale: 0.98))
    }
}

// MARK: - Gasto del mes

struct HomeMonthSpendHero: View {
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize = 44.0
    let total: Double
    let delta: Double?
    let comparisonLabel: String

    private var parts: (whole: String, cents: String) {
        let whole = Double(Int(total)).formatted(.currency(code: "USD").precision(.fractionLength(0)))
        let cents = Int((total * 100).rounded()) % 100
        let separator = Locale.current.decimalSeparator ?? "."
        return (whole, separator + String(format: "%02d", cents))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gasto del mes")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)

            (Text(parts.whole)
                .font(.system(size: amountSize, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
             + Text(parts.cents)
                .font(.system(size: amountSize * 0.6, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText))
                .tracking(-1.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: total))
                .accessibilityLabel(money(total))

            HStack(spacing: 8) {
                HomeSpendDelta(percent: delta, style: .pill)
                Text(comparisonLabel)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.statementBackground())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Ritmo del mes

struct HomePaceSection: View {
    let pulse: HomeMonthPulse

    var body: some View {
        VStack(spacing: 0) {
            row(
                icon: "clock",
                tint: AppTheme.info,
                title: "Hoy",
                detail: pulse.todayCount == 1 ? "1 gasto" : "\(pulse.todayCount) gastos",
                value: money(pulse.todayTotal),
                delta: pulse.todayDelta,
                comparison: "vs. ayer"
            )
            AppHairline()
            row(
                icon: "list.bullet.rectangle",
                tint: AppTheme.secondaryAccent,
                title: "Transacciones",
                detail: "ticket medio \(money(pulse.averageTicket))",
                value: "\(pulse.monthCount)",
                delta: pulse.countDelta,
                comparison: "vs. \(pulse.previousPeriodLabel)"
            )
            AppHairline()
            row(
                icon: "chart.line.uptrend.xyaxis",
                tint: AppTheme.warning,
                title: "Cierre estimado",
                detail: "ritmo de \(money(pulse.pacePerDay))/día",
                value: money(pulse.projectedClose),
                delta: pulse.projectionDelta,
                comparison: "vs. \(pulse.previousMonthShortName)"
            )
        }
        .homeCard(padding: EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Ritmo del mes")
    }

    private func row(
        icon: String,
        tint: Color,
        title: String,
        detail: String,
        value: String,
        delta: Double?,
        comparison: String
    ) -> some View {
        HStack(spacing: 14) {
            HomeRoundGlyph(systemName: icon, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .semibold))
                    .tracking(-0.5)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HomeSpendDelta(percent: delta, comparison: comparison)
            }
        }
        .frame(minHeight: 64)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Estado del mes

struct HomeBudgetStatusSection: View {
    let metrics: BudgetMonthlyMetrics
    let dailyAllowance: Double?
    let lines: [HomeMonthPulse.BudgetCategoryLine]
    let onAdjust: () -> Void

    private var usedPercent: Int { Int(metrics.progressPercentage.rounded()) }

    private var usedTint: Color {
        if metrics.isOverBudget { return AppTheme.negative }
        return metrics.progressPercentage >= 80 ? AppTheme.warning : AppTheme.accent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Estado del mes")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.2)
                    .foregroundStyle(AppTheme.primaryText)
                Spacer(minLength: 8)
                statusPill
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(money(metrics.remaining))
                        .font(.system(size: 28, weight: .semibold))
                        .tracking(-0.8)
                        .monospacedDigit()
                        .foregroundStyle(metrics.isOverBudget ? AppTheme.negative : AppTheme.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(metrics.isOverBudget ? "por encima del límite" : "disponible")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 8)
                if let dailyAllowance, !metrics.isOverBudget {
                    VStack(alignment: .trailing, spacing: 2) {
                        (Text(money(dailyAllowance))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                         + Text(" /día")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText))
                            .monospacedDigit()
                        Text("para seguir en plan")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }

            VStack(spacing: 8) {
                HomeProgressBar(fraction: metrics.progressPercentage / 100, tint: usedTint, height: 8)
                HStack {
                    (Text(money(metrics.spent)).fontWeight(.semibold).foregroundStyle(AppTheme.primaryText)
                     + Text(" de \(money(metrics.budgeted))"))
                    Spacer()
                    Text("\(usedPercent)%")
                }
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Consumo del presupuesto: \(usedPercent)%, \(money(metrics.spent)) de \(money(metrics.budgeted))")

            if !lines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AppHairline()
                    HStack {
                        Text("Por categoría")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                        Spacer()
                        Button("Ajustar", action: onAdjust)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(minHeight: 44)
                            .padding(.vertical, -12)
                            .buttonStyle(.plain)
                    }
                    ForEach(lines.prefix(5)) { line in
                        categoryLine(line)
                    }
                }
            }
        }
        .homeCard()
    }

    private var statusPill: some View {
        let tint = metrics.isOverBudget ? AppTheme.negative : AppTheme.positive
        return HStack(spacing: 6) {
            Circle().fill(tint).frame(width: 6, height: 6)
            Text(metrics.isOverBudget ? "Límite superado" : "Dentro del límite")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.13)))
    }

    private func categoryLine(_ line: HomeMonthPulse.BudgetCategoryLine) -> some View {
        let percent = line.metrics.progressPercentage
        let tint = line.metrics.isOverBudget ? AppTheme.negative : percent >= 80 ? AppTheme.warning : AppTheme.positive
        return HStack(spacing: 12) {
            Text(line.name)
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .frame(width: 108, alignment: .leading)
            HomeProgressBar(fraction: percent / 100, tint: tint)
            Text("\(Int(percent.rounded()))%")
                .font(.footnote.weight(percent >= 80 ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(percent >= 80 ? tint : AppTheme.secondaryText)
                .frame(width: 44, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.name): \(money(line.metrics.spent)) de \(money(line.metrics.budgeted)), \(Int(percent.rounded()))%")
    }
}

/// Sustituye a «Estado del mes» cuando no hay presupuesto para este mes.
struct HomeNoBudgetCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                HomeRoundGlyph(systemName: "chart.pie", tint: AppTheme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Define un presupuesto")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Así verás cuánto te queda y cuánto gastar por día.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .homeCard(padding: EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            .contentShape(.rect)
        }
        .buttonStyle(.pressable(scale: 0.98))
    }
}

// MARK: - Calendario del mes

struct HomeSpendingCalendar: View {
    let pulse: HomeMonthPulse
    @Binding var selectedDay: Int?

    private static let weekdays = ["L", "M", "X", "J", "V", "S", "D"]
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0), spacing: 4), count: 7)

    private var selected: HomeMonthPulse.CalendarDay? {
        let day = selectedDay ?? pulse.dayOfMonth
        return pulse.calendarDays.first { $0.day == day }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pulse.monthTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(pulse.daysWithSpending == 1 ? "1 día con gasto este mes" : "\(pulse.daysWithSpending) días con gasto este mes")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer(minLength: 8)
                if let selected {
                    Text(readout(for: selected))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Self.weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.secondaryText)
                        .accessibilityHidden(true)
                }
                ForEach(0..<pulse.calendarLeadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 1)
                }
                ForEach(pulse.calendarDays) { day in
                    dayCell(day)
                }
            }

            HStack(spacing: 6) {
                Spacer()
                Text("Menos")
                ForEach([0.0, 0.3, 0.55, 0.85], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(level == 0 ? AppTheme.primaryText.opacity(0.06) : AppTheme.accent.opacity(level))
                        .frame(width: 12, height: 12)
                }
                Text("Más")
            }
            .font(.caption)
            .foregroundStyle(AppTheme.secondaryText)
            .accessibilityHidden(true)
        }
        .homeCard()
    }

    private func dayCell(_ day: HomeMonthPulse.CalendarDay) -> some View {
        let isToday = day.day == pulse.dayOfMonth
        let isSelected = day.day == (selectedDay ?? pulse.dayOfMonth)
        let ratio = pulse.maxDailyTotal > 0 ? day.total / pulse.maxDailyTotal : 0
        let fill: Color = if day.total <= 0 || day.isFuture {
            AppTheme.primaryText.opacity(0.06)
        } else if ratio > 0.66 {
            AppTheme.accent.opacity(0.85)
        } else if ratio > 0.33 {
            AppTheme.accent.opacity(0.55)
        } else {
            AppTheme.accent.opacity(0.3)
        }
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        return Button {
            selectedDay = day.day
        } label: {
            Text("\(day.day)")
                .font(.footnote.weight(isToday ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(day.total > 0 && !day.isFuture ? AppTheme.primaryText : AppTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 40)
                .aspectRatio(1, contentMode: .fit)
                .background(shape.fill(fill))
                .overlay {
                    if isSelected {
                        shape.strokeBorder(AppTheme.primaryText, lineWidth: 2)
                    } else if isToday {
                        shape.strokeBorder(AppTheme.accent, lineWidth: 1.5)
                    }
                }
                .contentShape(shape)
        }
        .buttonStyle(.pressable(scale: 0.92))
        .accessibilityLabel(accessibilityText(for: day))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func readout(for day: HomeMonthPulse.CalendarDay) -> String {
        let date = day.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))
        guard day.count > 0 else { return "\(date) · sin gastos" }
        return "\(date) · \(money(day.total))"
    }

    private func accessibilityText(for day: HomeMonthPulse.CalendarDay) -> String {
        let date = day.date.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "es")))
        guard day.count > 0 else { return "\(date): sin gastos" }
        return "\(date): \(money(day.total)) en \(day.count == 1 ? "1 gasto" : "\(day.count) gastos")"
    }
}

// MARK: - Gasto por categoría

struct HomeCategorySpendSection: View {
    let totals: [(Categoria, Double)]
    let counts: [Int: Int]
    let total: Double
    let onSelect: (Categoria) -> Void

    private var concentration: Int {
        guard total > 0 else { return 0 }
        let top = totals.prefix(3).reduce(0) { $0 + $1.1 }
        return Int((top / total * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeCardHeader(
                title: "Gasto por categoría",
                subtitle: totals.count > 3
                    ? Text("Las 3 principales concentran el ") + Text("\(concentration)%").fontWeight(.semibold).foregroundColor(AppTheme.primaryText) + Text(" del total")
                    : nil
            )

            let maxAmount = totals.first?.1 ?? 0
            ForEach(totals.prefix(6), id: \.0) { category, amount in
                Button {
                    onSelect(category)
                } label: {
                    row(category: category, amount: amount, maxAmount: maxAmount)
                }
                .buttonStyle(.pressable(scale: 0.98))
                .accessibilityHint("Muestra los gastos de esta categoría")
            }
        }
        .homeCard()
    }

    private func row(category: Categoria, amount: Double, maxAmount: Double) -> some View {
        let percent = total > 0 ? Int((amount / total * 100).rounded()) : 0
        let count = counts[category.id] ?? 0
        return VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(category.color).frame(width: 9, height: 9)
                    Text(category.nombre)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(money(amount))
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.primaryText)
            }
            HStack(spacing: 10) {
                HomeProgressBar(fraction: maxAmount > 0 ? amount / maxAmount : 0, tint: category.color)
                Text("\(percent)% · \(count)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(minWidth: 62, alignment: .trailing)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.nombre): \(money(amount)), \(percent)% del total, \(count == 1 ? "1 gasto" : "\(count) gastos")")
    }
}

// MARK: - Gastos recientes

struct HomeRecentExpensesSection: View {
    let expenses: [Expense]
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeCardHeader(title: "Gastos recientes", actionTitle: "Ver todos", action: onSeeAll)
                .padding(.bottom, 6)

            ForEach(expenses) { expense in
                AppHairline()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.descripcion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            HStack(spacing: 6) {
                                Circle().fill(expense.categoria.color).frame(width: 7, height: 7)
                                Text(expense.categoria.nombre)
                                    .fontWeight(.medium)
                                    .foregroundStyle(AppTheme.primaryText)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.insetSurface))
                            Text(expense.fecha.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es"))))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .font(.caption)
                    }
                    Spacer(minLength: 8)
                    Text(money(expense.monto))
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                        .fixedSize()
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
            }
        }
        .homeCard(padding: EdgeInsets(top: 18, leading: 18, bottom: 8, trailing: 18))
    }
}

// MARK: - Próximos recurrentes

struct HomeUpcomingRecurringSection: View {
    let items: [HomeRecurringPreview]
    let committedTotal: Double
    let onSeeAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeCardHeader(title: "Próximos recurrentes", actionTitle: "Ver detalle", action: onSeeAll)

            (Text(money(committedTotal)).fontWeight(.semibold).foregroundColor(AppTheme.primaryText)
             + Text(" previstos hasta fin de mes"))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.top, 2)
                .padding(.bottom, 6)

            ForEach(items) { item in
                AppHairline()
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.expense.descripcion)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                        Text("\(item.date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))) · \(item.expense.cadenceLabel)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer(minLength: 8)
                    Text(money(item.expense.monto))
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.primaryText)
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
            }

            Text("Fechas previstas, no pagos confirmados.")
                .font(.caption)
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.top, 4)
        }
        .homeCard(padding: EdgeInsets(top: 18, leading: 18, bottom: 14, trailing: 18))
    }
}

// MARK: - Mes vacío

struct HomeEmptyMonthState: View {
    let monthName: String
    let onAddExpense: () -> Void
    let onBudget: () -> Void
    let onRecurring: () -> Void
    let onEmail: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 20) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(AppTheme.accent.opacity(0.16)))
                    .accessibilityHidden(true)
                VStack(spacing: 8) {
                    Text("Aún no hay gastos en \(monthName)")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(-0.4)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Registra tu primer gasto y aquí verás tu resumen, la proyección de cierre y el estado de tu presupuesto.")
                        .font(.system(size: 15))
                        .lineSpacing(3)
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: 290)
                }
                .multilineTextAlignment(.center)
                Button(action: onAddExpense) {
                    Label("Agregar gasto", systemImage: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AppTheme.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Capsule().fill(AppTheme.accent))
                }
                .buttonStyle(.pressable(scale: 0.98))
            }
            .padding(EdgeInsets(top: 28, leading: 20, bottom: 20, trailing: 20))
            .frame(maxWidth: .infinity)
            .background(AppTheme.cardBackground())

            VStack(alignment: .leading, spacing: 8) {
                Text("Para empezar")
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.horizontal, 4)
                VStack(spacing: 0) {
                    startRow(icon: "chart.pie", title: "Define un presupuesto", detail: "Límites por categoría para \(monthName).", action: onBudget)
                    AppHairline()
                    startRow(icon: "repeat", title: "Añade tus recurrentes", detail: "Renta, suscripciones y servicios se registran solos.", action: onRecurring)
                    AppHairline()
                    startRow(icon: "envelope", title: "Importa desde el correo", detail: "Trae los movimientos de tu banco.", action: onEmail)
                }
                .background(AppTheme.cardBackground(cornerRadius: 20))
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
            }
        }
    }

    private func startRow(icon: String, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Carga

struct HomeLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                SkeletonBlock(width: 34, height: 34, cornerRadius: 17)
                SkeletonBlock(width: 180, height: 14)
                Spacer(minLength: 0)
            }
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(height: 56)
            .background(Capsule().fill(AppTheme.surface))

            VStack(alignment: .leading, spacing: 14) {
                SkeletonBlock(width: 110, height: 12)
                SkeletonBlock(width: 200, height: 40, cornerRadius: 10)
                SkeletonBlock(width: 150, height: 22, cornerRadius: 11)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.cardBackground())

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: 14) {
                        SkeletonBlock(width: 34, height: 34, cornerRadius: 17)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 120, height: 12)
                            SkeletonBlock(width: 80, height: 10)
                        }
                        Spacer(minLength: 0)
                        SkeletonBlock(width: 70, height: 20)
                    }
                    .frame(height: 64)
                    .overlay(alignment: .top) { if index > 0 { AppHairline() } }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(AppTheme.cardBackground())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cargando tu resumen")
        .accessibilityAddTraits(.updatesFrequently)
    }
}
