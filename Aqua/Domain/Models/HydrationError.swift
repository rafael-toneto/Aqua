import Foundation

enum HydrationError: LocalizedError, Equatable {
    case invalidAmount
    case amountExceedsSingleEntryLimit
    case invalidDailyGoal
    case dailyGoalExceedsLimit
    case invalidQuickAddAmounts
    case quickAddAmountExceedsLimit
    case invalidPlanningPreferences

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            "Enter an amount greater than zero."
        case .amountExceedsSingleEntryLimit:
            "A single water entry cannot exceed 30 L."
        case .invalidDailyGoal:
            "Enter a daily goal greater than zero."
        case .dailyGoalExceedsLimit:
            "The daily water goal cannot exceed 30 L."
        case .invalidQuickAddAmounts:
            "Enter an amount greater than zero for every quick-add slot."
        case .quickAddAmountExceedsLimit:
            "A quick-add amount cannot exceed 30 L."
        case .invalidPlanningPreferences:
            "Check the active hours and planning values, then try again."
        }
    }
}
