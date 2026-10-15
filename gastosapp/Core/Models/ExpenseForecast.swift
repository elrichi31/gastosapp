import Foundation

struct ExpenseForecast: Decodable {
    struct Range: Decodable { let low: Double; let high: Double }
    struct Point: Decodable, Identifiable {
        let day: Int
        let date: String
        let actual: Double?
        let forecast: Double?
        let previous: Double?
        var id: Int { day }
    }
    struct Category: Decodable, Identifiable {
        let name: String
        let recorded: Double
        let previous: Double
        let projected: Double?
        var id: String { name }
    }
    struct Backtest: Decodable, Identifiable {
        let month: String
        let actual: Double
        let predictions: [String: Double]
        var id: String { month }
    }
    struct Model: Decodable, Identifiable {
        let method: String
        let label: String
        let projected: Double
        let mae: Double?
        let wape: Double?
        var id: String { method }
    }
    struct Upcoming: Decodable, Identifiable {
        let ruleId: Int
        let description: String
        let date: String
        let amount: Double
        var id: String { "\(ruleId)-\(date)" }
    }
    struct Previous: Decodable { let month: String; let total: Double }
    let today: String
    let month: String
    let days: Int
    let recorded: Double
    let recordedToDate: Double
    let futureRecorded: Double
    let committed: Double
    let variableRemaining: Double?
    let projected: Double?
    let floor: Double
    let range: Range?
    let method: String?
    let methodLabel: String?
    let errorTypical: Double?
    let status: String
    let trainingMonths: [String]
    let backtest: [Backtest]
    let models: [Model]
    let points: [Point]
    let upcoming: [Upcoming]
    let warnings: [String]
    let previous: Previous?
    let dailyAllowance: Double?
    let categories: [Category]
}
