import SwiftUI

private struct ProfileTransitionNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Espacio de la transición «burbuja» entre el avatar y la hoja de Cuenta.
    var profileTransitionNamespace: Namespace.ID? {
        get { self[ProfileTransitionNamespaceKey.self] }
        set { self[ProfileTransitionNamespaceKey.self] = newValue }
    }
}

enum ProfileTransition {
    static let sourceID = "perfil"
}

/// Estado de navegación compartido por las cuatro pestañas.
///
/// La barra superior vive en cada pantalla, pero sus acciones (abrir la cuenta,
/// un gasto nuevo, ir a Correo desde la bandeja, filtrar Gastos desde la
/// búsqueda) cruzan pestañas, así que el estado vive aquí y no en cada vista.
@MainActor @Observable
final class AppNavigator {
    enum Panel: Equatable { case search, inbox }

    var selectedTab: MainTabView.Tab = .inicio
    var showsProfile = false
    var showsNewExpense = false
    /// Sección de Gastos que hay que abrir al llegar a la pestaña.
    var pendingGastosSection: GastosSectionMode?
    /// Panel desplegado bajo la barra superior.
    var panel: Panel?
    /// Texto del buscador en Resumen, Plan y Análisis (abre resultados).
    var searchText = ""
    /// Texto del buscador en Gastos, que filtra la lista en su sitio.
    var expenseQuery = ""
    /// Gasto abierto desde el buscador, en detalle o editándolo.
    var expenseSheet: ExpenseSheet?

    enum ExpenseSheet: Identifiable {
        case detail(Expense)
        case edit(Expense)

        var id: String {
            switch self {
            case let .detail(expense): "detail-\(expense.id)"
            case let .edit(expense): "edit-\(expense.id)"
            }
        }
    }

    /// El buscador abierto es el de Gastos: sugiere categorías, pero en cuanto
    /// se escribe el panel se aparta y la lista se filtra debajo.
    var searchFiltersInPlace = false

    /// El panel que se dibuja. En Gastos el de búsqueda sólo se ve mientras
    /// el buscador está vacío, para no tapar la lista que se está filtrando.
    var visiblePanel: Panel? {
        if panel == .search, searchFiltersInPlace,
           !expenseQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        return panel
    }

    func closePanel() {
        withAnimation(AppMotion.fade) {
            panel = nil
            searchText = ""
        }
    }

    func open(_ tab: MainTabView.Tab, section: GastosSectionMode? = nil) {
        closePanel()
        pendingGastosSection = section
        withAnimation(AppMotion.standard) {
            selectedTab = tab
        }
    }

    /// Lleva a Gastos con la lista ya filtrada por `query`.
    func showExpenses(matching query: String) {
        expenseQuery = query
        open(.gastos, section: .movimientos)
    }
}

/// Avisos de la bandeja: correo por revisar, categorías cerca del límite y
/// cobros recurrentes de los próximos días. Todo sale de datos reales.
@MainActor @Observable
final class AppInbox {
    struct Item: Identifiable, Equatable {
        enum Kind { case mail, budget, recurring }

        let id: String
        let kind: Kind
        let title: String
        let subtitle: String
    }

    private(set) var items: [Item] = []
    private(set) var pendingEmailCount = 0
    private let emailReview = EmailReviewStore()
    private let budgetDetail = BudgetDetailStore()
    private static let readKey = "inbox.readSignature"

    /// Firma de lo que había cuando se marcó como leído: si cambia, hay novedades.
    private var signature: String { items.map(\.id).sorted().joined(separator: "|") }

    var hasUnread: Bool {
        !items.isEmpty && UserDefaults.standard.string(forKey: Self.readKey) != signature
    }

    var unreadCount: Int { hasUnread ? items.count : 0 }

    func markRead() {
        UserDefaults.standard.set(signature, forKey: Self.readKey)
        items = items
    }

    func refresh(store: ExpenseStore, budgets: BudgetStore) async {
        guard store.canAccessProtectedEndpoints else {
            items = []
            pendingEmailCount = 0
            return
        }
        emailReview.tab = "nuevos"
        await emailReview.load(using: store)
        pendingEmailCount = emailReview.isEnabled == true ? emailReview.counts["nuevos"] ?? 0 : 0

        let cal = Calendar.current
        let now = Date()
        if let budget = budgets.budgets.first(where: {
            $0.anio == cal.component(.year, from: now) && $0.mes == cal.component(.month, from: now)
        }) {
            await budgetDetail.loadDetail(using: store, budgetID: budget.id)
        }
        rebuild(store: store)
    }

    /// Recalcula sin pedir nada al servidor, p. ej. tras guardar un gasto.
    func rebuild(store: ExpenseStore) {
        let cal = Calendar.current
        let now = Date()
        var next: [Item] = []

        if pendingEmailCount > 0 {
            next.append(Item(
                id: "mail-\(pendingEmailCount)",
                kind: .mail,
                title: pendingEmailCount == 1 ? "1 movimiento del correo" : "\(pendingEmailCount) movimientos del correo",
                subtitle: "Importados · por confirmar"
            ))
        }

        for category in budgetDetail.categories where category.budgetedAmount > 0 {
            let spent = store.gastos
                .filter { $0.categoriaId == category.categoriaId && cal.isDate($0.fecha, equalTo: now, toGranularity: .month) }
                .reduce(0) { $0 + $1.monto }
            let ratio = spent / category.budgetedAmount
            guard ratio >= 0.8 else { continue }
            let name = category.displayCategory.nombre
            next.append(Item(
                id: "budget-\(category.categoriaId)-\(ratio > 1 ? "over" : "near")",
                kind: .budget,
                title: ratio > 1 ? "\(name) superó el límite" : "\(name) cerca del límite",
                subtitle: ratio > 1
                    ? "\(money(spent - category.budgetedAmount)) por encima de \(money(category.budgetedAmount))"
                    : "Quedan \(money(category.budgetedAmount - spent)) de \(money(category.budgetedAmount))"
            ))
        }

        let soon = cal.date(byAdding: .day, value: 3, to: cal.startOfDay(for: now)) ?? now
        for recurring in store.recurringExpenses where recurring.activo {
            guard let date = recurring.nextChargeDate, date <= soon else { continue }
            let day = date.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "es")))
            next.append(Item(
                id: "rec-\(recurring.id)-\(Int(date.timeIntervalSince1970))",
                kind: .recurring,
                title: "\(recurring.descripcion) se registra el \(day)",
                subtitle: "\(money(recurring.monto)) · \(recurring.frecuencia.title.lowercased())"
            ))
        }

        items = next
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }
}
