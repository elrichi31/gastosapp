import SwiftUI

struct EmailReviewView: View {
    /// Encabezado que se desplaza con el contenido (título de Gastos).
    private let header: AnyView?

    init(header: AnyView? = nil) {
        self.header = header
    }

    @Environment(ExpenseStore.self) private var session
    @State private var review = EmailReviewStore()
    /// Movimiento con la revisión desplegada; sólo uno a la vez.
    @State private var expandedID: Int?
    @State private var discarded: EmailMovement?
    @State private var isSearching = false
    private var selectedTab: EmailReviewTab { EmailReviewTab(rawValue: review.tab) ?? .nuevos }
    private var requestKey: String { "\(review.tab)|\(review.page)|\(review.query)" }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            // VStack y no LazyVStack: son pocas piezas y la tarjeta de la bandeja
            // cambia mucho de alto al desplegar una revisión. Con Lazy, SwiftUI
            // estimaba esos altos al desplazar y el contenido daba saltos.
            VStack(alignment: .leading, spacing: 16) {
                if let header { header.padding(.bottom, 6) }
                EmailInboxHeader(counts: review.counts, isSearching: $isSearching,
                    isSyncing: review.isSyncing, canSync: review.isEnabled == true && !review.isWorking,
                    onSync: { Task { await review.sync(using: session) } })
                EmailInboxFilters(tab: $review.tab, query: $review.query, counts: review.counts,
                    isWorking: review.isWorking, showsSearch: isSearching)
                Text(selectedTab.help)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, -4)
                if let message = review.message {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.accent)
                }
                inbox
            }
            .padding(.horizontal, 20)
            .padding(.top, 4).padding(.bottom, AppScreenMetrics.contentBottomPadding)
        }
        // En el propio ScrollView y no en el ScrollViewReader que lo envuelve:
        // el hueco de la barra y el seguimiento del scroll tienen que llegarle
        // directamente.
        .tracksScrollChrome().floatingTabBarInset()
        .scrollDismissesKeyboard(.interactively)
        // Al recargar la lista se queda en su sitio: vaciarla encogía la
        // pantalla y la hacía subir y bajar.
        .refreshable { await review.load(using: session, keepsRows: true) }
        .onChange(of: expandedID) { _, id in
            guard let id else { return }
            // Desplaza lo justo para que el desplegable entre en pantalla; si ya
            // se ve, no mueve nada.
            withAnimation(AppMotion.expand) { proxy.scrollTo(id, anchor: nil) }
        }
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .onChange(of: isSearching) { _, open in if !open { review.query = "" } }
        .onChange(of: review.tab) { review.page = 1; expandedID = nil }
        .onChange(of: review.query) { review.page = 1 }
        .task(id: requestKey) {
            if !review.query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await review.load(using: session)
        }
        .confirmationDialog("¿Descartar este movimiento?", isPresented: Binding(get: { discarded != nil }, set: { if !$0 { discarded = nil } }), titleVisibility: .visible) {
            if let row = discarded {
                Button("Descartar", role: .destructive) { Task { _ = await review.apply(["descartar": [row.id]], using: session); discarded = nil } }
            }
        } message: { Text("No se guardará como gasto y no volverá a aparecer en pendientes.") }
    }

    @ViewBuilder private var inbox: some View {
        if let error = review.loadError {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(AppTheme.negative)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("No pudimos leer tu correo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button("Reintentar") { Task { await review.load(using: session) } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.backgroundTop)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Capsule().fill(AppTheme.primaryText))
                    .buttonStyle(.pressable(scale: 0.96))
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
        } else if review.result == nil {
            ListRowsSkeleton(label: "Cargando movimientos")
                .transition(.opacity)
        } else if let result = review.result {
            VStack(spacing: 0) {
                if !result.enabled {
                    EmailInboxState(title: "Correo no disponible", message: "El servidor no habilitó la importación para esta cuenta.", icon: "envelope.badge", tint: AppTheme.warning)
                } else if result.pendientes.isEmpty {
                    EmailInboxState(title: review.query.isEmpty ? selectedTab.emptyTitle : "Sin resultados",
                        message: review.query.isEmpty ? "Puedes sincronizar para buscar nuevos movimientos." : "Prueba con otra descripción, banco o fecha.",
                        icon: review.query.isEmpty ? "checkmark.circle" : "magnifyingglass")
                } else {
                    ForEach(Array(result.pendientes.enumerated()), id: \.element.id) { index, row in
                        let isExpanded = expandedID == row.id
                        VStack(spacing: 0) {
                            EmailMovementRow(row: row, category: session.categorias.first { $0.id == row.categoria_id },
                                isExpanded: isExpanded, onReview: { toggle(row) }, onDiscard: { discarded = row })
                                .disabled(review.isWorking)
                            if isExpanded {
                                EmailMovementReviewPanel(row: row, review: review) {
                                    withAnimation(AppMotion.expand) { expandedID = nil }
                                }
                                .transition(AppMotion.reveal)
                            }
                        }
                        .background(isExpanded ? AppTheme.primaryText.opacity(0.03) : .clear)
                        .id(row.id)
                        if index < result.pendientes.count - 1 { AppHairline() }
                    }
                }
            }
            .background(AppTheme.cardBackground())
            .clipShape(.rect(cornerRadius: AppTheme.Radius.card, style: .continuous))
            .animation(AppMotion.standard, value: result.pendientes.map(\.id))
            .transition(.opacity)
            if result.enabled, (result.pages ?? 1) > 1 { pagination(result).padding(.top, 8) }
        }
    }

    private func toggle(_ row: EmailMovement) {
        withAnimation(AppMotion.expand) {
            expandedID = expandedID == row.id ? nil : row.id
        }
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
