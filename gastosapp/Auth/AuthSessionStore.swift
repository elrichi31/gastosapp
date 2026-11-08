import Foundation
import Security

enum AuthSessionStore {
    /// El llavero no se puede leer todavía (iPhone sin desbloquear desde que
    /// encendió). No significa que no haya sesión guardada.
    struct UnavailableError: Error {}

    static func save<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        let query = baseQuery(for: key)
        // Legible tras el primer desbloqueo: la revisión del correo corre en
        // segundo plano con el iPhone bloqueado. Con el valor por defecto
        // (sólo desbloqueado) no veía la sesión y la app pedía iniciar sesión.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Actualizar en lugar de borrar y volver a crear: si el alta fallaba
        // después del borrado, la sesión se perdía.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
    }

    static func load<T: Decodable>(for key: String) throws -> T? {
        let query = baseQuery(for: key).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]) { _, new in new }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecInteractionNotAllowed {
            throw UnavailableError()
        }

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let value = try? JSONDecoder().decode(T.self, from: data)
        else {
            return nil
        }

        return value
    }

    static func delete(for key: String) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
    }

    private static func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gastosapp.auth",
            kSecAttrAccount as String: key
        ]
    }
}
