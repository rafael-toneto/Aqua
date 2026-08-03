import Foundation
import XCTest
@testable import Aqua

@MainActor
final class HydrationGoalServiceTests: XCTestCase {
    func testConfiguredGoalPersistsAndCanBeReadByANewStore() async throws {
        let suiteName = "HydrationGoalServiceTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let firstStore = HydrationPreferencesStore(userDefaults: userDefaults)
        let goalService = HydrationGoalService(preferencesStore: firstStore)
        try goalService.updateDailyGoal(to: 2_400)

        let reopenedStore = HydrationPreferencesStore(userDefaults: userDefaults)

        XCTAssertEqual(reopenedStore.dailyGoalInMilliliters, 2_400, accuracy: 0.001)
    }

    func testInvalidGoalIsRejectedWithoutChangingSavedGoal() async {
        let preferences = InMemoryHydrationPreferencesStore(dailyGoalInMilliliters: 2_000)
        let goalService = HydrationGoalService(preferencesStore: preferences)

        XCTAssertThrowsError(try goalService.updateDailyGoal(to: 0)) { error in
            XCTAssertEqual(error as? HydrationError, .invalidDailyGoal)
        }
        XCTAssertEqual(goalService.dailyGoalInMilliliters, 2_000, accuracy: 0.001)
    }

    func testDailyGoalAcceptsThirtyLitersAndRejectsAnythingHigher() async throws {
        let preferences = InMemoryHydrationPreferencesStore(dailyGoalInMilliliters: 2_000)
        let goalService = HydrationGoalService(preferencesStore: preferences)

        try goalService.updateDailyGoal(to: HydrationLimits.maximumDailyGoalInMilliliters)

        XCTAssertEqual(goalService.dailyGoalInMilliliters, 30_000, accuracy: 0.001)
        XCTAssertThrowsError(try goalService.updateDailyGoal(to: 30_000.001)) { error in
            XCTAssertEqual(error as? HydrationError, .dailyGoalExceedsLimit)
        }
        XCTAssertEqual(goalService.dailyGoalInMilliliters, 30_000, accuracy: 0.001)
    }

    func testPreviouslyStoredGoalAboveLimitFallsBackToDefault() async throws {
        let suiteName = "HydrationGoalServiceTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = HydrationPreferencesStore(userDefaults: userDefaults)

        store.dailyGoalInMilliliters = 30_000.001

        XCTAssertEqual(
            store.dailyGoalInMilliliters,
            HydrationDefaults.dailyGoalInMilliliters,
            accuracy: 0.001
        )
    }
}
