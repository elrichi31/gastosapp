import SwiftUI
import UserNotifications

/// Ajustes de notificaciones dentro de Cuenta.
///
/// Cada aviso es una fila con su icono y un resumen de cuándo llega; al
/// activarlo se despliegan sus opciones debajo (hora o umbral). Si el permiso
/// está bloqueado en Ajustes lo decimos arriba, porque los interruptores
/// encendidos no sirven de nada sin él.
struct NotificationSettingsSection: View {
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
        VStack(spacing: 10) {
            if isBlocked {
                blockedBanner
                    .transition(AppMotion.reveal)
            }

            VStack(spacing: 0) {
                row(
                    icon: "calendar",
                    tint: AppTheme.info,
                    title: "Resumen semanal",
                    subtitle: weeklySummaryEnabled ? "Domingos a las \(Self.timeFormatter.string(from: weeklySummaryDate))" : "Lo que gastaste, cada domingo.",
                    isOn: $weeklySummaryEnabled.animation(AppMotion.expand)
                )

                AppHairline().padding(.leading, 64)

                row(
                    icon: "bell.badge",
                    tint: AppTheme.accent,
                    title: "Recordatorio diario",
                    subtitle: dailyExpenseReminderEnabled ? "Todos los días a las \(reminderTimeText)" : "Para anotar lo del día.",
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

                AppHairline().padding(.leading, 64)

                row(
                    icon: "chart.pie",
                    tint: AppTheme.warning,
                    title: "Alertas de presupuesto",
                    subtitle: budgetAlertsEnabled
                        ? "Al llegar al \(percent(budgetAlertThreshold)) de una categoría"
                        : "Antes de pasarte del límite.",
                    isOn: $budgetAlertsEnabled.animation(AppMotion.expand)
                )
                if budgetAlertsEnabled {
                    option(title: "Avisar al") { thresholdPicker }
                        .transition(AppMotion.reveal)
                }
            }
            .background(AppTheme.cardBackground(cornerRadius: 20))
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
        }
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
