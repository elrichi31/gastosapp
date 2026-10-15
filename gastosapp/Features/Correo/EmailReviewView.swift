import SwiftUI

struct EmailReviewView: View {
    @Environment(ExpenseStore.self) private var session
    @State private var review = EmailReviewStore()
    @State private var editing: EmailMovement?
    @State private var discarded: EmailMovement?
    private var selectedTab: EmailReviewTab { EmailReviewTab(rawValue: review.tab) ?? .nuevos }
    private var requestKey: String { "\(review.tab)|\(review.page)|\(review.query)" }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                EmailInboxHeader(counts: review.counts, selectedTab: selectedTab,
                    isSyncing: review.isSyncing, canSync: review.isEnabled == true && !review.isWorking,
                    onSync: { Task { await review.sync(using: session) } })
                    .padding(.bottom, 22)
                EmailInboxFilters(tab: $review.tab, query: $review.query, counts: review.counts, isWorking: review.isWorking)
                    .padding(.bottom, 24)
                if let message = review.message {
                    Label(message, systemImage: "checkmark.circle")
                        .font(.caption).foregroundStyle(AppTheme.accent)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 16)
                }
                inbox
            }
            .padding(.horizontal, AppScreenMetrics.horizontalPadding)
            .padding(.top, 8).padding(.bottom, AppScreenMetrics.contentBottomPadding)
        }
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .tracksScrollChrome().floatingTabBarInset()
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await review.load(using: session) }
        .onChange(of: review.tab) { review.page = 1 }
        .onChange(of: review.query) { review.page = 1 }
        .task(id: requestKey) {
            if !review.query.isEmpty {
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await review.load(using: session)
        }
        .sheet(item: $editing) { row in EmailMovementReviewSheet(row: row, review: review) }
        .confirmationDialog("¿Descartar este movimiento?", isPresented: Binding(get: { discarded != nil }, set: { if !$0 { discarded = nil } }), titleVisibility: .visible) {
            if let row = discarded {
                Button("Descartar", role: .destructive) { Task { _ = await review.apply(["descartar": [row.id]], using: session); discarded = nil } }
            }
        } message: { Text("No se guardará como gasto y no volverá a aparecer en pendientes.") }
    }

    @ViewBuilder private var inbox: some View {
        if let error = review.error {
            ExpenseFormStatusCard(status: .init(title: "No pudimos cargar el correo", message: error, icon: "wifi.exclamationmark", tint: AppTheme.warning))
            Button("Reintentar") { Task { await review.load(using: session) } }
                .buttonStyle(.bordered).tint(AppTheme.accent).padding(.top, 12)
        } else if review.isLoading {
            ProgressView("Cargando movimientos…").font(.caption)
                .foregroundStyle(AppTheme.secondaryText).frame(maxWidth: .infinity).padding(.vertical, 48)
        } else if let result = review.result {
            if !result.enabled {
                EmailInboxState(title: "Correo no disponible", message: "El servidor no habilitó la importación para esta cuenta.", icon: "envelope.badge", tint: AppTheme.warning)
            } else if result.pendientes.isEmpty {
                EmailInboxState(title: review.query.isEmpty ? selectedTab.emptyTitle : "Sin resultados",
                    message: review.query.isEmpty ? "Puedes sincronizar para buscar nuevos movimientos." : "Prueba con otra descripción, banco o fecha.",
                    icon: review.query.isEmpty ? "checkmark.circle" : "magnifyingglass")
            } else {
                HStack {
                    Text(selectedTab.title).font(.headline).foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    Text("\(result.total ?? result.pendientes.count) pendientes").font(.caption).foregroundStyle(AppTheme.tertiaryText)
                }.padding(.bottom, 8)
                ForEach(result.pendientes) { row in
                    EmailMovementRow(row: row, category: session.categorias.first { $0.id == row.categoria_id },
                        onReview: { editing = row }, onDiscard: { discarded = row })
                        .disabled(review.isWorking)
                    AppHairline()
                }
                if (result.pages ?? 1) > 1 { pagination(result).padding(.top, 24) }
            }
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
