import SwiftData
import XCTest
@testable import Aqua

@MainActor
final class DailyPlanPersistenceTests: XCTestCase {
    func testPlanningPreferencesPersistLocally() throws {
        let suiteName = "DailyPlanPersistenceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        var preferences = PlanningPreferences.defaults
        preferences.activeDayEndMinutes = 21 * 60
        preferences.preferredMomentCount = 5

        try PlanningPreferencesStore(userDefaults: defaults).update(preferences)
        let reopened = PlanningPreferencesStore(userDefaults: defaults)

        XCTAssertEqual(reopened.preferences, preferences)
    }

    func testLegacyAdjustmentSettingsDoNotPreventPreferencesFromDecoding() throws {
        let data = try XCTUnwrap(
            """
            {
              "activeDayStartMinutes": 480,
              "activeDayEndMinutes": 1260,
              "preferredMomentCount": 5,
              "minimumIntervalMinutes": 75,
              "preferredAmountMilliliters": 550,
              "automaticRedistributionEnabled": true,
              "mayAddMoments": false
            }
            """.data(using: .utf8)
        )

        let decoded = try JSONDecoder().decode(PlanningPreferences.self, from: data)

        XCTAssertEqual(decoded.activeDayStartMinutes, 480)
        XCTAssertEqual(decoded.activeDayEndMinutes, 1260)
        XCTAssertEqual(decoded.preferredMomentCount, 5)
        XCTAssertEqual(decoded.minimumIntervalMinutes, 75)
        XCTAssertEqual(decoded.preferredAmountMilliliters, 550)
    }

    func testInvalidPlanningPreferencesAreRejected() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayEndMinutes = preferences.activeDayStartMinutes
        XCTAssertFalse(preferences.isValid)
    }

    func testDailyCadenceIsPresentedAsCheckpointsPerActivePeriod() {
        let preferences = PlanningPreferences.defaults

        XCTAssertEqual(preferences.preferredMomentCount, 6)
        XCTAssertEqual(preferences.preferredCheckpointsPerActivePeriod, 2)
    }

    func testCheckpointPreferenceTracksOnlyActivePeriods() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 12 * 60
        preferences.activeDayEndMinutes = 18 * 60
        preferences.setPreferredCheckpointsPerActivePeriod(3)

        XCTAssertEqual(preferences.preferredCheckpointsPerActivePeriod, 3)
        XCTAssertEqual(preferences.preferredMomentCount, 3)
    }

    func testSwiftDataRepositoryKeepsOneActivePlanPerDayAndUpdatesRevision() throws {
        let container = try ModelContainer(
            for: SwiftDataHydrationEntry.self,
            SwiftDataDailyPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = SwiftDataDailyPlanRepository(modelContext: container.mainContext)
        let calendar = fixedCalendar()
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 22)) ?? .distantPast
        var plan = makePlan(day: day)
        try repository.save(plan)
        plan.revision = 1
        plan.updatedAt = day.addingTimeInterval(60)
        try repository.save(plan)

        let descriptor = FetchDescriptor<SwiftDataDailyPlan>()
        XCTAssertEqual(try container.mainContext.fetchCount(descriptor), 1)
        XCTAssertEqual(try repository.plan(for: day)?.revision, 1)
    }

    func testPlanCanBeDecodedByReopenedRepository() throws {
        let container = try ModelContainer(
            for: SwiftDataHydrationEntry.self,
            SwiftDataDailyPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let calendar = fixedCalendar()
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 22)) ?? .distantPast
        let plan = makePlan(day: day)
        try SwiftDataDailyPlanRepository(modelContext: container.mainContext).save(plan)

        let reopened = SwiftDataDailyPlanRepository(modelContext: container.mainContext)
        XCTAssertEqual(try reopened.plan(for: day), plan)
    }

    func testHydrationEntryPlanMetadataRoundTripsThroughSwiftData() async throws {
        let container = try ModelContainer(
            for: SwiftDataHydrationEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let calendar = fixedCalendar()
        let date = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 10)
        ) ?? .distantPast
        let momentID = UUID()
        let repository = SwiftDataHydrationRepository(modelContext: container.mainContext)
        try await repository.add(
            HydrationEntry(
                amountInMilliliters: 300,
                date: date,
                source: .plan,
                planMomentID: momentID,
                planRevision: 2
            )
        )
        let entries = try await repository.entries(for: date, calendar: calendar)
        let stored = try XCTUnwrap(entries.first)
        XCTAssertEqual(stored.planMomentID, momentID)
        XCTAssertEqual(stored.planRevision, 2)
        XCTAssertEqual(stored.source, .plan)
    }

    private func makePlan(day: Date) -> DailyHydrationPlan {
        DailyHydrationPlan(
            id: UUID(),
            calendarDay: day,
            createdAt: day,
            updatedAt: day,
            goalMilliliters: 2_000,
            consumedMillilitersAtGeneration: 0,
            moments: [],
            revision: 0,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false
        )
    }
}
