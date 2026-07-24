import Foundation

protocol AdaptivePlanGenerating: Sendable {
    func generatePlan(
        from context: DailyPlanContext,
        preferences: PlanningPreferences,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft
}

struct DeterministicAdaptivePlanGenerator: AdaptivePlanGenerating {
    func generatePlan(
        from context: DailyPlanContext,
        preferences: PlanningPreferences,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft {
        guard preferences.isValid, context.reflects(preferences) else {
            throw PlanGenerationError.invalidFallback
        }
        let distribution = try DailyPlanDistributionPolicy().makeDistribution(
            context: context,
            constraints: constraints
        )

        return GeneratedDailyPlanDraft(
            moments: distribution.moments,
            explanation: "The remaining goal was divided across the rest of your active day."
        )
    }
}

extension DailyPlanContext {
    func reflects(_ preferences: PlanningPreferences) -> Bool {
        let expectedStart = calendar.date(
            byAdding: .minute,
            value: preferences.activeDayStartMinutes,
            to: calendarDay
        )
        let expectedEnd = calendar.date(
            byAdding: .minute,
            value: preferences.activeDayEndMinutes,
            to: calendarDay
        )
        return activeDayStart == expectedStart
            && activeDayEnd == expectedEnd
            && preferredMomentCount == preferences.preferredMomentCount
            && preferredAmountMilliliters == preferences.preferredAmountMilliliters
            && minimumIntervalMinutes == preferences.minimumIntervalMinutes
    }
}
