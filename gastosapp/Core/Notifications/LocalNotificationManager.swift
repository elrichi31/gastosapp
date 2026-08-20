import Foundation
import UserNotifications

enum LocalNotificationManager {
    static let weeklySummaryEnabledKey = "zenlor.notifications.weeklySummary.enabled"
    static let dailyExpenseReminderEnabledKey = "zenlor.notifications.dailyExpenseReminder.enabled"
    static let dailyExpenseReminderHourKey = "zenlor.notifications.dailyExpenseReminder.hour"
    static let dailyExpenseReminderMinuteKey = "zenlor.notifications.dailyExpenseReminder.minute"
    static let budgetAlertsEnabledKey = "zenlor.notifications.budgetAlerts.enabled"
    static let budgetAlertThresholdKey = "zenlor.notifications.budgetAlert.threshold"

    private static let weeklySummaryID = "zenlor.notifications.weeklySummary"
    private static let dailyExpenseReminderID = "zenlor.notifications.dailyExpenseReminder"
    private static let budgetAlertID = "zenlor.notifications.weeklyBudgetAlert"
    private static let budgetAlertWeekKey = "zenlor.notifications.budgetAlertWeek"
    private static let foregroundDelegate = LocalNotificationForegroundDelegate()

    static var isWeeklySummaryEnabled: Bool {
        UserDefaults.standard.object(forKey: weeklySummaryEnabledKey) as? Bool ?? true
    }

    static var isDailyExpenseReminderEnabled: Bool {
        UserDefaults.standard.object(forKey: dailyExpenseReminderEnabledKey) as? Bool ?? true
    }

    static var dailyExpenseReminderHour: Int {
        let storedValue = UserDefaults.standard.object(forKey: dailyExpenseReminderHourKey) as? Int
        return storedValue ?? 21
    }

    static var dailyExpenseReminderMinute: Int {
        let storedValue = UserDefaults.standard.object(forKey: dailyExpenseReminderMinuteKey) as? Int
        return storedValue ?? 0
    }

    static var areBudgetAlertsEnabled: Bool {
        UserDefaults.standard.object(forKey: budgetAlertsEnabledKey) as? Bool ?? true
    }

    static var budgetAlertThreshold: Double {
        let storedValue = UserDefaults.standard.double(forKey: budgetAlertThresholdKey)
        return storedValue > 0 ? storedValue : 0.80
    }

    static func configureForegroundPresentation() {
        UNUserNotificationCenter.current().delegate = foregroundDelegate
    }

    @MainActor
    static func prepareWeeklySummary(expenses: [Expense]) async {
        guard isWeeklySummaryEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [weeklySummaryID])
            return
        }
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Resumen semanal"
        content.body = weeklySummaryBody(expenses: expenses)
        content.sound = .default

        var date = DateComponents()
        date.calendar = Calendar.current
        date.weekday = 1
        date.hour = 19
        date.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: weeklySummaryID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [weeklySummaryID])
        try? await center.add(request)
    }

    @MainActor
    static func prepareDailyExpenseReminder() async {
        guard isDailyExpenseReminderEnabled else {
            removeDailyExpenseReminder()
            return
        }
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Registra tus gastos"
        content.body = "Tómate un minuto para anotar lo de hoy y mantener tus números al día."
        content.sound = .default

        var date = DateComponents()
        date.calendar = Calendar.current
        date.hour = min(max(dailyExpenseReminderHour, 0), 23)
        date.minute = min(max(dailyExpenseReminderMinute, 0), 59)

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: dailyExpenseReminderID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyExpenseReminderID])
        try? await center.add(request)
    }

    @MainActor
    static func sendBudgetAlertIfNeeded(budget: BudgetMonthly, categories: [BudgetCategoryDetail], expenses: [Expense]) async {
        guard areBudgetAlertsEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [budgetAlertID])
            return
        }
        guard await hasAuthorizedNotificationSettings(), shouldSendBudgetAlertThisWeek() else { return }
        guard let alert = strongestBudgetAlert(budget: budget, categories: categories, expenses: expenses) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ojo con \(alert.categoryName)"
        content.body = "Ya usaste \(alert.percentage)% de ese presupuesto en \(budget.monthTitle)."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: budgetAlertID, content: content, trigger: trigger)

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [budgetAlertID])
        do {
            try await center.add(request)
            markBudgetAlertSentThisWeek()
        } catch {
            return
        }
    }

    static func removeBudgetAlerts() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [budgetAlertID])
    }

    static func removeDailyExpenseReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyExpenseReminderID])
    }

    @MainActor
    static func requestBudgetAlertAuthorizationIfNeeded() async -> Bool {
        await ensureAuthorization()
    }

    private static func weeklySummaryBody(expenses: [Expense]) -> String {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start
            ?? calendar.date(byAdding: .day, value: -6, to: now)
            ?? now

        let weeklyExpenses = expenses.filter { $0.fecha >= weekStart && $0.fecha <= now }
        let total = weeklyExpenses.reduce(0) { $0 + $1.monto }

        guard total > 0 else {
            return "Esta semana no registraste gastos. Buen momento para revisar si falta alguno."
        }

        let topCategory = Dictionary(grouping: weeklyExpenses, by: \.categoria)
            .mapValues { $0.reduce(0) { $0 + $1.monto } }
            .max { $0.value < $1.value }

        if let topCategory {
            return "Esta semana gastaste \(currency(total)). Tu categoría más alta fue \(topCategory.key.nombre)."
        }

        return "Esta semana gastaste \(currency(total))."
    }

    private static func strongestBudgetAlert(
        budget: BudgetMonthly,
        categories: [BudgetCategoryDetail],
        expenses: [Expense]
    ) -> (categoryName: String, percentage: Int)? {
        categories
            .compactMap { category -> (categoryName: String, percentage: Int, value: Double)? in
                let metrics = category.metrics(expenses: expenses, year: budget.anio, month: budget.mes)
                guard metrics.budgeted > 0, metrics.progressValue >= budgetAlertThreshold else { return nil }
                return (
                    category.displayCategory.nombre,
                    Int(round(metrics.progressPercentage)),
                    metrics.progressValue
                )
            }
            .max { $0.value < $1.value }
            .map { ($0.categoryName, $0.percentage) }
    }

    private static func ensureAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func hasAuthorizedNotificationSettings() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private static func shouldSendBudgetAlertThisWeek(calendar: Calendar = .current) -> Bool {
        let currentWeek = currentWeekKey(calendar: calendar)
        return UserDefaults.standard.string(forKey: budgetAlertWeekKey) != currentWeek
    }

    private static func markBudgetAlertSentThisWeek(calendar: Calendar = .current) {
        UserDefaults.standard.set(currentWeekKey(calendar: calendar), forKey: budgetAlertWeekKey)
    }

    private static func currentWeekKey(calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }

    private static func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}

private final class LocalNotificationForegroundDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}
