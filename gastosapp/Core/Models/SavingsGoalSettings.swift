import Foundation

enum SavingsGoalSettings {
    static let enabledKey = "zenlor.savingsGoal.enabled"
    static let monthlyTargetKey = "zenlor.savingsGoal.monthlyTarget"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false
    }

    static var monthlyTarget: Double {
        UserDefaults.standard.double(forKey: monthlyTargetKey)
    }
}
