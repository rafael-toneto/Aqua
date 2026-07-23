import Foundation

enum HydrationPlanMomentStatus: String, Codable, Sendable, CaseIterable {
    case completed
    case partiallyCompleted
    case current
    case upcoming
    case missed
    case adjusted
    case cancelled
}

enum PlanMomentReason: String, Codable, Sendable {
    case initialDistribution
    case remainingGoal
    case missedMomentRedistribution
    case partialCompletionRedistribution
    case lateDayAdjustment
    // Retained only so plans created by older builds remain decodable.
    case manuallyRegenerated
}

enum PlanGenerationSource: String, Codable, Sendable {
    case foundationModels
    case deterministicFallback
}

enum DailyPlanRules {
    static let gracePeriodMinutes = 20
}

struct HydrationPlanMoment: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    var scheduledDate: Date
    var plannedMilliliters: Int
    var completedMilliliters: Int
    var status: HydrationPlanMomentStatus
    var originalPlannedMilliliters: Int?
    var originalScheduledDate: Date?
    var generatedReason: PlanMomentReason
    var rationale: String?
    var generatedRevision: Int

    var remainingMilliliters: Int {
        max(plannedMilliliters - completedMilliliters, 0)
    }
}

struct DailyHydrationPlan: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let calendarDay: Date
    let createdAt: Date
    var updatedAt: Date
    let goalMilliliters: Int
    var consumedMillilitersAtGeneration: Int
    var moments: [HydrationPlanMoment]
    var revision: Int
    var generationSource: PlanGenerationSource
    var adjustmentSummary: String?
    var wasNormalized: Bool
    var periodTargets: [HydrationPlanPeriodTarget]? = nil
}

struct HydrationEntrySnapshot: Identifiable, Sendable, Equatable {
    let id: UUID
    let amountMilliliters: Int
    let date: Date
    let source: HydrationEntrySource
    let planMomentID: UUID?
    let planRevision: Int?

    init(entry: HydrationEntry) {
        id = entry.id
        amountMilliliters = Self.safeIntegerMilliliters(entry.amountInMilliliters)
        date = entry.date
        source = entry.source
        planMomentID = entry.planMomentID
        planRevision = entry.planRevision
    }

    private nonisolated static func safeIntegerMilliliters(_ amount: Double) -> Int {
        guard amount.isFinite, amount > 0 else { return 0 }
        let rounded = amount.rounded()
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }
}

struct PlanningPreferences: Codable, Sendable, Equatable {
    var activeDayStartMinutes: Int
    var activeDayEndMinutes: Int
    var preferredMomentCount: Int
    var minimumIntervalMinutes: Int
    var preferredAmountMilliliters: Int
    var automaticRedistributionEnabled: Bool
    var mayAddMoments: Bool

    nonisolated static let defaults = PlanningPreferences(
        activeDayStartMinutes: 8 * 60,
        activeDayEndMinutes: 22 * 60,
        preferredMomentCount: 6,
        minimumIntervalMinutes: 60,
        preferredAmountMilliliters: 400,
        automaticRedistributionEnabled: true,
        mayAddMoments: true
    )

    func requiresPlanRegeneration(comparedTo previous: PlanningPreferences) -> Bool {
        activeDayStartMinutes != previous.activeDayStartMinutes
            || activeDayEndMinutes != previous.activeDayEndMinutes
            || preferredMomentCount != previous.preferredMomentCount
            || minimumIntervalMinutes != previous.minimumIntervalMinutes
            || preferredAmountMilliliters != previous.preferredAmountMilliliters
            || automaticRedistributionEnabled != previous.automaticRedistributionEnabled
            || mayAddMoments != previous.mayAddMoments
    }

    var isValid: Bool {
        (0..<24 * 60).contains(activeDayStartMinutes)
            && (1...24 * 60).contains(activeDayEndMinutes)
            && activeDayStartMinutes < activeDayEndMinutes
            && (1...12).contains(preferredMomentCount)
            && (15...240).contains(minimumIntervalMinutes)
            && (1...10_000).contains(preferredAmountMilliliters)
    }
}

struct DailyPlanContext: Sendable {
    let calendar: Calendar
    let now: Date
    let calendarDay: Date
    let dailyGoalMilliliters: Int
    let consumedMilliliters: Int
    let remainingMilliliters: Int
    let activeDayStart: Date
    let activeDayEnd: Date
    let planningStart: Date
    let remainingActiveMinutes: Int
    let preferredMomentCount: Int
    let preferredRemainingMomentCount: Int
    let preferredAmountMilliliters: Int
    let minimumIntervalMinutes: Int
    let existingPlan: DailyHydrationPlan?
    let todayEntries: [HydrationEntrySnapshot]
    let missedMoments: [HydrationPlanMoment]
    let partiallyCompletedMoments: [HydrationPlanMoment]
    let automaticRedistributionEnabled: Bool
    let mayAddMoments: Bool
    let gracePeriodMinutes: Int

    var isWithinActiveHours: Bool {
        now < activeDayEnd && activeDayStart < activeDayEnd
    }
}

struct GeneratedPlanMoment: Sendable, Equatable {
    var minutesFromStart: Int
    var amountMilliliters: Int
    var rationale: String
}

struct GeneratedDailyPlanDraft: Sendable, Equatable {
    var moments: [GeneratedPlanMoment]
    var explanation: String
}

enum PlanGenerationError: Error, Equatable {
    case unavailable
    case noActiveTimeRemaining
    case invalidFallback
}
