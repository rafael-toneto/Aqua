import Foundation

@MainActor
protocol HydrationGoalServiceProtocol: AnyObject {
    var dailyGoalInMilliliters: Double { get }
    func updateDailyGoal(to amountInMilliliters: Double) throws
}

@MainActor
final class HydrationGoalService: HydrationGoalServiceProtocol {
    private let preferencesStore: any HydrationPreferencesStoring

    init(preferencesStore: any HydrationPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    var dailyGoalInMilliliters: Double {
        preferencesStore.dailyGoalInMilliliters
    }

    func updateDailyGoal(to amountInMilliliters: Double) throws {
        guard amountInMilliliters.isFinite, amountInMilliliters > 0 else {
            throw HydrationError.invalidDailyGoal
        }

        preferencesStore.dailyGoalInMilliliters = amountInMilliliters
        NotificationCenter.default.post(name: .hydrationGoalDidChange, object: nil)
    }
}
