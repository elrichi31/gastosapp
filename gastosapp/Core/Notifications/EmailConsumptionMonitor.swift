import BackgroundTasks
import Foundation
import UserNotifications

/// Avisa con una notificación cuando el correo trae un consumo nuevo.
///
/// Sin notificaciones push del servidor, la app pide a iOS que la despierte
/// de vez en cuando (`BGAppRefreshTask`): sincroniza el correo, compara los
/// movimientos por revisar con los que ya se conocían y avisa de los nuevos.
/// iOS decide cuándo la despierta según cuánto se usa la app, así que el
/// aviso puede llegar con retraso; no es inmediato como un push.
enum EmailConsumptionMonitor {
    static let taskIdentifier = "zenlor.gastosapp.email-check"
    static let enabledKey = "zenlor.notifications.emailConsumption.enabled"

    private static let seenIDsKey = "zenlor.notifications.emailConsumption.seenIDs"
    private static let notificationID = "zenlor.notifications.emailConsumption"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Pide la próxima revisión. Se llama al pasar a segundo plano y al
    /// terminar cada revisión, porque cada petición sirve una sola vez.
    static func schedule() {
        guard isEnabled else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Movimientos que el usuario ya vio en la app: no se avisa de ellos.
    static func markSeen(_ rows: [EmailMovement]) {
        var seen = seenIDs ?? []
        seen.formUnion(rows.map(\.id))
        storeSeen(seen)
    }

    /// Revisión en segundo plano.
    @MainActor
    static func checkInBackground(store: ExpenseStore) async {
        defer { schedule() }
        guard isEnabled else { return }
        await store.bootstrapSessionIfNeeded()
        guard store.isAuthenticated, store.canAccessProtectedEndpoints else { return }

        let review = EmailReviewStore()
        review.tab = "nuevos"
        // Pide al servidor que lea el correo; sync ya recarga la lista.
        await review.sync(using: store)
        if review.result == nil { await review.load(using: store) }
        guard review.isEnabled == true, let rows = review.result?.pendientes else { return }

        let known = seenIDs
        markSeen(rows)
        // La primera vez sólo se aprende lo que hay, sin avisar de todo.
        guard let known else { return }
        let fresh = rows.filter { !known.contains($0.id) && $0.tipo == "gasto" }
        guard !fresh.isEmpty else { return }
        await notify(fresh)
    }

    private static func notify(_ rows: [EmailMovement]) async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else { return }

        let content = UNMutableNotificationContent()
        if rows.count == 1, let row = rows.first {
            content.title = "Consumo detectado"
            content.body = "\(row.descripcion) · \(row.monto.formatted(.currency(code: "USD").precision(.fractionLength(2)))). Tócalo para revisarlo."
        } else {
            let total = rows.reduce(0) { $0 + $1.monto }
            content.title = "\(rows.count) consumos detectados"
            content.body = "Suman \(total.formatted(.currency(code: "USD").precision(.fractionLength(2)))). Revísalos en Correo."
        }
        content.sound = .default
        content.userInfo = ["destination": "correo"]

        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static var seenIDs: Set<Int>? {
        (UserDefaults.standard.array(forKey: seenIDsKey) as? [Int]).map(Set.init)
    }

    /// Sólo los últimos: los movimientos revisados dejan de estar pendientes.
    private static func storeSeen(_ ids: Set<Int>) {
        UserDefaults.standard.set(Array(ids.sorted().suffix(500)), forKey: seenIDsKey)
    }
}
