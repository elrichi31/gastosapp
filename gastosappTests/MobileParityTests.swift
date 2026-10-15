import Foundation
import Testing
@testable import Zenlor

@MainActor
struct MobileParityTests {
    @Test func budgetCrossingDoesNotRepeatAboveThreshold() {
        #expect(BudgetCrossing.message(before: 79, after: 80, limit: 100, category: "Comida") != nil)
        #expect(BudgetCrossing.message(before: 80, after: 95, limit: 100, category: "Comida") == nil)
        #expect(BudgetCrossing.message(before: 100, after: 101, limit: 100, category: "Comida") != nil)
        #expect(BudgetCrossing.message(before: 101, after: 110, limit: 100, category: "Comida") == nil)
        #expect(BudgetCrossing.message(before: 80, after: 70, limit: 100, category: "Comida") == nil)
    }

    @Test func taxMatchesBackendCentRounding() throws {
        let tax = ForeignTax(base: 15.99, selected: ["isd", "iva_digital"], customRate: "")
        #expect(tax.isValid)
        #expect(tax.taxAmount == 3.20)
        #expect(tax.total == 19.19)
        let custom = ForeignTax(base: 10, selected: ["custom"], customRate: "2,5")
        #expect(custom.total == 10.25)
        #expect(!ForeignTax(base: 10, selected: ["custom"], customRate: "101").isValid)
        #expect(!ForeignTax(base: 10, selected: [], customRate: "").isValid)
        #expect(!ForeignTax(base: .infinity, selected: ["isd"], customRate: "").isValid)
    }

    @Test func tagsNormalizeAndValidateLikeWeb() {
        #expect(ExpenseTags.normalize(" Viaje, familia, VIAJE,  regalo   mamá ") == ["viaje", "familia", "regalo mamá"])
        #expect(!ExpenseTags.isValid(Array(repeating: "a", count: 11)))
        #expect(!ExpenseTags.isValid([String(repeating: "a", count: 31)]))
        #expect(!ExpenseTags.isValid(["test\u{0000}"]))
    }

