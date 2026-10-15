import SwiftUI

struct ConnectionsView: View {
    @Environment(ExpenseStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var data: MobileConnections?
    @State private var error: String?
    @State private var working = false
    @State private var revoke: MobileConnections.Connection?
    @State private var revokeSessions = false
    var body: some View {
        NavigationStack {
            Form {
                Section("ChatGPT") {
                    if working { ProgressView() }
                    if let data {
                        Text(data.state == "ready" ? "MCP configurado" : "MCP pendiente de configuración")
                        if let endpoint = data.endpoint { Text(endpoint).font(.caption).textSelection(.enabled); ShareLink("Compartir URL de conexión", item: endpoint) }
                        if data.connections.isEmpty { Text("Sin conexiones activas").foregroundStyle(.secondary) }
                        ForEach(data.connections) { connection in
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ChatGPT").font(.headline)
                                Text("Vence: " + connection.expires_at.prefix(10)).font(.caption)
                                Text((connection.scopes ?? []).joined(separator: ", ")).font(.caption)
                                Button("Revocar acceso", role: .destructive) { revoke = connection }
                            }
                        }
                    }
                }
                if data?.revocationEnabled == true {
                    Section("Sesiones") {
                        Text("Cierra todas las sesiones de la web y de la app. Tendrás que iniciar sesión otra vez.")
                        Button("Cerrar todas las sesiones", role: .destructive) { revokeSessions = true }
                    }
                }
                if let error { Section { Text(error).foregroundStyle(AppTheme.negative); Button("Reintentar") { Task { await load() } } } }
            }.navigationTitle("Conexiones y seguridad")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
                .task { await load() }.refreshable { await load() }.disabled(working)
                .confirmationDialog("¿Revocar el acceso de ChatGPT?", isPresented: Binding(get: { revoke != nil }, set: { if !$0 { revoke = nil } }), titleVisibility: .visible) {
                    if let grant = revoke { Button("Revocar acceso", role: .destructive) { Task { await mutate(["action": "revoke_connection", "grant_id": grant.id]); revoke = nil } } }
                }
                .confirmationDialog("¿Cerrar todas las sesiones?", isPresented: $revokeSessions, titleVisibility: .visible) {
                    Button("Cerrar todas", role: .destructive) { Task { await mutate(["action": "revoke_sessions"]) } }
                }
        }
    }
    private func load() async {
        working = true; error = nil
        defer { working = false }
        do { data = try await session.request(MobileConnections.self, path: "/api/mobile/connections", requiresAuth: true) }
        catch { if !isCancellationError(error) { self.error = "No se pudo consultar las conexiones. Verifica que el backend tenga la API móvil actualizada. " + error.localizedDescription } }
    }
    private func mutate(_ payload: [String: String]) async {
        working = true; error = nil
        do {
            struct Result: Decodable { let success: Bool }
            let result = try await session.request(Result.self, path: "/api/mobile/connections", method: "POST", requiresAuth: true, body: JSONEncoder().encode(payload))
            guard result.success else { throw ExpenseStoreError.invalidResponse }
            if payload["action"] == "revoke_sessions" { session.logout(); dismiss() }
            else { await load() }
        } catch { if !isCancellationError(error) { self.error = error.localizedDescription } }
        working = false
    }
}
