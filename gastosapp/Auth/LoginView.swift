import SwiftUI

struct LoginView: View {
    private enum FocusField: Hashable {
        case email
        case password
    }

    @Environment(ExpenseStore.self) private var store

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: FocusField?

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !store.isAuthenticating
    }

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    encabezado
                    card
                    footer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Image(systemName: "wallet.pass.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Zenlor")
                        .font(.system(size: 34, weight: .bold, design: .default))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("Tu dinero, claro y simple")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.5))
                }
            }

            Text("Inicia sesión para ver tus movimientos, registrar gastos y mantener todo en un solo lugar.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.primaryText.opacity(0.60))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 18)
    }

    private var card: some View {
        VStack(spacing: 18) {
            quickHighlights

            campo(
                titulo: "Correo electronico",
                icono: "at",
                content: {
                    TextField(
                        "tu@correo.com",
                        text: $email,
                        prompt: Text("tu@correo.com").foregroundStyle(AppTheme.primaryText.opacity(0.24))
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .foregroundStyle(AppTheme.primaryText)
                    .onSubmit {
                        focusedField = .password
                    }
                }
            )

            campo(
                titulo: "Contrasena",
                icono: "lock.fill",
                content: {
                    HStack(spacing: 10) {
                        Group {
                            if showPassword {
                                TextField(
                                    "Ingresa tu contrasena",
                                    text: $password,
                                    prompt: Text("Ingresa tu contrasena").foregroundStyle(AppTheme.primaryText.opacity(0.24))
                                )
                            } else {
                                SecureField(
                                    "Ingresa tu contrasena",
                                    text: $password,
                                    prompt: Text("Ingresa tu contrasena").foregroundStyle(AppTheme.primaryText.opacity(0.24))
                                )
                            }
                        }
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .foregroundStyle(AppTheme.primaryText)
                        .onSubmit {
                            guard canSubmit else { return }
                            Task {
                                await iniciarSesion()
                            }
                        }

                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(AppTheme.primaryText.opacity(0.55))
                        }
                        .accessibilityLabel(showPassword ? "Ocultar contrasena" : "Mostrar contrasena")
                        .accessibilityHint("Alterna la visibilidad de la contrasena")
                    }
                }
            )

            LoginSubmitSection(
                isAuthenticating: store.isAuthenticating,
                canSubmit: canSubmit,
                errorMessage: store.authErrorMessage
            ) {
                Task {
                    await iniciarSesion()
                }
            }
        }
        .padding(22)
        .background(AppTheme.cardBackground(cornerRadius: 28))
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text("Tus datos se mantienen disponibles para que entres sin complicarte.")
                .font(.caption)
                .foregroundStyle(AppTheme.primaryText.opacity(0.46))
                .multilineTextAlignment(.center)

            Link("Crear cuenta", destination: LocalAPIConfig.registerURL)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
        }
        .padding(.bottom, 18)
    }

    private var quickHighlights: some View {
        HStack(spacing: 10) {
            highlightPill(icon: "chart.bar.fill", text: "Resumen")
            highlightPill(icon: "plus.circle.fill", text: "Registrar")
            highlightPill(icon: "repeat.circle.fill", text: "Control")
        }
    }

    private func highlightPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppTheme.primaryText.opacity(0.72))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(
            Capsule()
                .fill(AppTheme.primaryText.opacity(0.05))
        )
    }

    private func campo<Content: View>(titulo: String, icono: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primaryText.opacity(0.48))
                .tracking(1.1)

            HStack(spacing: 12) {
                Image(systemName: icono)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 28, height: 28)
                    .background(AppTheme.primaryText.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                content()
            }
            .padding(14)
            .background(AppTheme.primaryText.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func iniciarSesion() async {
        let ok = await store.login(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )

        guard ok else { return }
        password = ""
    }
}

#Preview {
    LoginView()
        .environment(ExpenseStore())
}
