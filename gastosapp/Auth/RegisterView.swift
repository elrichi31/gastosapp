import SwiftUI

struct RegisterView: View {
    @Environment(ExpenseStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?
    @State private var message: String?
    private var valid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && firstName.count <= 80 &&
        !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && lastName.count <= 80 &&
        email.contains("@") && password.count >= 6 && password.count <= 128
    }
    var body: some View {
        NavigationStack {
            Form {
                if let message { Section { Text(message); Button("Volver a iniciar sesión") { dismiss() } } }
                else {
                    Section("Tu cuenta") {
                        TextField("Nombre", text: $firstName).textContentType(.givenName)
                        TextField("Apellido", text: $lastName).textContentType(.familyName)
                        TextField("Correo", text: $email).textContentType(.emailAddress).keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                        SecureField("Contraseña (mínimo 6 caracteres)", text: $password).textContentType(.newPassword)
                    }
                    if let error { Text(error).foregroundStyle(AppTheme.negative) }
                    Button("Crear cuenta") { Task { await register() } }.disabled(!valid || working)
                    if working { ProgressView() }
                }
            }.navigationTitle("Crear cuenta")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
    private func register() async {
        working = true; error = nil
        defer { working = false }
        do {
            struct Result: Decodable { let message: String; let needsEmailConfirmation: Bool }
            let body = try JSONEncoder().encode(["firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines), "lastName": lastName.trimmingCharacters(in: .whitespacesAndNewlines), "email": email.trimmingCharacters(in: .whitespacesAndNewlines), "password": password])
            let result = try await session.request(Result.self, path: "/api/auth/register", method: "POST", requiresAuth: false, body: body)
            message = result.message; password = ""
        } catch { if !isCancellationError(error) { self.error = error.localizedDescription } }
    }
}
