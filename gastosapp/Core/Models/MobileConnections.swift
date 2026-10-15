import Foundation

struct MobileConnections: Decodable {
    struct Connection: Decodable, Identifiable {
        let id: String
        let created_at: String
        let expires_at: String
        let scopes: [String]?
    }
    let state: String
    let endpoint: String?
    let connections: [Connection]
    let revocationEnabled: Bool
}
