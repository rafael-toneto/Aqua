import Foundation

@MainActor
protocol HydrationPreferencesStoring: AnyObject {
    var dailyGoalInMilliliters: Double { get set }
    var quickAddAmountsInMilliliters: [Double] { get set }
}

@MainActor
final class HydrationPreferencesStore: HydrationPreferencesStoring {
    private enum Key {
        static let dailyGoalInMilliliters = "hydration.dailyGoalInMilliliters"
        static let quickAddAmountsInMilliliters = "hydration.quickAddAmountsInMilliliters"
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

    var quickAddAmountsInMilliliters: [Double] {
        get {
            guard let storedValues = userDefaults.array(forKey: Key.quickAddAmountsInMilliliters) else {
                return HydrationDefaults.quickAddAmountsInMilliliters
            }

            let amounts = storedValues.compactMap { ($0 as? NSNumber)?.doubleValue }
            guard amounts.count == HydrationDefaults.quickAddAmountsInMilliliters.count,
                  amounts.allSatisfy({ $0.isFinite && $0 > 0 }) else {
                return HydrationDefaults.quickAddAmountsInMilliliters
            }

            return amounts
        }
        set {
            userDefaults.set(newValue, forKey: Key.quickAddAmountsInMilliliters)
        }
    }
}
