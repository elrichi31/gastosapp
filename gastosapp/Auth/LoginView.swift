import SwiftUI

/// Iniciar sesión, según el canvas «Iniciar sesión».
struct LoginView: View {
    private enum FocusField: Hashable {
        case email
        case password
    }

    @Environment(ExpenseStore.self) private var store

    @State private var showsRegistration = false
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
                VStack(alignment: .leading, spacing: 28) {
                    brand

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bienvenido")
                            .font(.system(size: 40, weight: .bold))
                            .tracking(-1.2)
                            .foregroundStyle(AppTheme.primaryText)
                            .accessibilityAddTraits(.isHeader)
                        Text("Accede a tu cuenta y sigue con tus finanzas.")
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    form

                    Spacer(minLength: 0)

                    HStack(spacing: 5) {
                        Text("¿No tienes cuenta?")
                            .foregroundStyle(AppTheme.secondaryText)
                        Button("Crear cuenta") { showsRegistration = true }
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.accent)
                    }
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .frame(minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showsRegistration) { RegisterView() }
        .tint(AppTheme.accent)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .animation(.easeOut(duration: 0.2), value: store.authErrorMessage)
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Image("BrandMark")
                .resizable()
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
            Text("Zenlor")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .foregroundStyle(AppTheme.primaryText)
        }
    }

    private var form: some View {
        VStack(spacing: 12) {
            AuthField(label: "Correo electrónico", isFocused: focusedField == .email, placeholder: "tu@email.com", isEmpty: email.isEmpty) {
                TextField("", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled(true)
                    .textContentType(.username)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .email)
                    .accessibilityLabel("Correo electrónico")
                    .onSubmit { focusedField = .password }
            }
            .onTapGesture { focusedField = .email }

            AuthField(label: "Contraseña", isFocused: focusedField == .password) {
                Group {
                    if showPassword {
                        TextField("", text: $password, prompt: Text("Tu contraseña").foregroundStyle(AppTheme.placeholderText))
                    } else {
                        SecureField("", text: $password, prompt: Text("Tu contraseña").foregroundStyle(AppTheme.placeholderText))
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textContentType(.password)
                .submitLabel(.go)
                .focused($focusedField, equals: .password)
                .accessibilityLabel("Contraseña")
                .onSubmit {
                    guard canSubmit else { return }
                    Task { await iniciarSesion() }
                }
            } trailing: {
                PasswordVisibilityButton(isVisible: $showPassword)
            }
            .onTapGesture { focusedField = .password }

            if let error = store.authErrorMessage, !error.isEmpty {
                AuthErrorBanner(message: error)
            }

            AuthPrimaryButton(
                title: store.isAuthenticating ? "Entrando…" : "Iniciar sesión",
                isWorking: store.isAuthenticating,
                isEnabled: canSubmit
            ) {
                Task { await iniciarSesion() }
            }
        }
    }

    private func iniciarSesion() async {
        focusedField = nil
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
