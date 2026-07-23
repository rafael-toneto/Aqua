import Foundation

extension Notification.Name {
    static let hydrationEntriesDidChange = Notification.Name("hydrationEntriesDidChange")
    static let hydrationPlanDidChange = Notification.Name("hydrationPlanDidChange")
    static let hydrationGoalDidChange = Notification.Name("hydrationGoalDidChange")
}

@MainActor
protocol PlanningPreferencesStoring: AnyObject {
    var preferences: PlanningPreferences { get }
    func update(_ preferences: PlanningPreferences) throws
}

@MainActor
final class PlanningPreferencesStore: PlanningPreferencesStoring {
    private enum Key {
        static let planningPreferences = "hydration.planningPreferences.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    nonisolated deinit {}

    var preferences: PlanningPreferences {
        guard let data = userDefaults.data(forKey: Key.planningPreferences),
              let decoded = try? decoder.decode(PlanningPreferences.self, from: data),
              decoded.isValid else {
            return .defaults
        }
        return decoded
    }

    func update(_ preferences: PlanningPreferences) throws {
        guard preferences.isValid else { throw HydrationError.invalidPlanningPreferences }
        userDefaults.set(try encoder.encode(preferences), forKey: Key.planningPreferences)
    }
}
