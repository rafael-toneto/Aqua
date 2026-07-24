import Foundation
@testable import Aqua

@MainActor
final class FakeHydrationRepository: HydrationRepository {
    var storedEntries: [HydrationEntry]

    init(entries: [HydrationEntry] = []) {
        storedEntries = entries
    }

    func add(_ entry: HydrationEntry) async throws {
        storedEntries.append(entry)
    }

    func deleteEntry(id: UUID) async throws {
        storedEntries.removeAll { $0.id == id }
    }

    func entries(for date: Date, calendar: Calendar) async throws -> [HydrationEntry] {
        storedEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func entries(from startDate: Date, to endDate: Date) async throws -> [HydrationEntry] {
        storedEntries
            .filter { $0.date >= startDate && $0.date < endDate }
            .sorted { $0.date < $1.date }
    }
}

struct FixedDateProvider: DateProviding {
    let now: Date
}

@MainActor
final class InMemoryHydrationPreferencesStore: HydrationPreferencesStoring {
    var dailyGoalInMilliliters: Double
    var quickAddAmountsInMilliliters: [Double]

    init() {
        dailyGoalInMilliliters = HydrationDefaults.dailyGoalInMilliliters
        quickAddAmountsInMilliliters = HydrationDefaults.quickAddAmountsInMilliliters
    }

    init(dailyGoalInMilliliters: Double) {
        self.dailyGoalInMilliliters = dailyGoalInMilliliters
        quickAddAmountsInMilliliters = HydrationDefaults.quickAddAmountsInMilliliters
    }
}

@MainActor
final class InMemoryPlanningPreferencesStore: PlanningPreferencesStoring {
    var preferences: PlanningPreferences

    init(preferences: PlanningPreferences) {
        self.preferences = preferences
    }

    convenience init() {
        self.init(preferences: .defaults)
    }

    func update(_ preferences: PlanningPreferences) throws {
        guard preferences.isValid else { throw HydrationError.invalidPlanningPreferences }
        self.preferences = preferences
    }
}

@MainActor
final class InMemoryDailyPlanRepository: DailyPlanRepository {
    var plansByDay: [Date: DailyHydrationPlan] = [:]
    private let calendar: Calendar

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    convenience init() {
        self.init(calendar: fixedCalendar())
    }

    func plan(for calendarDay: Date) throws -> DailyHydrationPlan? {
        plansByDay[calendar.startOfDay(for: calendarDay)]
    }

    func save(_ plan: DailyHydrationPlan) throws {
        plansByDay[calendar.startOfDay(for: plan.calendarDay)] = plan
    }
}

@MainActor
final class MockAdaptivePlanGenerator: AdaptivePlanGenerating, @unchecked Sendable {
    var callCount = 0
    var receivedPreferences: [PlanningPreferences] = []
    var result: Result<GeneratedDailyPlanDraft, Error>
    var delay: Duration?

    init(result: Result<GeneratedDailyPlanDraft, Error>) {
        self.result = result
    }

    func generatePlan(
        from context: DailyPlanContext,
        preferences: PlanningPreferences,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft {
        callCount += 1
        receivedPreferences.append(preferences)
        if let delay { try await Task.sleep(for: delay) }
        return try result.get()
    }
}

@MainActor
final class MockHydrationInsightsGenerator: HydrationInsightsGenerating, @unchecked Sendable {
    var callCount = 0
    var result: Result<[HydrationInsight], Error>
    var delay: Duration?

    init(result: Result<[HydrationInsight], Error>) {
        self.result = result
    }

    func generateInsights(
        from snapshot: HydrationInsightsSnapshot
    ) async throws -> [HydrationInsight] {
        callCount += 1
        if let delay { try await Task.sleep(for: delay) }
        return try result.get()
    }
}

struct ValidHydrationInsightsGenerator: HydrationInsightsGenerating {
    func generateInsights(
        from snapshot: HydrationInsightsSnapshot
    ) async throws -> [HydrationInsight] {
        let definitions: [(
            category: HydrationInsightCategory,
            metric: HydrationInsightEvidenceMetric,
            title: String
        )] = [
            (.consistency, .daysWithoutEntries, "Build a steady rhythm"),
            (.timing, .firstEntryTime, "Anchor the first entry"),
            (.goalProgress, .goalAchievement, "Keep goal progress visible")
        ]

        return definitions.map { definition in
            HydrationInsight(
                id: "\(definition.category.rawValue).\(definition.metric.rawValue)",
                title: definition.title,
                description: "This pattern is based on recent aggregate history.",
                evidence: snapshot.evidence(for: definition.metric),
                evidenceMetric: definition.metric,
                suggestedAction: "Use the existing plan as a practical cue.",
                category: definition.category,
                priority: .medium
            )
        }
    }
}

@MainActor
final class MutableDateProvider: DateProviding {
    var now: Date

    init(now: Date) {
        self.now = now
    }
}

@MainActor
func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}
