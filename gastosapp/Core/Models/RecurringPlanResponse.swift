import Foundation

struct RecurringPlanResponse: Decodable {
    let rules: [RemoteRecurringExpense]
}
