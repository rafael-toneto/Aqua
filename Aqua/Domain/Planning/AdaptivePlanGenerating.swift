import Foundation

protocol AdaptivePlanGenerating: Sendable {
    func generatePlan(
        from context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft
}

struct DeterministicAdaptivePlanGenerator: AdaptivePlanGenerating {
    func generatePlan(
        from context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft {
        let distribution = try DailyPlanDistributionPolicy().makeDistribution(
            context: context,
            constraints: constraints
        )

        let reason: String
        if !context.missedMoments.isEmpty {
            reason = "The remaining goal was redistributed across the rest of today."
        } else if !context.partiallyCompletedMoments.isEmpty {
            reason = "The unfinished amount was redistributed across the remaining moments."
        } else {
            reason = "The remaining goal was divided across the rest of your active day."
        }

        return GeneratedDailyPlanDraft(
            moments: distribution.moments,
            explanation: reason
        )
    }
}
