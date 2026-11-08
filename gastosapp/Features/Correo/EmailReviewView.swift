import SwiftUI

/// Bandeja del correo según el canvas «Correo»: cada movimiento es una tarjeta
/// que se resuelve ahí mismo (Registrar, Es el mismo, Descontar) y, en Nuevos,
/// «Por registrar» registra de una vez los que ya tienen forma de pago.
struct EmailReviewView: View {
    /// Encabezado que se desplaza con el contenido (título de Gastos).
    private let header: AnyView?

    init(header: AnyView? = nil) {
        self.header = header
    }

    @Environment(ExpenseStore.self) private var session
    @State private var review = EmailReviewStore()
    /// Ajustes de cada movimiento nuevo, por id, hasta registrarlo.
    @State private var drafts: [Int: EmailDraft] = [:]
    /// Coincidencia elegida en duplicados y devoluciones con varias.
    @State private var candidates: [Int: Int] = [:]
    /// Desplegable abierto; sólo uno a la vez en toda la bandeja.
    @State private var openPanel: (id: Int, panel: EmailCardPanel)?
    @State private var isSearching = false
    @State private var toast: String?
    /// El toast avisa de algo que no se hizo, no de un éxito.
    @State private var toastIsWarning = false
    private var selectedTab: EmailReviewTab { EmailReviewTab(rawValue: review.tab) ?? .nuevos }
    private var requestKey: String { "\(review.tab)|\(review.page)|\(review.query)" }
    private var rows: [EmailMovement] { review.result?.pendientes ?? [] }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // VStack y no LazyVStack: son pocas piezas y las tarjetas cambian
            // mucho de alto al desplegarse. Con Lazy, SwiftUI estimaba esos
            // altos al desplazar y el contenido daba saltos.
            VStack(alignment: .leading, spacing: 16) {
                if let header { header.padding(.bottom, 6) }
                EmailInboxHeader(counts: review.counts, isSearching: $isSearching,
                    isSyncing: review.isSyncing, canSync: review.isEnabled == true && !review.isWorking,
                    onSync: { Task { await review.sync(using: session) } })
                if let error = review.error { errorBanner(title: "No se pudo completar", message: error, retry: nil) }
                if showsSummary { summary.transition(AppMotion.reveal) }
                EmailInboxFilters(tab: $review.tab, query: $review.query, counts: review.counts,
                    isWorking: review.isWorking, showsSearch: isSearching)
                inbox
            }
            .padding(.horizontal, 20)
            .padding(.top, 4).padding(.bottom, AppScreenMetrics.contentBottomPadding)
            .animation(AppMotion.standard, value: rows.map(\.id))
            .animation(AppMotion.standard, value: showsSummary)
        }
        // En el propio ScrollView y no en el ScrollViewReader que lo envuelve:
        // el hueco de la barra y el seguimiento del scroll tienen que llegarle
        // directamente.
        .tracksScrollChrome().floatingTabBarInset()
        .scrollDismissesKeyboard(.interactively)
        // Al recargar la lista se queda en su sitio: vaciarla encogía la
        // pantalla y la hacía subir y bajar.
        .refreshable { await review.load(using: session, keepsRows: true) }
        .onChange(of: openPanel?.id) { _, id in
            guard let id else { return }
            // Desplaza lo justo para que el desplegable entre en pantalla; si ya
            // se ve, no mueve nada.
            withAnimation(AppMotion.expand) { proxy.scrollTo(id, anchor: nil) }
        }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .overlay(alignment: .bottom) {
            if let toast {
                TransientStatusToast(text: toast, tint: toastIsWarning ? AppTheme.warning : AppTheme.accent,
                                     icon: toastIsWarning ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .padding(.horizontal, AppScreenMetrics.horizontalPadding)
                    .padding(.bottom, AppScreenMetrics.toastBottomPadding)
                    .transition(AppMotion.toast)
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isSearching) { _, open in if !open { review.query = "" } }
        .onChange(of: review.tab) { review.page = 1; openPanel = nil }
        .onChange(of: review.query) { review.page = 1 }
        .onChange(of: review.message) { _, message in
            guard let message else { return }
            review.message = nil
            show(message)
        }
        .task(id: requestKey) {
            if !review.query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await review.load(using: session)
        }
        .task(id: toast) {
            guard toast != nil else { return }
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            withAnimation(AppMotion.fade) { toast = nil }
        }
    }

    // MARK: - Resumen

    private var newRows: [EmailMovement] { selectedTab == .nuevos ? rows : [] }
    private var showsSummary: Bool {
        selectedTab == .nuevos && review.query.isEmpty && review.loadError == nil && review.result?.enabled == true && !newRows.isEmpty
    }

    private var summary: some View {
        let ready = newRows.filter { draft(for: $0).isReady(for: $0) }
        return EmailPendingSummary(
            total: newRows.reduce(0) { $0 + draft(for: $1).total(for: $1) },
            count: newRows.count,
            missingPayment: newRows.filter { draft(for: $0).needsPayment }.count,
            isWorking: review.isWorking && !review.isSavingAlias
        ) {
            if ready.isEmpty {
                if let first = newRows.first(where: { !draft(for: $0).isReady(for: $0) }) {
                    withAnimation(AppMotion.expand) { openPanel = (first.id, draft(for: first).needsPayment ? .payment : .more) }
                    show("Elige cómo pagaste")
                }
            } else {
                Task { await register(ready) }
            }
        }
    }

    // MARK: - Bandeja

    @ViewBuilder private var inbox: some View {
        if let error = review.loadError {
            errorBanner(title: "No pudimos leer tu correo", message: error) { Task { await review.load(using: session) } }
        } else if review.result == nil {
            ListRowsSkeleton(label: "Cargando movimientos")
                .transition(.opacity)
        } else if let result = review.result {
            if !result.enabled {
                emptyCard(title: "Correo no disponible", message: "El servidor no habilitó la importación para esta cuenta.", icon: "envelope.badge", tint: AppTheme.warning)
            } else if result.pendientes.isEmpty {
                if review.query.isEmpty {
                    emptyCard(title: selectedTab.emptyTitle, message: selectedTab.emptyMessage,
                              icon: selectedTab == .nuevos ? "checkmark" : "tray", tint: selectedTab == .nuevos ? AppTheme.accent : AppTheme.tertiaryText)
                } else {
                    emptyCard(title: "Sin coincidencias", message: "Prueba con otra descripción, fecha o banco.", icon: "magnifyingglass", tint: AppTheme.tertiaryText)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(result.pendientes) { row in
                        card(for: row)
                            .disabled(review.isWorking)
                            .id(row.id)
                            .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .trailing).combined(with: .opacity)))
                    }
                }
                if (result.pages ?? 1) > 1 { pagination(result).padding(.top, 8) }
            }
        }
    }

    @ViewBuilder private func card(for row: EmailMovement) -> some View {
        if row.tipo == "ingreso" {
            EmailRefundCard(row: row, candidateID: candidateBinding(row), onIgnore: { discard(row) }) { candidate in
                Task { await link(row, to: candidate, success: "Descontado de \(candidate.gasto.descripcion)") }
            }
        } else if selectedTab == .duplicados && !row.coincidencias.isEmpty {
            EmailDuplicateCard(row: row, candidateID: candidateBinding(row), onOther: { markAsOther(row) }) { candidate in
                Task { await link(row, to: candidate, success: "Vinculado, sin duplicar") }
            }
        } else {
            EmailNewMovementCard(row: row, draft: draftBinding(row), panel: panelBinding(row),
                categories: session.categorias, methods: session.metodosPago,
                isSavingAlias: review.isSavingAlias,
                onRememberName: { name in Task { await rememberName(name, for: row) } },
                onRegister: { Task { await register([row]) } },
                onDiscard: { discard(row) })
        }
    }

    private func discard(_ row: EmailMovement) {
        Task {
            // Si falla (o hay otra acción en curso) se conservan los ajustes.
            let wasBusy = review.isWorking
            guard await review.apply(["descartar": [row.id]], using: session,
                                     success: row.tipo == "ingreso" ? "Devolución ignorada" : "Descartado",
                                     reloadsExpenses: false) else {
                // Un error real ya sale en el aviso de arriba; si no se hizo por
                // estar ocupada, antes no pasaba nada y no se decía nada.
                if wasBusy { show("Hay otra acción en curso. Inténtalo en un momento", warning: true) }
                return
            }
            drafts[row.id] = nil
        }
    }

    // MARK: - Estado por tarjeta

    private func draft(for row: EmailMovement) -> EmailDraft {
        drafts[row.id] ?? EmailDraft(row: row, categories: session.categorias)
    }

    private func draftBinding(_ row: EmailMovement) -> Binding<EmailDraft> {
        Binding(get: { draft(for: row) }, set: { drafts[row.id] = $0 })
    }

    private func panelBinding(_ row: EmailMovement) -> Binding<EmailCardPanel?> {
        Binding(get: { openPanel?.id == row.id ? openPanel?.panel : nil },
                set: { value in withAnimation(AppMotion.expand) { openPanel = value.map { (row.id, $0) } } })
    }

    private func candidateBinding(_ row: EmailMovement) -> Binding<Int?> {
        Binding(get: { candidates[row.id] }, set: { candidates[row.id] = $0 })
    }

    // MARK: - Acciones

    private func register(_ items: [EmailMovement]) async {
        let ready = items.filter { draft(for: $0).isReady(for: $0) }
        guard !ready.isEmpty else { return }
        let chosen = ready.map { ($0, draft(for: $0)) }
        let knownIDs = Set(session.gastos.map(\.id))
        let success = ready.count == 1 ? "\(chosen[0].1.name.trimmingCharacters(in: .whitespacesAndNewlines)) registrado" : "\(ready.count) gastos registrados"
        guard await review.apply(["aceptar": chosen.map { $0.1.payload(for: $0.0) }], using: session, success: success) else { return }
        openPanel = nil
        for row in ready { drafts[row.id] = nil }
        await fixPaymentMethods(chosen, excluding: knownIDs)
    }

    /// Si el servidor no tomó la forma de pago elegida al aceptar, se corrige
    /// en el gasto recién creado que coincide en nombre y monto.
    private func fixPaymentMethods(_ chosen: [(EmailMovement, EmailDraft)], excluding knownIDs: Set<Int>) async {
        for (row, draft) in chosen {
            guard let paymentID = draft.paymentID, let method = session.metodosPago.first(where: { $0.id == paymentID }) else { continue }
            let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let amounts = [draft.base(for: row), draft.total(for: row)]
            guard let created = session.gastos.first(where: { expense in
                !knownIDs.contains(expense.id) && expense.descripcion == name && amounts.contains { abs(expense.monto - $0) < 0.005 }
            }), created.metodoPagoId != paymentID else { continue }
            _ = await session.updateExpense(id: created.id, descripcion: created.descripcion, monto: created.monto, fecha: created.fecha,
                categoria: created.categoria, metodoPago: method, isRecurrent: created.isRecurrent, tags: created.tags, foreignTax: created.foreignTax)
        }
    }

    private func link(_ row: EmailMovement, to candidate: EmailCandidate, success: String) async {
        if await review.apply(["vincular": [["id": row.id, "gasto_id": candidate.id]]], using: session, success: success) {
            candidates[row.id] = nil
        }
    }

    /// «Es otro gasto»: deja de tratarse como duplicado y pasa a Nuevos.
    private func markAsOther(_ row: EmailMovement) {
        review.otherIDs.insert(row.id)
        withAnimation(AppMotion.standard) { review.tab = EmailReviewTab.nuevos.rawValue }
        show("Movido a Nuevos")
    }

    private func rememberName(_ name: String, for row: EmailMovement) async {
        guard await review.saveAlias(for: row, alias: name, using: session) else { return }
        // El alias guardado pasa a ser la descripción del movimiento.
        if !name.isEmpty { drafts[row.id]?.name = name }
        review.message = nil
        show(name.isEmpty ? "Nombre olvidado" : "Lo usaremos en próximas transferencias")
    }

    private func show(_ message: String, warning: Bool = false) {
        toastIsWarning = warning
        withAnimation(AppMotion.fade) { toast = message }
    }

    // MARK: - Piezas

    private func errorBanner(title: String, message: String, retry: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(AppTheme.negative)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let retry {
                Button("Reintentar", action: retry)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.backgroundTop)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Capsule().fill(AppTheme.primaryText))
                    .buttonStyle(.pressable(scale: 0.96))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.negative.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.negative.opacity(0.25), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }

    private func emptyCard(title: String, message: String, icon: String, tint: Color) -> some View {
        EmailInboxState(title: title, message: message, icon: icon, tint: tint)
            .background(AppTheme.cardBackground())
            .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .transition(.opacity)
    }

    private func pagination(_ result: EmailReviewPage) -> some View {
        HStack {
            AppCircleButton(icon: "chevron.left", label: "Página anterior") { review.page -= 1 }
                .disabled(review.page <= 1 || review.isWorking)
                .opacity(review.page <= 1 ? 0.3 : 1)
            Spacer()
            Text("Página \(review.page) de \(result.pages ?? 1)")
                .font(.caption.weight(.semibold)).foregroundStyle(AppTheme.secondaryText)
            Spacer()
            AppCircleButton(icon: "chevron.right", label: "Página siguiente") { review.page += 1 }
                .disabled(review.page >= (result.pages ?? 1) || review.isWorking)
                .opacity(review.page >= (result.pages ?? 1) ? 0.3 : 1)
        }
    }
}
