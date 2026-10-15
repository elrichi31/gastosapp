import SwiftUI

/// Crear cuenta, según el canvas «Crear cuenta»: mismas reglas que la web
/// (contraseñas iguales, mínimo 6 caracteres) y aviso para confirmar el correo.
struct RegisterView: View {
    private enum FocusField: Hashable { case first, last, email, password, confirm }

    @Environment(ExpenseStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showPassword = false
    @State private var working = false
    @State private var error: String?
    @State private var message: String?
    @FocusState private var focusedField: FocusField?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Button(action: dismiss.callAsFunction) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppTheme.popoverSurface))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Volver a iniciar sesión")
                    Text("Zenlor")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let message {
                    confirmation(message)
                } else {
                    form
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.screenBackground.ignoresSafeArea())
        .tint(AppTheme.accent)
        .animation(.easeOut(duration: 0.2), value: error)
        .animation(.spring(response: 0.3, dampingFraction: 0.86), value: message)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Crear cuenta")
                    .font(.system(size: 40, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(AppTheme.primaryText)
                    .accessibilityAddTraits(.isHeader)
                Text("Ingresa tus datos para empezar a organizar tus gastos.")
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    AuthField(label: "Nombre", isFocused: focusedField == .first) {
                        TextField("", text: $firstName, prompt: Text("Tu nombre").foregroundStyle(AppTheme.placeholderText))
                            .textContentType(.givenName)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .first)
                            .onSubmit { focusedField = .last }
                            .accessibilityLabel("Nombre")
                    }
                    AuthField(label: "Apellido", isFocused: focusedField == .last) {
                        TextField("", text: $lastName, prompt: Text("Tu apellido").foregroundStyle(AppTheme.placeholderText))
                            .textContentType(.familyName)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .last)
                            .onSubmit { focusedField = .email }
                            .accessibilityLabel("Apellido")
                    }
                }

                AuthField(label: "Correo electrónico", isFocused: focusedField == .email, placeholder: "tu@email.com", isEmpty: email.isEmpty) {
                    TextField("", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                        .accessibilityLabel("Correo electrónico")
                }

                AuthField(label: "Contraseña", isFocused: focusedField == .password) {
                    passwordInput($password, prompt: "Mínimo 6 caracteres", field: .password)
                        .accessibilityLabel("Contraseña")
                } trailing: {
                    PasswordVisibilityButton(isVisible: $showPassword)
                }

                AuthField(label: "Confirmar contraseña", isFocused: focusedField == .confirm) {
                    passwordInput($confirmation, prompt: "Repite tu contraseña", field: .confirm)
                        .accessibilityLabel("Confirmar contraseña")
                }

                if let error {
                    AuthErrorBanner(message: error)
                }

                AuthPrimaryButton(title: working ? "Creando cuenta…" : "Crear cuenta", isWorking: working) {
                    Task { await register() }
                }
            }

            HStack(spacing: 5) {
                Text("¿Ya tienes una cuenta?")
                    .foregroundStyle(AppTheme.secondaryText)
                Button("Inicia sesión", action: dismiss.callAsFunction)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.system(size: 15))
            .frame(maxWidth: .infinity)
        }
    }

    private func passwordInput(_ text: Binding<String>, prompt: String, field: FocusField) -> some View {
        Group {
            if showPassword {
                TextField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.placeholderText))
            } else {
                SecureField("", text: text, prompt: Text(prompt).foregroundStyle(AppTheme.placeholderText))
            }
        }
        .textContentType(.newPassword)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(field == .password ? .next : .go)
        .focused($focusedField, equals: field)
        .onSubmit {
            if field == .password { focusedField = .confirm } else { Task { await register() } }
        }
    }

    private func confirmation(_ text: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 84, height: 84)
                .background(Circle().fill(AppTheme.accent.opacity(0.16)))
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Revisa tu correo")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(AppTheme.primaryText)
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: 300)
            }
            .multilineTextAlignment(.center)
            AuthPrimaryButton(title: "Ir a iniciar sesión", action: dismiss.callAsFunction)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
        .accessibilityElement(children: .contain)
    }

    /// Mismos mensajes que /auth/register en la web.
    private var validationError: String? {
        let first = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if first.isEmpty || last.isEmpty || first.count > 80 || last.count > 80 || !email.contains("@") || password.isEmpty {
            return "Revisa nombre, apellido, correo y contraseña."
        }
        if password != confirmation { return "Las contraseñas no coinciden" }
        if password.count < 6 { return "La contraseña debe tener al menos 6 caracteres" }
        if password.count > 128 { return "La contraseña no puede tener más de 128 caracteres" }
        return nil
    }

    private func register() async {
        if let validationError {
            error = validationError
            return
        }
        focusedField = nil
        working = true; error = nil
        defer { working = false }
        do {
            struct Result: Decodable { let message: String; let needsEmailConfirmation: Bool }
            let body = try JSONEncoder().encode(["firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines), "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines), "email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
            let result = try await session.request(Result.self, path: "/api/auth/register", method: "POST", requiresAuth: false, body: body)
            message = result.message; password = ""; confirmation = ""
        } catch { if !isCancellationError(error) { self.error = error.localizedDescription } }
    }
}
