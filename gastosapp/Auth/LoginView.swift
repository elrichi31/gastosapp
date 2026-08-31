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
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer(minLength: 24)
                    encabezado
                    capacidades
                        .padding(.top, 24)
                    card
                        .padding(.top, 28)
                    footer
                        .padding(.top, 24)
                    Spacer(minLength: 24)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height)
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .tint(AppTheme.accent)
        .background(AppTheme.screenBackground.ignoresSafeArea())
    }

    private var encabezado: some View {
        VStack(spacing: 14) {
            Image("BrandMark")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 12, y: 6)

            VStack(spacing: 5) {
                Text("Zenlor")
                    .font(AppTheme.number(30, .bold))
                    .kerning(-0.5)
                    .foregroundStyle(AppTheme.primaryText)
                Text("Tu dinero, claro y simple")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Qué hace la app, en tres palabras. Reemplaza al párrafo de introducción:
    /// decía lo mismo y competía con el formulario por la atención.
    private var capacidades: some View {
        HStack(spacing: 8) {
            capacidad(icon: "chart.bar.fill", text: "Resumen")
            capacidad(icon: "plus.circle.fill", text: "Registrar")
            capacidad(icon: "repeat", text: "Control")
        }
    }

    private func capacidad(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(Capsule().fill(AppTheme.controlSurface))
    }

    private var card: some View {
        VStack(spacing: 16) {
            campo(titulo: "Correo electrónico", field: .email) {
                marcador("tu@correo.com", visible: email.isEmpty) {
                    TextField("", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled(true)
                        .textContentType(.username)
                        .tint(AppTheme.accent)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .foregroundStyle(AppTheme.primaryText)
                        .accessibilityLabel("Correo electrónico")
                        .onSubmit { focusedField = .password }
                }
            }

            campo(titulo: "Contraseña", field: .password) {
                HStack(spacing: 10) {
                    marcador("Tu contraseña", visible: password.isEmpty) {
                        Group {
                            if showPassword {
                                TextField("", text: $password)
                            } else {
                                SecureField("", text: $password)
                            }
                        }
                        .accessibilityLabel("Contraseña")
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.password)
                    .tint(AppTheme.accent)
                    .submitLabel(.go)
                    .focused($focusedField, equals: .password)
                    .foregroundStyle(AppTheme.primaryText)
                    .onSubmit {
                        guard canSubmit else { return }
                        Task { await iniciarSesion() }
                    }

                    Button {
                        showPassword.toggle()
                        focusedField = .password
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.tertiaryText)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showPassword ? "Ocultar contraseña" : "Mostrar contraseña")
                    .accessibilityHint("Mantiene el foco en el campo de contraseña")
                }
            }

            LoginSubmitSection(
                isAuthenticating: store.isAuthenticating,
                canSubmit: canSubmit,
                errorMessage: store.authErrorMessage
            ) {
                Task { await iniciarSesion() }
            }
            .padding(.top, 4)
        }
        .padding(22)
        .background(AppTheme.cardBackground(cornerRadius: 26))
    }

    private var footer: some View {
        HStack(spacing: 5) {
            Text("¿No tienes cuenta?")
                .foregroundStyle(AppTheme.secondaryText)
            Link("Crear cuenta", destination: LocalAPIConfig.registerURL)
                .foregroundStyle(AppTheme.accent)
                .fontWeight(.semibold)
        }
        .font(.footnote)
    }

    /// Placeholder propio en lugar de `prompt:`.
    ///
    /// El `foregroundStyle` de un `Text` pasado como `prompt` se ignora y el
    /// campo de correo lo pintaba con el azul del sistema, fuera del tema.
    private func marcador<Content: View>(
        _ text: String,
        visible: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .leading) {
            if visible {
                Text(text)
                    .foregroundStyle(AppTheme.tertiaryText)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            content()
        }
    }

    private func campo<Content: View>(
        titulo: String,
        field: FocusField,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isFocused = focusedField == field

        return VStack(alignment: .leading, spacing: 8) {
            AppSectionLabel(text: titulo, size: 10)

            content()
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .fill(AppTheme.insetSurface)
                )
                .overlay(
                    // El foco se marca con el borde, no con un icono decorativo.
                    RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                        .strokeBorder(
                            isFocused ? AppTheme.accent : AppTheme.border,
                            lineWidth: isFocused ? 1.5 : 1
                        )
                )
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = field }
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
