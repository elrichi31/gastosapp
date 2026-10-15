import Foundation
import Testing
@testable import Zenlor

struct EmailAliasTests {
    private func row(_ id: Int, recipient: String?, alias: String? = nil, type: String = "gasto") -> EmailMovement {
        EmailMovement(id: id, tipo: type, origen: "Banco", fecha: "2026-10-10",
            descripcion: alias ?? "Transferencia a Ana Pérez", monto: 25, categoria_id: 1,
            metodo_pago_id: 1, destinatario: recipient, alias: alias,
            descripcion_original: "Transferencia a Ana Pérez", coincidencias: [])
    }

    @Test func aliasIsAvailableOnlyForSentTransfers() {
        #expect(row(1, recipient: "ana perez").canHaveAlias)
        #expect(!row(2, recipient: nil).canHaveAlias)
        #expect(!row(3, recipient: "  ").canHaveAlias)
        #expect(!row(4, recipient: "ana perez", type: "ingreso").canHaveAlias)
    }

    @Test func savedAliasUpdatesAllPendingTransfersForExactRecipient() {
        let page = EmailReviewPage(enabled: true,
            pendientes: [row(1, recipient: "ana perez"), row(2, recipient: "ana perez"), row(3, recipient: "ana")],
            counts: ["nuevos": 3], total: 3, page: 1, pages: 1)
        let updated = page.applyingAlias(EmailAliasResult(destinatario: "ana perez", alias: "Gimnasio"))
        #expect(updated.pendientes[0].descripcion == "Gimnasio")
        #expect(updated.pendientes[1].alias == "Gimnasio")
        #expect(updated.pendientes[2].alias == nil)
        #expect(updated.total == page.total)
        #expect(updated.pendientes.count == 3)
    }

    @Test func removingAliasRestoresOriginalDescription() {
        let updated = row(1, recipient: "ana perez", alias: "Gimnasio").updatingAlias("")
        #expect(updated.descripcion == "Transferencia a Ana Pérez")
        #expect(updated.alias == "")
    }

    @Test func serverOriginalDescriptionDecodes() throws {
        let data = Data(#"{"id":1,"tipo":"gasto","origen":"Banco","fecha":"2026-10-10","descripcion":"Gimnasio","descripcion_original":"Transferencia a Ana Pérez","monto":25,"destinatario":"ana perez","alias":"Gimnasio","coincidencias":[]}"#.utf8)
        let decoded = try JSONDecoder().decode(EmailMovement.self, from: data)
        #expect(decoded.descripcion_original == "Transferencia a Ana Pérez")
        #expect(decoded.updatingAlias("").descripcion == decoded.descripcion_original)
    }
}