    @Test func legacyCacheStillDecodes() throws {
        let expense = Expense(descripcion: "Anterior", monto: 20, fecha: Date(), categoria: Categoria.fallback[0], metodoPago: .placeholder)
        let encoded = try JSONEncoder().encode(expense)
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "tags"); json.removeValue(forKey: "foreignTax")
        let decoded = try JSONDecoder().decode(Expense.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.monto == 20)
        #expect(decoded.tags == nil)
        #expect(decoded.foreignTax == nil)
    }

    @Test func foreignExpenseSurvivesCacheRoundtrip() throws {
        let tax = ForeignTax(base: 15.99, selected: ["isd"], customRate: "")
        let expense = Expense(descripcion: "Exterior", monto: tax.total, fecha: Date(), categoria: Categoria.fallback[0], metodoPago: .placeholder, tags: ["viaje", "exterior"], foreignTax: tax)
        let decoded = try JSONDecoder().decode(Expense.self, from: JSONEncoder().encode(expense))
        #expect(decoded == expense)
    }

    @Test func updateCanExplicitlyClearTaxesAndTags() throws {
        let payload = UpdateExpensePayload(descripcion: "Local", monto: 20, fecha: "2026-10-10", categoriaId: 1, metodoPagoId: 1, isRecurrent: false, tags: [], foreignTax: nil)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(json["impuesto_exterior"] is NSNull)
        #expect((json["tags"] as? [String]) == [])
    }

    @Test func remoteAnnualRuleIncludesTaxesAndServerSchedule() throws {
        let data = Data(#"{"id":1,"descripcion":"Servicio","monto":12,"categoria_id":1,"metodo_pago_id":1,"frecuencia":"anual","dia_mes":31,"mes_anual":12,"fecha_inicio":"2026-01-01","fecha_fin":null,"activo":true,"proxima_fecha":"2026-12-31","impuesto_exterior":{"base":10,"selected":["isd","iva_digital"],"customRate":""}}"#.utf8)
        let remote = try JSONDecoder().decode(RemoteRecurringExpense.self, from: data)
        let rule = remote.asRecurringExpense(categorias: Categoria.fallback, metodosPago: ExpensePaymentMethod.fallback)
        #expect(rule.frecuencia == .anual)
        #expect(rule.annualMonth == 12)
        #expect(rule.estimatedMonthlyAmount == 1)
        #expect(rule.foreignTax?.base == 10)
        #expect(rule.nextChargeDate.map(AppDateCodec.apiDateString) == "2026-12-31")
    }

    @Test func monthlyThirtyFirstClampsToFebruary() throws {
        let start = try #require(AppDateCodec.dateOnly(from: "2030-02-01"))
        let rule = RecurringExpense(id: 1, descripcion: "Mensual", monto: 10, frecuencia: .mensual, diaMes: 31, fechaInicio: start, activo: true, categoriaId: 1, metodoPagoId: 1, categoria: Categoria.fallback[0], metodoPago: .placeholder)
        #expect(rule.nextChargeDate(referenceDate: start).map(AppDateCodec.apiDateString) == "2030-02-28")
    }

    @Test func endDateAndInactiveRulesHaveNoFutureCharge() throws {
        let start = try #require(AppDateCodec.dateOnly(from: "2030-02-01"))
        let end = try #require(AppDateCodec.dateOnly(from: "2030-02-15"))
        var rule = RecurringExpense(id: 1, descripcion: "Finalizada", monto: 10, frecuencia: .mensual, diaMes: 31, fechaInicio: start, fechaFin: end, activo: true, categoriaId: 1, metodoPagoId: 1, categoria: Categoria.fallback[0], metodoPago: .placeholder)
        #expect(rule.nextChargeDate == nil)
        rule.activo = false
        rule.scheduledNextDate = "2030-02-10"
        #expect(rule.nextChargeDate == nil)
    }

    @Test func recurringUpdateEncodesYearAndExplicitNullEndDate() throws {
        let payload = CreateRecurringExpensePayload(descripcion: "Anual", monto: 10, categoriaId: 1, metodoPagoId: 1, annualMonth: 2, frecuencia: "anual", diaSemana: nil, diaMes: 28, fechaInicio: "2026-02-01", fechaFin: nil, activo: true)
        let json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(payload)) as? [String: Any])
        #expect(json["mes_anual"] as? Int == 2)
        #expect(json["fecha_fin"] is NSNull)
        #expect(json["impuesto_exterior"] is NSNull)
    }

    @Test func offlineDraftRetainsExtrasAfterEditingAndRestart() throws {
        let date = try #require(AppDateCodec.dateOnly(from: "2026-10-10"))
        let tax = ForeignTax(base: 10, selected: ["isd"], customRate: "")
        let draft = PendingExpenseDraft(id: "draft", localExpenseID: -1, descripcion: "Original", monto: tax.total, fecha: date, categoriaId: 1, metodoPagoId: 1, tags: ["exterior"], foreignTax: tax)
        let updated = draft.updated(descripcion: "Editado", monto: tax.total, fecha: date, categoriaId: 1, metodoPagoId: 1, tags: ["exterior", "viaje"], foreignTax: tax)
        let restored = try JSONDecoder().decode(PendingExpenseDraft.self, from: JSONEncoder().encode(updated))
        #expect(restored.foreignTax == tax)
        #expect(restored.tags == ["exterior", "viaje"])
        #expect(restored.payload.foreignTax == tax)
        #expect(restored.asExpense(categorias: Categoria.fallback, metodosPago: ExpensePaymentMethod.fallback).monto == 10.5)
        var oldJSON = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(draft)) as? [String: Any])
        oldJSON.removeValue(forKey: "tags"); oldJSON.removeValue(forKey: "foreignTax")
        let old = try JSONDecoder().decode(PendingExpenseDraft.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        #expect(old.tags == nil)
        #expect(old.foreignTax == nil)
    }

    @Test func disabledEmailResponseDecodesWithoutPagination() throws {
        let page = try JSONDecoder().decode(EmailReviewPage.self, from: Data(#"{"enabled":false,"pendientes":[]}"#.utf8))
        #expect(!page.enabled)
        #expect(page.pages == nil)
    }
}
