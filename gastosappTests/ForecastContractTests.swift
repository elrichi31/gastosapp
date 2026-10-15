import Foundation
import Testing
@testable import Zenlor

private final class ForecastTestResources: NSObject {}

struct ForecastContractTests {
    @Test func decodesActualWebForecastContract() throws {
        let url = try #require(Bundle(for: ForecastTestResources.self).url(forResource: "forecast-web-fixture", withExtension: "json"))
        let forecast = try JSONDecoder().decode(ExpenseForecast.self, from: Data(contentsOf: url))
        #expect(forecast.status == "validated")
        #expect(forecast.committed == 20)
        #expect(forecast.projected != nil)
        #expect(forecast.points.count == 31)
        #expect(forecast.categories.first?.name == "Comida")
        #expect(forecast.backtest.count >= 3)
        #expect(forecast.previous?.month == "2026-09")
    }
}
