import SwiftUI

/// Notificaciones de la app: correo por revisar, presupuestos cerca del límite
/// y cobros de los próximos días.
///
/// Antes era un panel flotante bajo la barra; ahora es una pantalla completa
/// que entra desde la derecha, con un grupo por tipo de aviso y acceso a su
/// configuración.
struct AppNotificationsView: View {
    let onClose: () -> Void

    @Environment(AppNavigator.self) private var navigator
    @Environment(AppInbox.self) private var inbox
    @Environment(ExpenseStore.self) private var store
    @Environment(BudgetStore.self) private var budgets

    @State private var showsSettings = false
    /// Los puntos de no leído se quedan mientras la pantalla está abierta, para
    /// que se vea qué es nuevo; se marca como leído al salir.
    @State private var wasUnread = false

    private struct KindGroup: Identifiable {
        let kind: AppInbox.Item.Kind
        let title: String
        let items: [AppInbox.Item]
        var id: String { title }
    }

    private var groups: [KindGroup] {
        let order: [(AppInbox.Item.Kind, String)] = [
            (.mail, "Correo"),
            (.budget, "Presupuesto"),
            (.recurring, "Próximos cobros")
        ]
        return order.compactMap { kind, title in
            let items = inbox.items.filter { $0.kind == kind }
            return items.isEmpty ? nil : KindGroup(kind: kind, title: title, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if inbox.items.isEmpty {
                        emptyState
                    } else {
                        ForEach(groups) { group in
                            section(group)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 40)
                .animation(AppMotion.standard, value: inbox.items.map(\.id))
            }
            .refreshable { await inbox.refresh(store: store, budgets: budgets) }
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showsSettings) {
                NotificationSettingsView()
            }
        }
        .onAppear { wasUnread = inbox.hasUnread }
        .onDisappear { inbox.markRead() }
        .task { await inbox.refresh(store: store, budgets: budgets) }
    }

    // MARK: - Piezas

    private var header: some View {
        HStack(spacing: 12) {
            circleButton(icon: "chevron.left", label: "Volver", action: onClose)
            Text("Notificaciones")
                .font(.system(size: 32, weight: .bold))
                .tracking(-0.6)
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            circleButton(icon: "gearshape", label: "Configuración de notificaciones") {
                showsSettings = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, AppScreenMetrics.headerTopPadding)
        .padding(.bottom, 12)
        .background(AppTheme.backgroundTop.ignoresSafeArea(edges: .top))
    }

    private func circleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    private func section(_ group: KindGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.title)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text("\(group.items.count)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    Button { open(item) } label: { row(item) }
                        .buttonStyle(.plain)
                    if index < group.items.count - 1 {
                        AppHairline().padding(.leading, 66)
                    }
                }
            }
            .background(AppTheme.cardBackground(cornerRadius: 20))
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
        }
        .transition(AppMotion.reveal)
    }

    private func style(_ kind: AppInbox.Item.Kind) -> (icon: String, tint: Color) {
        switch kind {
        case .mail: ("envelope.fill", AppTheme.accent)
        case .budget: ("exclamationmark.circle.fill", AppTheme.warning)
        case .recurring: ("repeat", AppTheme.secondaryAccent)
        }
    }

    private func row(_ item: AppInbox.Item) -> some View {
        let (icon, tint) = style(item.kind)
        return HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.18)))
                .overlay(alignment: .topTrailing) {
                    if wasUnread {
                        Circle()
                            .fill(AppTheme.negative)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().strokeBorder(AppTheme.surface, lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: wasUnread ? .semibold : .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.subtitle)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 68)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint(wasUnread ? "Nueva" : "")
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "bell")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 64, height: 64)
                .background(Circle().fill(AppTheme.accent.opacity(0.16)))
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Todo al día")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)
                Text("Aquí verás los movimientos del correo por revisar, los presupuestos cerca del límite y los cobros de los próximos días.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                showsSettings = true
            } label: {
                Label("Configurar notificaciones", systemImage: "gearshape")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(AppTheme.popoverSurface))
            }
            .buttonStyle(.pressable(scale: 0.97))
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.top, 72)
    }

    // MARK: - Acciones

    private func open(_ item: AppInbox.Item) {
        onClose()
        switch item.kind {
        case .mail: navigator.open(.gastos, section: .correo)
        case .budget: navigator.open(.presupuestos)
        case .recurring: navigator.open(.gastos, section: .recurrentes)
        }
    }
}
