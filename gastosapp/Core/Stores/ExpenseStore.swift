import Foundation
import Network
import Observation

struct AuthenticatedUser: Hashable, Codable {
    let id: String
    let email: String
    let name: String
}

private struct PersistedAuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let expiresAt: Int
    let tokenType: String
    let user: AuthenticatedUser
    let lastActivityAt: Int?

    func withActivity(_ timestamp: Int) -> PersistedAuthSession {
        PersistedAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            expiresAt: expiresAt,
            tokenType: tokenType,
            user: user,
            lastActivityAt: timestamp
        )
    }
}

private struct PendingExpenseDeletion: Codable, Identifiable {
    let id: Int
    let expense: Expense
}

@MainActor
@Observable
final class ExpenseStore {
    var gastos: [Expense] = [] {
        didSet { WidgetSummaryPublisher.publish(expenses: gastos) }
    }
    var recurringExpenses: [RecurringExpense] = []
    var categorias: [Categoria] = Categoria.fallback
    var metodosPago: [ExpensePaymentMethod] = ExpensePaymentMethod.fallback

    var isLoadingCatalogs = false
    var isLoadingExpenses = false
    var isLoadingRecurringExpenses = false
    var isSavingExpense = false
    var deletingExpenseIDs: Set<Int> = []
    var deletingRecurringExpenseIDs: Set<Int> = []
    var isAuthenticating = false
    var isAuthResolved = false

    var catalogErrorMessage: String?
    var expensesErrorMessage: String?
    var recurringExpensesErrorMessage: String?
    var saveErrorMessage: String?
    var authErrorMessage: String?
    var syncStatusMessage: String?
    var pendingExpenseCount: Int { pendingExpenseDrafts.count + pendingExpenseDeletions.count }

    var currentUser: AuthenticatedUser?
    var baseURL: String

    private var accessToken: String = ""
    private var refreshToken: String = ""
    private var tokenType: String = "bearer"
    private var expiresAt: Int?

