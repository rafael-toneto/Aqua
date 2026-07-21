import Foundation

@MainActor
protocol HydrationPreferencesStoring: AnyObject {
    var dailyGoalInMilliliters: Double { get set }
}

@MainActor
final class HydrationPreferencesStore: HydrationPreferencesStoring {
    private enum Key {
        static let dailyGoalInMilliliters = "hydration.dailyGoalInMilliliters"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var dailyGoalInMilliliters: Double {
        get {
            guard userDefaults.object(forKey: Key.dailyGoalInMilliliters) != nil else {
                return HydrationDefaults.dailyGoalInMilliliters
            }

            let storedGoal = userDefaults.double(forKey: Key.dailyGoalInMilliliters)
            return storedGoal.isFinite && storedGoal > 0
                ? storedGoal
                : HydrationDefaults.dailyGoalInMilliliters
        }
        set {
            userDefaults.set(newValue, forKey: Key.dailyGoalInMilliliters)
        }
    }
}
