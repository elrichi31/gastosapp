import Foundation

/// Retires production domains while keeping explicitly configured development servers.
enum BackendURLPreference {
    static func resolve(storedURL: String?, configuredURL: String) -> String {
        guard var stored = storedURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !stored.isEmpty else { return configuredURL }
        while stored.hasSuffix("/") { stored.removeLast() }
        let retiredOrigins: Set<String> = [
            "https://bethaspend.bethalabs.com",
            "http://bethaspend.bethalabs.com",
            "https://zenlor.app"
        ]
        return retiredOrigins.contains(stored.lowercased()) ? configuredURL : stored
    }
}
