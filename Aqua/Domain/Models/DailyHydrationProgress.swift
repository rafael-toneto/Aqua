import Foundation

struct DailyHydrationProgress: Equatable, Sendable {
    let consumedAmount: Double
    let dailyGoal: Double
    let remainingAmount: Double
    let completionPercentage: Double
    let hasReachedGoal: Bool

    init(consumedAmount: Double, dailyGoal: Double) {
        let safeConsumedAmount = consumedAmount.isFinite ? max(consumedAmount, 0) : 0
        let safeDailyGoal = dailyGoal.isFinite ? max(dailyGoal, 0) : 0

        self.consumedAmount = safeConsumedAmount
        self.dailyGoal = safeDailyGoal
        remainingAmount = max(safeDailyGoal - safeConsumedAmount, 0)
        hasReachedGoal = safeDailyGoal > 0 && safeConsumedAmount >= safeDailyGoal

        if safeDailyGoal > 0 {
            completionPercentage = min((safeConsumedAmount / safeDailyGoal) * 100, 100)
        } else {
            completionPercentage = 0
        }
    }

    static func calculate(entries: [HydrationEntry], dailyGoal: Double) -> Self {
        let consumedAmount = entries.reduce(0) { total, entry in
            total + entry.amountInMilliliters
        }

        return Self(consumedAmount: consumedAmount, dailyGoal: dailyGoal)
    }
}
