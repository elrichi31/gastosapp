import Foundation

struct EmailReviewPage: Decodable {
    let enabled: Bool
    var pendientes: [EmailMovement]
    let counts: [String: Int]?
    let total: Int?
    let page: Int?
    let pages: Int?
    func applyingAlias(_ saved: EmailAliasResult) -> EmailReviewPage {
        var updated = self
        updated.pendientes = pendientes.map { row in
            row.canHaveAlias && row.destinatario == saved.destinatario ? row.updatingAlias(saved.alias) : row
        }
        return updated
    }
}
