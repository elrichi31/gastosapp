import SwiftUI
import UserNotifications

/// Pantalla de notificaciones, empujada desde Cuenta.
///
/// Arriba, cómo se verá el próximo aviso; debajo, un bloque por tipo de aviso
/// con su interruptor y, al activarlo, sus opciones (hora o umbral). Si el
/// permiso está bloqueado en Ajustes lo decimos primero, porque los
/// interruptores encendidos no sirven de nada sin él.
struct NotificationsView: View {
    @Environment(ExpenseStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage(LocalNotificationManager.weeklySummaryEnabledKey) private var weeklySummaryEnabled = true
    @AppStorage(LocalNotificationManager.dailyExpenseReminderEnabledKey) private var dailyExpenseReminderEnabled = true
    @AppStorage(LocalNotificationManager.dailyExpenseReminderHourKey) private var dailyExpenseReminderHour = 21
    @AppStorage(LocalNotificationManager.dailyExpenseReminderMinuteKey) private var dailyExpenseReminderMinute = 0
    @AppStorage(LocalNotificationManager.budgetAlertsEnabledKey) private var budgetAlertsEnabled = true
    @AppStorage(LocalNotificationManager.budgetAlertThresholdKey) private var budgetAlertThreshold = 0.80

    @State private var isBlocked = false

    private static let thresholds: [Double] = [0.50, 0.80, 1.00]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private var reminderDate: Date {
        Calendar.current.date(
            bySettingHour: dailyExpenseReminderHour,
            minute: dailyExpenseReminderMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    /// Igual que el aviso programado: domingos a las 19:00.
    private var weeklySummaryDate: Date {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var reminderTime: Binding<Date> {
        Binding {
            reminderDate
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyExpenseReminderHour = components.hour ?? 21
            dailyExpenseReminderMinute = components.minute ?? 0
        }
    }

    private var reminderTimeText: String { Self.timeFormatter.string(from: reminderDate) }

    var body: some View {
        ScrollView { settings }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .navigationTitle("Notificaciones")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.backgroundTop, for: .navigationBar)
    }

    /// Todo lo que va dentro del desplazamiento.
    var settings: some View {
        VStack(alignment: .leading, spacing: 24) {
            if isBlocked {
                blockedBanner
                    .transition(AppMotion.reveal)
            }

            preview

            block(
                "Resumen",
                footer: "Lo que gastaste en la semana y tu categoría más alta."
            ) {
                row(
                    icon: "calendar",
                    tint: AppTheme.info,
                    title: "Resumen semanal",
                    subtitle: weeklySummaryEnabled ? "Domingos a las \(Self.timeFormatter.string(from: weeklySummaryDate))" : "Apagado",
                    isOn: $weeklySummaryEnabled.animation(AppMotion.expand)
                )
            }

            block(
                "Recordatorio",
                footer: "Un empujón para anotar lo del día antes de que se te olvide."
            ) {
                row(
                    icon: "bell.badge",
                    tint: AppTheme.accent,
                    title: "Recordatorio diario",
                    subtitle: dailyExpenseReminderEnabled ? "Todos los días a las \(reminderTimeText)" : "Apagado",
                    isOn: $dailyExpenseReminderEnabled.animation(AppMotion.expand)
                )
                if dailyExpenseReminderEnabled {
                    option(title: "Hora") {
                        DatePicker("Hora del recordatorio", selection: reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                            .environment(\.locale, Locale(identifier: "es_EC"))
                    }
                    .transition(AppMotion.reveal)
                }
            }

            block(
                "Presupuesto",
                footer: "Como mucho un aviso por semana, por la categoría más cerca de su límite."
            ) {
                row(
                    icon: "chart.pie",
                    tint: AppTheme.warning,
                    title: "Alertas de presupuesto",
                    subtitle: budgetAlertsEnabled
                        ? "Al llegar al \(percent(budgetAlertThreshold)) de una categoría"
                        : "Apagado",
                    isOn: $budgetAlertsEnabled.animation(AppMotion.expand)
                )
                if budgetAlertsEnabled {
                    option(title: "Avisar al") { thresholdPicker }
                        .transition(AppMotion.reveal)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, AppScreenMetrics.contentBottomPadding)
        .task { await refreshAuthorization() }
        .onChange(of: scenePhase) { _, phase in
            // Al volver de Ajustes el permiso pudo cambiar.
            if phase == .active { Task { await refreshAuthorization() } }
        }
        .onChange(of: weeklySummaryEnabled) { _, _ in
            Task {
                await LocalNotificationManager.prepareWeeklySummary(expenses: store.gastos)
                await refreshAuthorization()
            }
        }
        .onChange(of: dailyExpenseReminderEnabled) { _, _ in rescheduleReminder() }
        .onChange(of: dailyExpenseReminderHour) { _, _ in rescheduleReminder() }
        .onChange(of: dailyExpenseReminderMinute) { _, _ in rescheduleReminder() }
        .onChange(of: budgetAlertsEnabled) { _, enabled in
            if enabled {
                Task {
                    _ = await LocalNotificationManager.requestBudgetAlertAuthorizationIfNeeded()
                    await refreshAuthorization()
                }
            } else {
                LocalNotificationManager.removeBudgetAlerts()
            }
        }
    }

    // MARK: - Piezas

    /// Un tipo de aviso: título encima, tarjeta y una línea que explica qué trae.
    private func block<Content: View>(_ title: String, footer: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 0) { content() }
                .background(AppTheme.cardBackground(cornerRadius: 20))
                .clipShape(.rect(cornerRadius: 20, style: .continuous))
            Text(footer)
                .font(.footnote)
                .foregroundStyle(AppTheme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
        }
    }

    /// El próximo aviso que llegará, dibujado como un banner del sistema.
    private var nextNotification: (title: String, body: String, when: String)? {
        if dailyExpenseReminderEnabled {
            return ("Registra tus gastos", "Tómate un minuto para anotar lo de hoy y mantener tus números al día.", reminderTimeText)
        }
        if weeklySummaryEnabled {
            return ("Resumen semanal", "Esta semana gastaste… y tu categoría más alta fue…", "domingo")
        }
        if budgetAlertsEnabled {
            return ("Ojo con una categoría", "Ya usaste \(percent(budgetAlertThreshold)) de ese presupuesto este mes.", "al llegar")
        }
        return nil
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Así te llegará")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.horizontal, 4)

            Group {
                if let next = nextNotification {
                    HStack(alignment: .top, spacing: 12) {
                        Image("BrandMark")
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.black))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(next.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.primaryText)
                                Spacer(minLength: 8)
                                Text(next.when)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.tertiaryText)
                            }
                            Text(next.body)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .id(next.title)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .frame(width: 38, height: 38)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(AppTheme.tertiaryText.opacity(0.16)))
                            .accessibilityHidden(true)
                        Text("No recibirás avisos de Zenlor.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer(minLength: 0)
                    }
                    .transition(.opacity)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(AppTheme.separator, lineWidth: 1))
            )
            .animation(AppMotion.fade, value: nextNotification?.title)
            .accessibilityElement(children: .combine)
        }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isOn.wrappedValue ? tint : AppTheme.tertiaryText)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill((isOn.wrappedValue ? tint : AppTheme.tertiaryText).opacity(0.16))
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                }
            }
        }
        .tint(AppTheme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 64)
    }

    /// Opción de un aviso encendido, sangrada bajo su texto.
    private func option<Control: View>(title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 8)
            control()
        }
        .padding(.leading, 64)
        .padding(.trailing, 16)
        .padding(.bottom, 12)
    }

    private var thresholdPicker: some View {
        HStack(spacing: 0) {
            ForEach(Self.thresholds, id: \.self) { value in
                let isSelected = abs(budgetAlertThreshold - value) < 0.001
                Button {
                    withAnimation(AppMotion.standard) { budgetAlertThreshold = value }
                } label: {
                    Text(percent(value))
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .frame(width: 54, height: 34)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        // Va sobre la tarjeta, no sobre el fondo: el gris de los popovers se
        // perdía en modo claro.
        .background(Capsule().fill(AppTheme.primaryText.opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Umbral de alerta")
    }

    private var blockedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.warning)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Notificaciones bloqueadas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Actívalas en Ajustes para recibir estos avisos.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Ajustes", action: openSettings)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.backgroundTop)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(AppTheme.primaryText))
                .buttonStyle(.pressable(scale: 0.96))
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.warning.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.warning.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Lógica

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }

    private func rescheduleReminder() {
        Task {
            await LocalNotificationManager.prepareDailyExpenseReminder()
            await refreshAuthorization()
        }
    }

    private func refreshAuthorization() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        withAnimation(AppMotion.expand) { isBlocked = status == .denied }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
