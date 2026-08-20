import SwiftUI

struct ProfileView: View {
    @Environment(ExpenseStore.self) private var store
    @AppStorage(AppAppearancePreference.storageKey) private var appearanceRawValue = AppAppearancePreference.system.rawValue
    @AppStorage(LocalNotificationManager.weeklySummaryEnabledKey) private var weeklySummaryEnabled = true
    @AppStorage(LocalNotificationManager.dailyExpenseReminderEnabledKey) private var dailyExpenseReminderEnabled = true
    @AppStorage(LocalNotificationManager.dailyExpenseReminderHourKey) private var dailyExpenseReminderHour = 21
    @AppStorage(LocalNotificationManager.dailyExpenseReminderMinuteKey) private var dailyExpenseReminderMinute = 0
    @AppStorage(LocalNotificationManager.budgetAlertsEnabledKey) private var budgetAlertsEnabled = true
    @AppStorage(LocalNotificationManager.budgetAlertThresholdKey) private var budgetAlertThreshold = 0.80
    @AppStorage(SavingsGoalSettings.enabledKey) private var savingsGoalEnabled = false
    @AppStorage(SavingsGoalSettings.monthlyTargetKey) private var monthlySavingsTarget = 0.0

    private let budgetAlertThresholds: [(value: Double, title: String)] = [
        (0.50, "50%"),
        (0.80, "80%"),
        (1.00, "100%")
    ]

    private var dailyReminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: dailyExpenseReminderHour,
                minute: dailyExpenseReminderMinute,
                second: 0,
                of: Date()
            ) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            dailyExpenseReminderHour = components.hour ?? 21
            dailyExpenseReminderMinute = components.minute ?? 0
        }
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    header
                    sessionCard
                    appearanceCard
                    notificationsCard
                    savingsGoalCard
                    logoutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
        }
        .onChange(of: weeklySummaryEnabled) { _, _ in
            Task {
                await LocalNotificationManager.prepareWeeklySummary(expenses: store.gastos)
            }
        }
        .onChange(of: dailyExpenseReminderEnabled) { _, _ in
            Task {
                await LocalNotificationManager.prepareDailyExpenseReminder()
            }
        }
        .onChange(of: dailyExpenseReminderHour) { _, _ in
            Task {
                await LocalNotificationManager.prepareDailyExpenseReminder()
            }
        }
        .onChange(of: dailyExpenseReminderMinute) { _, _ in
            Task {
                await LocalNotificationManager.prepareDailyExpenseReminder()
            }
        }
        .onChange(of: budgetAlertsEnabled) { _, enabled in
            if enabled {
                Task {
                    _ = await LocalNotificationManager.requestBudgetAlertAuthorizationIfNeeded()
                }
            } else {
                LocalNotificationManager.removeBudgetAlerts()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Perfil")
                .font(.system(size: 32, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.primaryText)
            Text("Gestiona tu sesión")
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(AppTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.currentUser?.name ?? "Sesión activa")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text(store.currentUser?.email ?? "Sin correo")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                }
                Spacer()
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Apariencia")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Elige claro, oscuro o sigue el sistema.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                }
            }

            Picker("Apariencia", selection: $appearanceRawValue) {
                ForEach(AppAppearancePreference.allCases) { option in
                    Label(option.title, systemImage: option.icon)
                        .tag(option.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .tint(AppTheme.accent)
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notificaciones")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Ajusta avisos semanales y de presupuesto.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                }
            }

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Resumen semanal",
                    subtitle: "Domingos a las 7:00 p.m.",
                    icon: "calendar.badge.clock",
                    isOn: $weeklySummaryEnabled
                )

                Divider().overlay(AppTheme.border)

                settingsToggle(
                    title: "Recordatorio diario",
                    subtitle: "Para registrar gastos antes de cerrar el día.",
                    icon: "bell.and.waves.left.and.right.fill",
                    isOn: $dailyExpenseReminderEnabled
                )

                if dailyExpenseReminderEnabled {
                    Divider().overlay(AppTheme.border)

                    HStack(spacing: 12) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Text("Hora")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)

                        Spacer()

                        DatePicker("", selection: dailyReminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .tint(AppTheme.accent)
                    }
                    .padding(14)
                }

                Divider().overlay(AppTheme.border)

                settingsToggle(
                    title: "Alertas de presupuesto",
                    subtitle: "Avísame cuando una categoría llegue al umbral.",
                    icon: "target",
                    isOn: $budgetAlertsEnabled
                )
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.insetSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
            )

            VStack(alignment: .leading, spacing: 10) {
                Text("Umbral de alerta")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .foregroundStyle(AppTheme.primaryText.opacity(0.48))

                Picker("Umbral de alerta", selection: $budgetAlertThreshold) {
                    ForEach(budgetAlertThresholds, id: \.value) { threshold in
                        Text(threshold.title).tag(threshold.value)
                    }
                }
                .pickerStyle(.segmented)
                .tint(AppTheme.accent)
                .disabled(!budgetAlertsEnabled)
                .opacity(budgetAlertsEnabled ? 1 : 0.45)
            }
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private var savingsGoalCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryAccent)
                    .frame(width: 32, height: 32)
                    .background(AppTheme.secondaryAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Objetivo de ahorro")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Protege una parte de tu presupuesto mensual.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                }
            }

            VStack(spacing: 0) {
                settingsToggle(
                    title: "Meta mensual",
                    subtitle: "Inicio calculará cuánto puedes gastar sin tocarla.",
                    icon: "target",
                    isOn: $savingsGoalEnabled
                )

                if savingsGoalEnabled {
                    Divider().overlay(AppTheme.border)

                    HStack(spacing: 12) {
                        Image(systemName: "dollarsign")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.secondaryAccent)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.secondaryAccent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quiero ahorrar")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.primaryText)
                            Text("Monto objetivo para cada mes.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.primaryText.opacity(0.52))
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Text("$")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(AppTheme.secondaryAccent)
                            TextField(
                                "0",
                                value: $monthlySavingsTarget,
                                format: .number.precision(.fractionLength(2))
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 92)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 40)
                        .background(
                            Capsule()
                                .fill(AppTheme.surface)
                                .overlay(Capsule().stroke(AppTheme.strongBorder, lineWidth: 1))
                        )
                    }
                    .padding(14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.insetSurface)
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.strongBorder, lineWidth: 1))
            )
        }
        .padding(18)
        .background(AppTheme.cardBackground(cornerRadius: 22))
    }

    private func settingsToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.primaryText.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(AppTheme.accent)
        .padding(14)
    }

    private var logoutButton: some View {
        Button {
            store.logout()
        } label: {
            Text("Cerrar sesión")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppTheme.negative.opacity(0.85), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

}

#Preview {
    let store = ExpenseStore()
    store.currentUser = AuthenticatedUser(id: "1", email: "nico@mail.com", name: "Nicolas")
    return ProfileView()
        .environment(store)
}