    private var hasLoadedCatalogsOnce = false
    private var hasLoadedExpensesOnce = false
    private var hasLoadedRecurringExpensesOnce = false
    private var hasBootstrappedSession = false
    private var pendingExpenseDrafts: [PendingExpenseDraft] = []
    private var pendingExpenseDeletions: [PendingExpenseDeletion] = []
    private var isSyncingPendingExpenses = false
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "zenlor.expenses.network-monitor")

    private static let baseURLKey = "expense.api.baseURL"
    private static let authSessionKey = "expense.api.mobileSession"
    private static let pendingExpensesKey = "expense.api.pendingExpenses"
    private static let pendingExpenseDeletionsKey = "expense.api.pendingExpenseDeletions"
    private static let cachedExpensesKey = "expense.cache.expenses"
    private static let cachedRecurringExpensesKey = "expense.cache.recurringExpenses"
    private static let cachedCategoriesKey = "expense.cache.categories"
    private static let cachedPaymentMethodsKey = "expense.cache.paymentMethods"
    private static let sessionInactivityLimit: TimeInterval = 3 * 24 * 60 * 60
    private static var nowTimestamp: Int {
        Int(Date().timeIntervalSince1970)
    }
    init() {
        let defaults = UserDefaults.standard
        self.baseURL = BackendURLPreference.resolve(
            storedURL: defaults.string(forKey: Self.baseURLKey),
            configuredURL: LocalAPIConfig.baseURL
        )
        defaults.set(self.baseURL, forKey: Self.baseURLKey)
        self.pendingExpenseDrafts = Self.loadPendingExpenseDrafts()
        self.pendingExpenseDeletions = Self.loadPendingExpenseDeletions()
        self.categorias = Self.loadCachedValue([Categoria].self, key: Self.cachedCategoriesKey) ?? Categoria.fallback
        self.metodosPago = Self.loadCachedValue([ExpensePaymentMethod].self, key: Self.cachedPaymentMethodsKey) ?? ExpensePaymentMethod.fallback
        let cachedExpenses = Self.normalizedCachedExpenses(
            Self.loadCachedValue([Expense].self, key: Self.cachedExpensesKey) ?? []
        )
        let pendingDeletionIDs = Set(pendingExpenseDeletions.map(\.id))
        self.gastos = (cachedExpenses.filter { !pendingDeletionIDs.contains($0.id) } + pendingExpenseDrafts
            .map { $0.asExpense(categorias: categorias, metodosPago: metodosPago) }
        )
            .sorted { $0.fecha > $1.fecha }
        self.recurringExpenses = Self.loadCachedValue([RecurringExpense].self, key: Self.cachedRecurringExpensesKey) ?? []
        startNetworkMonitoring()
    }

    var hasBaseURLConfigured: Bool {
        !normalizedBaseURL.isEmpty
    }

    var canAccessProtectedEndpoints: Bool {
        hasBaseURLConfigured && !normalizedAccessToken.isEmpty
    }

    var isAuthenticated: Bool {
        currentUser != nil && canAccessProtectedEndpoints
    }

    var apiBaseURL: String {
        normalizedBaseURL
    }

    var authorizationHeaderValue: String? {
        guard hasBaseURLConfigured, !normalizedAccessToken.isEmpty else { return nil }
        return "\(authorizationScheme) \(normalizedAccessToken)"
    }

    func authorizationHeaderValueRefreshingIfNeeded() async -> String? {
        guard hasBaseURLConfigured else { return nil }
        do {
            try await refreshAccessTokenIfNeeded()
            touchSessionActivity()
            return authorizationHeaderValue
        } catch {
            if case ExpenseStoreError.unauthorized = error {
                handlePotentialUnauthorized(error)
                return nil
            }
            return authorizationHeaderValue
        }
    }

    func refreshSessionActivityWindow() {
        guard isAuthenticated else { return }
        guard let session: PersistedAuthSession = AuthSessionStore.load(for: Self.authSessionKey) else {
            touchSessionActivity()
            return
        }
        guard !isSessionExpiredByInactivity(session) else {
            clearExpiredInactiveSession()
            isAuthResolved = true
            return
        }
        persist(session.withActivity(Self.nowTimestamp))
        authErrorMessage = nil
    }

    func renewMobileSessionWindowIfPossible() async {
        guard isAuthenticated, !normalizedAccessToken.isEmpty else { return }
        do {
            try await refreshSession(force: true)
        } catch {
            if isConnectivityError(error) {
                touchSessionActivity()
                return
            }
            handlePotentialUnauthorized(error)
        }
    }

    func bootstrapSessionIfNeeded() async {
        guard !hasBootstrappedSession else { return }
        hasBootstrappedSession = true
        await bootstrapSession()
    }

    func bootstrapSession() async {
        guard hasBaseURLConfigured else {
            currentUser = nil
            isAuthResolved = true
            return
        }

        var restoredExpiredSession = false

        if let session: PersistedAuthSession = AuthSessionStore.load(for: Self.authSessionKey) {
            guard !isSessionExpiredByInactivity(session) else {
                clearExpiredInactiveSession()
                isAuthResolved = true
                return
            }
            persist(session)
            touchSessionActivity()
            if isAccessTokenExpired {
                do {
                    try await refreshSession(force: true)
                } catch {
                    if !isConnectivityError(error) {
                        clearAuthSession()
                        authErrorMessage = "Tu sesión expiró. Inicia sesión nuevamente."
                        restoredExpiredSession = true
                    }
                }
            }
        } else {
            currentUser = nil
            accessToken = ""
            refreshToken = ""
            tokenType = "bearer"
            expiresAt = nil
        }

        if !restoredExpiredSession {
            authErrorMessage = nil
        }
        isAuthResolved = true
    }

    func login(email: String, password: String) async -> Bool {
        guard hasBaseURLConfigured else {
            authErrorMessage = "Configura la URL del backend antes de iniciar sesión."
            isAuthResolved = true
            return false
        }

        isAuthenticating = true
        authErrorMessage = nil
        defer {
            isAuthenticating = false
            isAuthResolved = true
        }

        do {
            let payload = MobileLoginRequest(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            let body = try JSONEncoder().encode(payload)
            let response = try await request(
                MobileLoginResponse.self,
                path: "/api/mobile/login",
                method: "POST",
                requiresAuth: false,
                body: body
            )

            let session = PersistedAuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? "",
                expiresIn: response.expiresIn,
                expiresAt: response.expiresAt,
                tokenType: response.tokenType,
                user: response.user,
                lastActivityAt: Self.nowTimestamp
            )

            persist(session)
            currentUser = response.user
            authErrorMessage = nil

            await loadCatalogs(force: true)
            await syncPendingExpensesIfPossible()
            await loadExpenses(force: true)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            clearAuthSession()
            authErrorMessage = error.localizedDescription
            return false
        }
    }

    func logout() {
        clearPersistedSession()
        EmailReviewStore.clearCache()
        authErrorMessage = nil
        isAuthResolved = true
    }

    func add(_ gasto: Expense) {
        let normalized = Self.normalizedExpense(gasto)
        // Se arma aparte y se asigna una vez: cada asignación a `gastos`
        // republica el widget y avisa a las vistas.
        var updated = gastos
        updated.removeAll { $0.id == normalized.id }
        let index = updated.firstIndex { $0.fecha <= normalized.fecha } ?? updated.endIndex
        updated.insert(normalized, at: index)
        gastos = updated
    }

    func smartSuggestion(for description: String) -> ExpenseSmartSuggestion? {
        let query = Self.normalizedSuggestionKey(description)
        guard query.count >= 3 else { return nil }

        let queryTokens = Set(query.split(separator: " ").map(String.init))
        var scores: [ExpenseSuggestionKey: Double] = [:]
        var examples: [ExpenseSuggestionKey: Expense] = [:]

        // `gastos` ya va del más reciente al más antiguo.
        for (index, expense) in gastos.enumerated() {
            let (candidate, candidateTokens) = suggestionKey(for: expense.descripcion)
            guard !candidate.isEmpty else { continue }

            let overlap = queryTokens.intersection(candidateTokens).count
            let matches = candidate == query || candidate.contains(query) || query.contains(candidate) || overlap > 0
            guard matches else { continue }

            var score = max(0.1, 8.0 - (Double(index) * 0.08))
            if candidate == query {
                score += 8
            } else if candidate.contains(query) || query.contains(candidate) {
                score += 5
            } else {
                score += Double(overlap) * 2
            }

            let key = ExpenseSuggestionKey(categoryID: expense.categoriaId, paymentMethodID: expense.metodoPagoId)
            scores[key, default: 0] += score
            if examples[key] == nil {
                examples[key] = expense
            }
        }

        guard let best = scores.max(by: { $0.value < $1.value }) else {
            return keywordSuggestion(for: query)
        }

        guard
            let category = categorias.first(where: { $0.id == best.key.categoryID }),
            let paymentMethod = metodosPago.first(where: { $0.id == best.key.paymentMethodID })
        else {
            return nil
        }

        return ExpenseSmartSuggestion(
            categoria: category,
            metodoPago: paymentMethod,
            sourceDescription: examples[best.key]?.descripcion,
            confidence: min(best.value / 18, 1)
        )
    }

    func loadCatalogsIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedCatalogsOnce else { return }
        await loadCatalogs(force: force)
    }

    func loadCatalogs(force: Bool = false) async {
        guard force || !isLoadingCatalogs else { return }
        guard hasBaseURLConfigured else {
            catalogErrorMessage = "Configura la URL del backend para cargar categorías y métodos."
            return
        }

        isLoadingCatalogs = true
        defer { isLoadingCatalogs = false }

        do {
            async let categoriasResponse: [Categoria] = request(
                [Categoria].self,
                path: "/api/categorias",
                requiresAuth: false
            )
            async let metodosResponse: [ExpensePaymentMethod] = request(
                [ExpensePaymentMethod].self,
                path: "/api/metodos_pago",
                requiresAuth: false
            )

            let (remoteCategorias, remoteMetodos) = try await (categoriasResponse, metodosResponse)
            categorias = remoteCategorias.isEmpty ? Categoria.fallback : remoteCategorias
            metodosPago = remoteMetodos.isEmpty ? ExpensePaymentMethod.fallback : remoteMetodos
            persistCachedValue(categorias, key: Self.cachedCategoriesKey)
            persistCachedValue(metodosPago, key: Self.cachedPaymentMethodsKey)
            catalogErrorMessage = nil
            hasLoadedCatalogsOnce = true
        } catch {
            guard !isCancellationError(error) else { return }
            if isConnectivityError(error), !categorias.isEmpty, !metodosPago.isEmpty {
                catalogErrorMessage = nil
                hasLoadedCatalogsOnce = true
            } else {
                catalogErrorMessage = error.localizedDescription
            }
        }
    }

    func loadExpensesIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedExpensesOnce else { return }
        await loadExpenses(force: force)
    }

    func loadRecurringExpensesIfNeeded(force: Bool = false) async {
        guard force || !hasLoadedRecurringExpensesOnce else { return }
        await loadRecurringExpenses(force: force)
    }

    func loadExpenses(force: Bool = false) async {
        guard force || !isLoadingExpenses else { return }
        guard hasBaseURLConfigured else {
            expensesErrorMessage = "Configura la URL del backend para obtener gastos."
            return
        }
        guard canAccessProtectedEndpoints else {
            expensesErrorMessage = "Inicia sesión para consultar tus gastos."
            return
        }

        await loadCatalogsIfNeeded()
        await syncPendingExpensesIfPossible()

        isLoadingExpenses = true
        defer { isLoadingExpenses = false }

        do {
            let remoteExpenses = try await request(
                [RemoteExpense].self,
                path: "/api/gastos",
                requiresAuth: true
            )

            let pendingDeletionIDs = Set(pendingExpenseDeletions.map(\.id))
            let syncedExpenses = remoteExpenses
                .map { $0.asExpense(categorias: categorias, metodosPago: metodosPago) }
                .filter { !pendingDeletionIDs.contains($0.id) }
            let pendingExpenses = pendingExpenseDrafts.map { $0.asExpense(categorias: categorias, metodosPago: metodosPago) }

            gastos = (syncedExpenses + pendingExpenses)
                .sorted { $0.fecha > $1.fecha }
            persistCachedExpenses()
            expensesErrorMessage = nil
            hasLoadedExpensesOnce = true
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
        } catch {
            guard !isCancellationError(error) else { return }
            if isConnectivityError(error), !gastos.isEmpty {
                expensesErrorMessage = nil
                hasLoadedExpensesOnce = true
            } else {
                expensesErrorMessage = error.localizedDescription
            }
            handlePotentialUnauthorized(error)
        }
    }

    func loadRecurringExpenses(force: Bool = false) async {
        guard force || !isLoadingRecurringExpenses else { return }
        guard hasBaseURLConfigured else {
            recurringExpensesErrorMessage = "Configura la conexión para ver tus cargos programados."
            return
        }
        guard canAccessProtectedEndpoints else {
            recurringExpensesErrorMessage = "Inicia sesión para ver tus cargos recurrentes."
            return
        }

        await loadCatalogsIfNeeded()

        isLoadingRecurringExpenses = true
        defer { isLoadingRecurringExpenses = false }

        do {
            let month = String(AppDateCodec.apiDateString(from: Date()).prefix(7))
            let plan = try await request(
                RecurringPlanResponse.self,
                path: "/api/dashboard/recurring-plan?month=\(month)",
                requiresAuth: true
            )

            recurringExpenses = plan.rules
                .map { $0.asRecurringExpense(categorias: categorias, metodosPago: metodosPago) }
                .sorted { lhs, rhs in
                    if lhs.activo != rhs.activo { return lhs.activo && !rhs.activo }
                    return lhs.descripcion.localizedCaseInsensitiveCompare(rhs.descripcion) == .orderedAscending
                }
            persistCachedRecurringExpenses()
            recurringExpensesErrorMessage = nil
            hasLoadedRecurringExpensesOnce = true
        } catch {
            guard !isCancellationError(error) else { return }
            if isConnectivityError(error), !recurringExpenses.isEmpty {
                recurringExpensesErrorMessage = nil
                hasLoadedRecurringExpensesOnce = true
            } else {
                recurringExpensesErrorMessage = error.localizedDescription
            }
            handlePotentialUnauthorized(error)
        }
    }

    func createExpense(
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        tags: [String]? = nil,
        foreignTax: ForeignTax? = nil
    ) async -> Bool {
        guard hasBaseURLConfigured else {
            saveErrorMessage = "Configura la URL del backend antes de guardar."
            return false
        }
        guard canAccessProtectedEndpoints else {
            saveErrorMessage = "Inicia sesión para crear gastos."
            return false
        }

        let previousExpenses = gastos
        isSavingExpense = true
        defer { isSavingExpense = false }

        let draft = PendingExpenseDraft(
            id: UUID().uuidString,
            localExpenseID: Self.makeLocalExpenseID(),
            descripcion: descripcion,
            monto: monto,
            fecha: fecha,
            categoriaId: categoria.id,
            metodoPagoId: metodoPago.id,
            tags: tags,
            foreignTax: foreignTax
        )

        do {
            let body = try JSONEncoder().encode(draft.payload)
            let response = try await request(
                CreateExpenseResponse.self,
                path: "/api/gastos",
                method: "POST",
                requiresAuth: true,
                body: body
            )

            let gasto = try createdExpense(from: response)

            add(gasto)
            persistCachedExpenses()
            saveErrorMessage = nil
            expensesErrorMessage = nil
            hasLoadedExpensesOnce = true
            showSyncStatus("Gasto guardado")
            if let alert = await budgetCrossingMessage(before: previousExpenses) { showSyncStatus(alert) }
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            if isConnectivityError(error) {
                enqueuePendingExpense(draft)
                saveErrorMessage = "Sin conexión. Guardamos el gasto en este iPhone y se sincronizará cuando vuelva la red."
                expensesErrorMessage = nil
                return true
            }
            saveErrorMessage = error.localizedDescription
            handlePotentialUnauthorized(error)
            return false
        }
    }

    func updateExpense(
        id: Int,
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        isRecurrent: Bool,
        tags: [String]? = nil,
        foreignTax: ForeignTax? = nil
    ) async -> Bool {
        if id < 0 {
            updatePendingExpenseLocally(
                id: id,
                descripcion: descripcion,
                monto: monto,
                fecha: fecha,
                categoria: categoria,
                metodoPago: metodoPago,
                isRecurrent: isRecurrent,
                tags: tags,
                foreignTax: foreignTax
            )
            saveErrorMessage = nil
            expensesErrorMessage = nil
            showSyncStatus("Cambios guardados")
            return true
        }

        guard hasBaseURLConfigured else {
            saveErrorMessage = "Configura la URL del backend antes de guardar."
            return false
        }
        guard canAccessProtectedEndpoints else {
            saveErrorMessage = "Inicia sesión para editar gastos."
            return false
        }

        let previousExpenses = gastos
        isSavingExpense = true
        defer { isSavingExpense = false }

        do {
            let payload = UpdateExpensePayload(
                descripcion: descripcion,
                monto: monto,
                fecha: AppDateCodec.apiDateString(from: fecha),
                categoriaId: categoria.id,
                metodoPagoId: metodoPago.id,
                isRecurrent: isRecurrent,
                tags: tags,
                foreignTax: foreignTax
            )
            let body = try JSONEncoder().encode(payload)
            let response = try await request(
                CreateExpenseResponse.self,
                path: "/api/gastos?id=\(id)",
                method: "PUT",
                requiresAuth: true,
                body: body
            )

            let updatedExpense = response.data?.asExpense(categorias: categorias, metodosPago: metodosPago)
                ?? Expense(
                    id: id,
                    descripcion: descripcion,
                    monto: monto,
                    fecha: fecha,
                    categoriaId: categoria.id,
                    metodoPagoId: metodoPago.id,
                    categoria: categoria,
                    metodoPago: metodoPago,
                    isRecurrent: isRecurrent,
                    tags: tags,
                    foreignTax: foreignTax
                )

            add(updatedExpense)
            persistCachedExpenses()
            saveErrorMessage = nil
            expensesErrorMessage = nil
            showSyncStatus("Cambios guardados")
            if let alert = await budgetCrossingMessage(before: previousExpenses) { showSyncStatus(alert) }
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            handlePotentialUnauthorized(error)
            return false
        }
    }

    func createRecurringExpense(
        descripcion: String,
        monto: Double,
        fechaInicio: Date,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        frecuencia: RecurringFrequency,
        diaMes: Int?,
        diaSemana: Int?,
        fechaFin: Date? = nil,
        annualMonth: Int? = nil,
        foreignTax: ForeignTax? = nil
    ) async -> Bool {
        guard hasBaseURLConfigured else {
            saveErrorMessage = "Configura la URL del backend antes de guardar."
            return false
        }
        guard canAccessProtectedEndpoints else {
            saveErrorMessage = "Inicia sesión para crear gastos recurrentes."
            return false
        }

        isSavingExpense = true
        defer { isSavingExpense = false }

        do {
            let payload = CreateRecurringExpensePayload(
                descripcion: descripcion,
                monto: monto,
                categoriaId: categoria.id,
                metodoPagoId: metodoPago.id,
                annualMonth: frecuencia == .anual ? annualMonth : nil,
                frecuencia: frecuencia.rawValue,
                diaSemana: frecuencia == .semanal ? diaSemana : nil,
                diaMes: frecuencia != .semanal ? diaMes : nil,
                fechaInicio: AppDateCodec.apiDateString(from: fechaInicio),
                fechaFin: fechaFin.map { AppDateCodec.apiDateString(from: $0) },
                foreignTax: foreignTax,
                activo: true
            )

            let body = try JSONEncoder().encode(payload)
            _ = try await rawRequest(
                path: "/api/gastos-recurrentes",
                method: "POST",
                body: body,
                additionalHeaders: ["Content-Type": "application/json"],
                requiresAuth: true,
                acceptedStatusCodes: [200, 201]
            )

            saveErrorMessage = nil
            showSyncStatus("Cargo recurrente guardado")
            await loadExpenses(force: true)
            await loadRecurringExpenses(force: true)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            handlePotentialUnauthorized(error)
            return false
        }
    }

    func updateRecurringExpense(
        id: Int,
        descripcion: String,
        monto: Double,
        fechaInicio: Date,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        frecuencia: RecurringFrequency,
        diaMes: Int?,
        diaSemana: Int?,
        activo: Bool,
        fechaFin: Date? = nil,
        annualMonth: Int? = nil,
        foreignTax: ForeignTax? = nil
    ) async -> Bool {
        guard hasBaseURLConfigured else {
            saveErrorMessage = "Configura la conexión antes de guardar cambios."
            return false
        }
        guard canAccessProtectedEndpoints else {
            saveErrorMessage = "Inicia sesión para editar cargos recurrentes."
            return false
        }

        isSavingExpense = true
        defer { isSavingExpense = false }

        do {
            let payload = CreateRecurringExpensePayload(
                descripcion: descripcion,
                monto: monto,
                categoriaId: categoria.id,
                metodoPagoId: metodoPago.id,
                annualMonth: frecuencia == .anual ? annualMonth : nil,
                frecuencia: frecuencia.rawValue,
                diaSemana: frecuencia == .semanal ? diaSemana : nil,
                diaMes: frecuencia != .semanal ? diaMes : nil,
                fechaInicio: AppDateCodec.apiDateString(from: fechaInicio),
                fechaFin: fechaFin.map { AppDateCodec.apiDateString(from: $0) },
                foreignTax: foreignTax,
                activo: activo
            )

            let body = try JSONEncoder().encode(payload)
            _ = try await rawRequest(
                path: "/api/gastos-recurrentes/\(id)",
                method: "PUT",
                body: body,
                additionalHeaders: ["Content-Type": "application/json"],
                requiresAuth: true
            )

            saveErrorMessage = nil
            showSyncStatus("Cargo recurrente actualizado")
            await loadRecurringExpenses(force: true)
            await loadExpenses(force: true)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            saveErrorMessage = error.localizedDescription
            handlePotentialUnauthorized(error)
            return false
        }
    }

    func deleteExpense(id: Int) async -> Bool {
        guard let expense = gastos.first(where: { $0.id == id }) else { return false }
        guard !deletingExpenseIDs.contains(id) else { return false }

        if id < 0 {
            removeExpenseLocally(id: id)
            removePendingDraft(localExpenseID: id)
            expensesErrorMessage = nil
            showSyncStatus("Gasto eliminado")
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
            return true
        }

        guard hasBaseURLConfigured else {
            expensesErrorMessage = "Configura la URL del backend antes de eliminar."
            return false
        }
        guard canAccessProtectedEndpoints else {
            expensesErrorMessage = "Inicia sesión para eliminar gastos."
            return false
        }

        removeExpenseLocally(id: id)

        do {
            try await deleteRemoteExpense(id: id)
            expensesErrorMessage = nil
            await loadExpenses(force: true)
            if gastos.contains(where: { $0.id == id }) {
                expensesErrorMessage = "La API respondio OK, pero el gasto sigue existiendo. Revisa que el id pertenezca al usuario autenticado."
                return false
            }
            showSyncStatus("Gasto eliminado")
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            if isConnectivityError(error) {
                enqueuePendingDeletion(id: id, expense: expense)
                expensesErrorMessage = nil
                showSyncStatus("Gasto eliminado. Se sincronizará cuando vuelva la conexión.")
                return true
            }
            restoreExpense(expense)
            expensesErrorMessage = "No se pudo eliminar: \(error.localizedDescription)"
            handlePotentialUnauthorized(error)
            return false
        }
    }

    func deleteRecurringExpense(id: Int) async -> Bool {
        guard hasBaseURLConfigured else {
            recurringExpensesErrorMessage = "Configura la conexión antes de eliminar."
            return false
        }
        guard canAccessProtectedEndpoints else {
            recurringExpensesErrorMessage = "Inicia sesión para eliminar cargos recurrentes."
            return false
        }
        guard !deletingRecurringExpenseIDs.contains(id) else {
            return false
        }

        deletingRecurringExpenseIDs.insert(id)
        defer { deletingRecurringExpenseIDs.remove(id) }

        do {
            _ = try await rawRequest(
                path: "/api/gastos-recurrentes/\(id)",
                method: "DELETE",
                requiresAuth: true
            )
            recurringExpenses.removeAll { $0.id == id }
            persistCachedRecurringExpenses()
            recurringExpensesErrorMessage = nil
            return true
        } catch {
            guard !isCancellationError(error) else { return false }
            recurringExpensesErrorMessage = error.localizedDescription
            handlePotentialUnauthorized(error)
            return false
        }
    }

    private func persist(_ session: PersistedAuthSession) {
        let activeSession = session.withActivity(session.lastActivityAt ?? Self.nowTimestamp)
        accessToken = activeSession.accessToken
        refreshToken = activeSession.refreshToken
        tokenType = activeSession.tokenType
        expiresAt = activeSession.expiresAt
        currentUser = activeSession.user
        AuthSessionStore.save(activeSession, for: Self.authSessionKey)
    }

    private func touchSessionActivity() {
        guard let currentUser, !normalizedAccessToken.isEmpty else { return }
        let session = PersistedAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: max((expiresAt ?? Self.nowTimestamp) - Self.nowTimestamp, 0),
            expiresAt: expiresAt ?? Self.nowTimestamp,
            tokenType: tokenType,
            user: currentUser,
            lastActivityAt: Self.nowTimestamp
        )
        AuthSessionStore.save(session, for: Self.authSessionKey)
    }

    private func isSessionExpiredByInactivity(_ session: PersistedAuthSession) -> Bool {
        guard let lastActivityAt = session.lastActivityAt else { return false }
        return TimeInterval(Self.nowTimestamp - lastActivityAt) >= Self.sessionInactivityLimit
    }

    private func clearExpiredInactiveSession() {
        clearAuthSession()
        authErrorMessage = "Tu sesión expiró por inactividad. Inicia sesión nuevamente."
    }

    private func clearPersistedSession() {
        clearAuthSession()
        gastos = []
        recurringExpenses = []
        pendingExpenseDrafts = []
        pendingExpenseDeletions = []
        // Por la misma cola que las escrituras de caché: así ninguna que
        // estuviera pendiente vuelve a guardar los gastos tras cerrar sesión.
        let cacheKeys = [Self.cachedExpensesKey, Self.cachedRecurringExpensesKey]
        Self.cacheQueue.async {
            cacheKeys.forEach(UserDefaults.standard.removeObject(forKey:))
        }
        UserDefaults.standard.removeObject(forKey: Self.pendingExpensesKey)
        UserDefaults.standard.removeObject(forKey: Self.pendingExpenseDeletionsKey)
        WidgetSummaryPublisher.clear()
    }

    private func clearAuthSession() {
        currentUser = nil
        accessToken = ""
        refreshToken = ""
        tokenType = "bearer"
        expiresAt = nil
        gastos = []
        recurringExpenses = []
        hasLoadedExpensesOnce = false
        hasLoadedRecurringExpensesOnce = false
        expensesErrorMessage = nil
        recurringExpensesErrorMessage = nil
        saveErrorMessage = nil
        AuthSessionStore.delete(for: Self.authSessionKey)
    }

    private var normalizedBaseURL: String {
        var value = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    private var normalizedAccessToken: String {
        accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var authorizationScheme: String {
        let normalized = tokenType.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Bearer" : normalized.capitalized
    }

    private var isAccessTokenExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= (Self.nowTimestamp + 30)
    }

    private func refreshAccessTokenIfNeeded() async throws {
        guard isAccessTokenExpired || normalizedAccessToken.isEmpty else { return }
        try await refreshSession(force: true)
    }

    private func refreshSession(force: Bool = false) async throws {
        guard force || isAccessTokenExpired || normalizedAccessToken.isEmpty else { return }
        guard !normalizedAccessToken.isEmpty else {
            throw ExpenseStoreError.missingAccessToken
        }

        let response = try await refreshMobileSession()

        let now = Self.nowTimestamp
        let resolvedExpiresIn = response.expiresIn ?? max((response.expiresAt ?? now) - now, 0)
        let resolvedExpiresAt = response.expiresAt ?? now + resolvedExpiresIn
        guard let resolvedUser = response.user ?? currentUser else {
            throw ExpenseStoreError.invalidResponse
        }

        persist(
            PersistedAuthSession(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken ?? refreshToken,
                expiresIn: resolvedExpiresIn,
                expiresAt: resolvedExpiresAt,
                tokenType: response.tokenType ?? tokenType,
                user: resolvedUser,
                lastActivityAt: now
            )
        )
        authErrorMessage = nil
    }

    private func refreshMobileSession() async throws -> MobileRefreshResponse {
        let url = try makeURL(path: "/api/mobile/refresh")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("\(authorizationScheme) \(normalizedAccessToken)", forHTTPHeaderField: "Authorization")
        request.markAsJSONIfMutating()

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExpenseStoreError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw mapServerError(data: data, statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(MobileRefreshResponse.self, from: data)
        } catch {
            throw ExpenseStoreError.decoding(error)
        }
    }

    func request<T: Decodable>(
        _ type: T.Type,
        path: String,
        method: String = "GET",
        requiresAuth: Bool,
        body: Data? = nil
    ) async throws -> T {
        let (data, _) = try await rawRequest(
            path: path,
            method: method,
            body: body,
            additionalHeaders: body == nil ? [:] : ["Content-Type": "application/json"],
            requiresAuth: requiresAuth
        )

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ExpenseStoreError.decoding(error)
        }
    }

    private func rawRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        additionalHeaders: [String: String] = [:],
        requiresAuth: Bool = false,
        acceptedStatusCodes: Set<Int> = Set(200...299)
    ) async throws -> (Data, HTTPURLResponse) {
        let url = try makeURL(path: path)
        if requiresAuth {
            touchSessionActivity()
            try await refreshAccessTokenIfNeeded()
        }

        func makeRequest() throws -> URLRequest {
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            for (key, value) in additionalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
            request.markAsJSONIfMutating()

            if requiresAuth {
                guard !normalizedAccessToken.isEmpty else {
                    throw ExpenseStoreError.missingAccessToken
                }
                request.setValue("\(authorizationScheme) \(normalizedAccessToken)", forHTTPHeaderField: "Authorization")
            }

            return request
        }

        var request = try makeRequest()
        var (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExpenseStoreError.invalidResponse
        }

        if httpResponse.statusCode == 401, requiresAuth, !normalizedAccessToken.isEmpty {
            try await refreshSession(force: true)
            request = try makeRequest()
            (data, response) = try await URLSession.shared.data(for: request)
            guard let retryResponse = response as? HTTPURLResponse else {
                throw ExpenseStoreError.invalidResponse
            }
            guard acceptedStatusCodes.contains(retryResponse.statusCode) else {
                throw mapServerError(data: data, statusCode: retryResponse.statusCode)
            }
            return (data, retryResponse)
        }

        guard acceptedStatusCodes.contains(httpResponse.statusCode) else {
            throw mapServerError(data: data, statusCode: httpResponse.statusCode)
        }

        return (data, httpResponse)
    }

    private func deleteRemoteExpense(id: Int) async throws {
        _ = try await rawRequest(
            path: "/api/gastos?id=\(id)",
            method: "DELETE",
            requiresAuth: true
        )
    }

    private func makeURL(path: String) throws -> URL {
        guard !normalizedBaseURL.isEmpty else {
            throw ExpenseStoreError.missingBaseURL
        }
        guard let url = URL(string: normalizedBaseURL + path) else {
            throw ExpenseStoreError.invalidBaseURL
        }
        return url
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                await self?.syncPendingExpensesIfPossible()
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }

    func syncPendingExpensesIfPossible() async {
        guard !isSyncingPendingExpenses, hasPendingExpenseChanges else { return }
        guard hasBaseURLConfigured, canAccessProtectedEndpoints else { return }

        isSyncingPendingExpenses = true
        defer { isSyncingPendingExpenses = false }

        let hadChanges = hasPendingExpenseChanges
        await syncPendingExpenseDrafts()
        await syncPendingExpenseDeletions()

        if hadChanges && !hasPendingExpenseChanges {
            saveErrorMessage = nil
            expensesErrorMessage = nil
            showSyncStatus("Datos sincronizados")
            await LocalNotificationManager.prepareWeeklySummary(expenses: gastos)
        }
    }

    private func syncPendingExpenseDrafts() async {
        var remaining: [PendingExpenseDraft] = []
        for (index, draft) in pendingExpenseDrafts.enumerated() {
            do {
                let body = try JSONEncoder().encode(draft.payload)
                let response = try await request(
                    CreateExpenseResponse.self,
                    path: "/api/gastos",
                    method: "POST",
                    requiresAuth: true,
                    body: body
                )
                let syncedExpense = try createdExpense(from: response)

                gastos.removeAll { $0.id == draft.localExpenseID }
                add(syncedExpense)
                persistCachedExpenses()
            } catch {
                guard !isCancellationError(error) else { return }
                remaining.append(draft)
                if isConnectivityError(error) {
                    continue
                }
                if case ExpenseStoreError.unauthorized = error {
                    handlePotentialUnauthorized(error)
                }
                if index + 1 < pendingExpenseDrafts.count {
                    remaining.append(contentsOf: pendingExpenseDrafts[(index + 1)...])
                }
                break
            }
        }
        pendingExpenseDrafts = remaining
        persistPendingExpenseDrafts()
    }

    private func syncPendingExpenseDeletions() async {
        var remaining: [PendingExpenseDeletion] = []
        for (index, deletion) in pendingExpenseDeletions.enumerated() {
            do {
                try await deleteRemoteExpense(id: deletion.id)
            } catch {
                guard !isCancellationError(error) else { return }
                if isConnectivityError(error) {
                    remaining.append(deletion)
                    continue
                }
                restoreExpense(deletion.expense)
                expensesErrorMessage = "No se pudo sincronizar una eliminación."
                handlePotentialUnauthorized(error)
                if index + 1 < pendingExpenseDeletions.count {
                    remaining.append(contentsOf: pendingExpenseDeletions[(index + 1)...])
                }
                break
            }
        }
        pendingExpenseDeletions = remaining
        persistPendingExpenseDeletions()
    }

    private func enqueuePendingExpense(_ draft: PendingExpenseDraft) {
        pendingExpenseDrafts.append(draft)
        persistPendingExpenseDrafts()
        add(draft.asExpense(categorias: categorias, metodosPago: metodosPago))
        persistCachedExpenses()
        hasLoadedExpensesOnce = true
    }

    private func createdExpense(from response: CreateExpenseResponse) throws -> Expense {
        guard let remoteExpense = response.data else {
            throw ExpenseStoreError.invalidResponse
        }
        return remoteExpense.asExpense(categorias: categorias, metodosPago: metodosPago)
    }

    private var hasPendingExpenseChanges: Bool {
        !pendingExpenseDrafts.isEmpty || !pendingExpenseDeletions.isEmpty
    }

    private func removeExpenseLocally(id: Int) {
        deletingExpenseIDs.insert(id)
        gastos.removeAll { $0.id == id }
        persistCachedExpenses()
        hasLoadedExpensesOnce = true
        deletingExpenseIDs.remove(id)
    }

    private func restoreExpense(_ expense: Expense) {
        add(expense)
        persistCachedExpenses()
    }

    private func removePendingDraft(localExpenseID: Int) {
        pendingExpenseDrafts.removeAll { $0.localExpenseID == localExpenseID }
        persistPendingExpenseDrafts()
    }

    private func updatePendingExpenseLocally(
        id: Int,
        descripcion: String,
        monto: Double,
        fecha: Date,
        categoria: Categoria,
        metodoPago: ExpensePaymentMethod,
        isRecurrent: Bool,
        tags: [String]? = nil,
        foreignTax: ForeignTax? = nil
    ) {
        if let index = pendingExpenseDrafts.firstIndex(where: { $0.localExpenseID == id }) {
            pendingExpenseDrafts[index] = pendingExpenseDrafts[index].updated(
                descripcion: descripcion,
                monto: monto,
                fecha: fecha,
                categoriaId: categoria.id,
                metodoPagoId: metodoPago.id,
                tags: tags,
                foreignTax: foreignTax
            )
            persistPendingExpenseDrafts()
        }

        add(
            Expense(
                id: id,
                descripcion: descripcion,
                monto: monto,
                fecha: fecha,
                categoriaId: categoria.id,
                metodoPagoId: metodoPago.id,
                categoria: categoria,
                metodoPago: metodoPago,
                isRecurrent: isRecurrent,
                tags: tags,
                foreignTax: foreignTax
            )
        )
        persistCachedExpenses()
        hasLoadedExpensesOnce = true
    }

    private func enqueuePendingDeletion(id: Int, expense: Expense) {
        pendingExpenseDeletions.removeAll { $0.id == id }
        pendingExpenseDeletions.append(PendingExpenseDeletion(id: id, expense: expense))
        persistPendingExpenseDeletions()
        hasLoadedExpensesOnce = true
    }

    private func showSyncStatus(_ message: String) {
        syncStatusMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if syncStatusMessage == message {
                syncStatusMessage = nil
            }
        }
    }

    private func persistPendingExpenseDrafts() {
        guard let data = try? JSONEncoder().encode(pendingExpenseDrafts) else { return }
        UserDefaults.standard.set(data, forKey: Self.pendingExpensesKey)
    }

    private func persistPendingExpenseDeletions() {
        guard let data = try? JSONEncoder().encode(pendingExpenseDeletions) else { return }
        UserDefaults.standard.set(data, forKey: Self.pendingExpenseDeletionsKey)
    }

    private func persistCachedExpenses() {
        let syncedExpenses = gastos.filter { $0.id >= 0 }.map(Self.normalizedExpense)
        persistCachedValue(syncedExpenses, key: Self.cachedExpensesKey)
    }

    private func persistCachedRecurringExpenses() {
        persistCachedValue(recurringExpenses, key: Self.cachedRecurringExpensesKey)
    }

    /// Cola serie para la caché: codificar todos los gastos a JSON en el hilo
    /// principal frenaba la interfaz justo después de guardar. Al ser serie,
    /// las escrituras llegan en orden y la última siempre gana.
    private static let cacheQueue = DispatchQueue(label: "zenlor.expenses.cache", qos: .utility)

    private func persistCachedValue<T: Encodable>(_ value: T, key: String) {
        Self.cacheQueue.async {
            guard let data = try? JSONEncoder().encode(value) else { return }
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private static func loadPendingExpenseDrafts() -> [PendingExpenseDraft] {
        guard
            let data = UserDefaults.standard.data(forKey: pendingExpensesKey),
            let drafts = try? JSONDecoder().decode([PendingExpenseDraft].self, from: data)
        else {
            return []
        }
        return drafts
    }

    private static func loadPendingExpenseDeletions() -> [PendingExpenseDeletion] {
        guard
            let data = UserDefaults.standard.data(forKey: pendingExpenseDeletionsKey),
            let deletions = try? JSONDecoder().decode([PendingExpenseDeletion].self, from: data)
        else {
            return []
        }
        return deletions
    }

    private static func loadCachedValue<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func normalizedCachedExpenses(_ expenses: [Expense]) -> [Expense] {
        expenses.map { expense in
            var normalized = expense
            normalized.fecha = AppDateCodec.repairedCachedDateOnly(expense.fecha)
            return normalized
        }
    }

    private static func normalizedExpense(_ expense: Expense) -> Expense {
        var normalized = expense
        normalized.fecha = AppDateCodec.normalizedDateOnly(expense.fecha)
        return normalized
    }

    private static func makeLocalExpenseID() -> Int {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return -(timestamp + Int.random(in: 0...999))
    }

    private func mapServerError(data: Data, statusCode: Int) -> ExpenseStoreError {
        if let payload = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            if statusCode == 401 {
                return .unauthorized(payload.error)
            }
            return .server("\(payload.error) (status \(statusCode))")
        }

        if statusCode == 401 {
            return .unauthorized("Sesión inválida o expirada.")
        }

        return .server("El backend respondio con status \(statusCode).")
    }

    private func handlePotentialUnauthorized(_ error: Error) {
        guard case ExpenseStoreError.unauthorized = error else { return }
        authErrorMessage = "Tu sesión expiró. Inicia sesión nuevamente."
        clearAuthSession()
        isAuthResolved = true
    }

    private func keywordSuggestion(for query: String) -> ExpenseSmartSuggestion? {
        let transportKeywords = ["parqueo", "parking", "taxi", "uber", "gasolina", "peaje", "bus"]
        guard transportKeywords.contains(where: { query.contains($0) }) else { return nil }
        guard let category = categorias.first(where: { $0.nombre.normalizedLookupKey.contains("transporte") }) else { return nil }
        let paymentMethod = metodosPago.first(where: { $0.nombre.normalizedLookupKey.contains("transfer") }) ?? metodosPago.first ?? .placeholder

        return ExpenseSmartSuggestion(
            categoria: category,
            metodoPago: paymentMethod,
            sourceDescription: nil,
            confidence: 0.45
        )
    }

    /// Descripciones ya normalizadas para las sugerencias. Se piden a cada
    /// tecla para todos los gastos y las descripciones se repiten mucho.
    @ObservationIgnored private var suggestionKeys: [String: (key: String, tokens: Set<String>)] = [:]

    private func suggestionKey(for description: String) -> (key: String, tokens: Set<String>) {
        if let cached = suggestionKeys[description] { return cached }
        let key = Self.normalizedSuggestionKey(description)
        let entry = (key, Set(key.split(separator: " ").map(String.init)))
        if suggestionKeys.count > 5_000 { suggestionKeys.removeAll(keepingCapacity: true) }
        suggestionKeys[description] = entry
        return entry
    }

    private static func normalizedSuggestionKey(_ value: String) -> String {
        value.normalizedLookupKey
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

struct ExpenseSmartSuggestion: Equatable {
    let categoria: Categoria
    let metodoPago: ExpensePaymentMethod
    let sourceDescription: String?
    let confidence: Double
}
