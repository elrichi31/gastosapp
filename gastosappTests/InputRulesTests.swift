import Foundation
import Testing
@testable import Zenlor

struct JSONRequestTests {
    @Test func mutatingRequestsWithoutBodyAreSentAsJSON() {
        var delete = URLRequest(url: URL(string: "https://example.com/api/gastos?id=1")!)
        delete.httpMethod = "DELETE"
        delete.markAsJSONIfMutating()
        #expect(delete.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(delete.httpBody == Data("{}".utf8))

        var post = URLRequest(url: URL(string: "https://example.com/api/gastos")!)
        post.httpMethod = "POST"
        post.httpBody = Data(#"{"monto":1}"#.utf8)
        post.markAsJSONIfMutating()
        #expect(post.httpBody == Data(#"{"monto":1}"#.utf8))

        var get = URLRequest(url: URL(string: "https://example.com/api/gastos")!)
        get.markAsJSONIfMutating()
        #expect(get.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(get.httpBody == nil)
    }
}

struct MoneyEntryTests {
    @Test func amountEntryKeepsOnlyDigitsAndOneSeparator() {
        #expect(MoneyInput.sanitizedEntry("12.50") == "12.50")
        #expect(MoneyInput.sanitizedEntry("0Almuerzo de prueba") == "0")
        #expect(MoneyInput.sanitizedEntry("1.2.3") == "1.23")
        #expect(MoneyInput.sanitizedEntry("3,999") == "3,99")
        #expect(MoneyInput.sanitizedEntry("12345678901") == "123456789")
    }
}
