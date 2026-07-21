import Foundation

enum HydrationError: LocalizedError, Equatable {
    case invalidAmount
    case invalidDailyGoal

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            "Enter an amount greater than zero."
        case .invalidDailyGoal:
            "Enter a daily goal greater than zero."
        }
    }
}
