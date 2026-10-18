import SwiftUI

struct ProfileView: View {
    /// `nil` cuando la vista no se presenta de forma modal.
    var onClose: (() -> Void)?

    @State private var showsConnections = false
    @Environment(ExpenseStore.self) private var store
    @AppStorage(AppAppearancePreference.storageKey) private var appearanceRawValue = AppAppearancePreference.defaultValue.rawValue
    @AppStorage(SavingsGoalSettings.enabledKey) private var savingsGoalEnabled = false
    @AppStorage(SavingsGoalSettings.monthlyTargetKey) private var monthlySavingsTarget = 0.0

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sessionCard
                    section("Apariencia") { appearancePicker }
                    section("Conexiones y seguridad") {
                        group {
                            navigationRow(
                                icon: "link",
                                title: "Conexiones MCP y sesiones",
                                subtitle: "ChatGPT y dispositivos con acceso",
                                showsDivider: false
                            ) { showsConnections = true }
                        }
                    }
                    section("Notificaciones") { NotificationSettingsSection() }
                    section("Objetivo de ahorro") { savingsGroup }
                    logoutButton
                        .padding(.top, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, AppScreenMetrics.contentBottomPadding)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppTheme.popoverSurface))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Cerrar")
                }
                Text("Cuenta")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, AppScreenMetrics.headerTopPadding)
            .padding(.bottom, 12)
            .background(AppTheme.backgroundTop.ignoresSafeArea(edges: .top))
        }
        .sheet(isPresented: $showsConnections) { ConnectionsView() }
    }

    // MARK: - Piezas

    private var initials: String {
        let name = store.currentUser?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }

    private var sessionCard: some View {
        HStack(spacing: 14) {
            Text(initials)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 52, height: 52)
                .background(Circle().fill(AppTheme.accent.opacity(0.18)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.currentUser?.name ?? "Sesión activa")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                Text(store.currentUser?.email ?? "Sin correo")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AppTheme.cardBackground(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(AppTheme.tertiaryText)
                .padding(.horizontal, 4)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    private func group<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(AppTheme.cardBackground(cornerRadius: 20))
            .clipShape(.rect(cornerRadius: 20, style: .continuous))
    }

    private var appearancePicker: some View {
        HStack(spacing: 0) {
            ForEach(AppAppearancePreference.allCases) { option in
                let isSelected = appearanceRawValue == option.rawValue
                Button {
                    withAnimation(AppMotion.standard) { appearanceRawValue = option.rawValue }
                } label: {
                    Text(option.title)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? AppTheme.backgroundTop : AppTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Capsule().fill(isSelected ? AppTheme.primaryText : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(AppTheme.popoverSurface))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tema")
    }

    private var savingsGroup: some View {
        group {
            settingsToggle(
                title: "Meta mensual",
                subtitle: "Resumen calculará cuánto puedes gastar sin tocarla.",
                isOn: $savingsGoalEnabled,
                showsDivider: savingsGoalEnabled
            )
            if savingsGoalEnabled {
                HStack(spacing: 12) {
                    Text("Quiero ahorrar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("$").foregroundStyle(AppTheme.tertiaryText)
                        TextField("0", value: $monthlySavingsTarget, format: .number.precision(.fractionLength(2)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 92)
                            .accessibilityLabel("Monto a ahorrar cada mes")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(Capsule().fill(AppTheme.popoverSurface))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 60)
            }
        }
    }

    private func settingsToggle(title: String, subtitle: String, isOn: Binding<Bool>, showsDivider: Bool = true) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(AppTheme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) {
            if showsDivider { AppHairline() }
        }
    }

    private func navigationRow(icon: String, title: String, subtitle: String, showsDivider: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.tertiaryText)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 60)
            .contentShape(.rect)
            .overlay(alignment: .bottom) {
                if showsDivider { AppHairline() }
            }
        }
        .buttonStyle(.plain)
    }

    private var logoutButton: some View {
        Button {
            onClose?()
            store.logout()
        } label: {
            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppTheme.negative)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(Capsule().fill(AppTheme.popoverSurface))
        }
        .buttonStyle(.pressable(scale: 0.98))
    }
}

#Preview {
    let store = ExpenseStore()
    store.currentUser = AuthenticatedUser(id: "1", email: "nico@mail.com", name: "Nicolas")
    return ProfileView()
        .environment(store)
}
