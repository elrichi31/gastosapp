import Foundation
import Security

enum AuthSessionStore {
    static func save<T: Encodable>(_ value: T, for key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gastosapp.auth",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        let attributes: [String: Any] = query.merging([
            kSecValueData as String: data
        ]) { _, new in new }

        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func load<T: Decodable>(for key: String) -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gastosapp.auth",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

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
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "gastosapp.auth",
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)
    }
}
