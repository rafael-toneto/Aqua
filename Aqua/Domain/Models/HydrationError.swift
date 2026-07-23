import Foundation

enum HydrationError: LocalizedError, Equatable {
    case invalidAmount
    case invalidDailyGoal
    case invalidQuickAddAmounts
    case invalidPlanningPreferences

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            "Enter an amount greater than zero."
        case .invalidDailyGoal:
            "Enter a daily goal greater than zero."
        case .invalidQuickAddAmounts:
            "Enter an amount greater than zero for every quick-add slot."
        case .invalidPlanningPreferences:
            "Check the active hours and planning values, then try again."
        }
    }
}
