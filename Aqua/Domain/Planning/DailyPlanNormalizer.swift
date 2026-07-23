import Foundation

struct DailyPlanNormalizationResult: Sendable, Equatable {
    let draft: GeneratedDailyPlanDraft
    let didNormalize: Bool
    let isSubstantiallyInvalid: Bool
}

struct DailyPlanNormalizer: Sendable {
    func normalize(
        _ draft: GeneratedDailyPlanDraft,
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) -> DailyPlanNormalizationResult {
        guard !draft.moments.isEmpty else {
            return DailyPlanNormalizationResult(
                draft: draft,
                didNormalize: false,
                isSubstantiallyInvalid: constraints.remainingMilliliters > 0
            )
        }
        guard draft.moments.allSatisfy({
            $0.amountMilliliters > 0
                && $0.amountMilliliters <= constraints.maximumMomentMilliliters
        }),
              draft.moments.count <= constraints.maximumMomentCount else {
            return DailyPlanNormalizationResult(
                draft: draft,
                didNormalize: false,
                isSubstantiallyInvalid: true
            )
        }

        let latestOffset = max(context.remainingActiveMinutes - 1, 0)
        var moments = draft.moments.map { moment in
            var copy = moment
            copy.minutesFromStart = min(max(copy.minutesFromStart, 0), latestOffset)
            return copy
        }.sorted { $0.minutesFromStart < $1.minutesFromStart }

        guard Set(moments.map(\.minutesFromStart)).count == moments.count else {
            return DailyPlanNormalizationResult(
                draft: draft,
                didNormalize: false,
                isSubstantiallyInvalid: true
            )
        }

        var total = 0
        for moment in moments {
            let result = total.addingReportingOverflow(moment.amountMilliliters)
            guard !result.overflow else {
                return DailyPlanNormalizationResult(
                    draft: draft,
                    didNormalize: false,
                    isSubstantiallyInvalid: true
                )
            }
            total = result.partialValue
        }
        let difference = constraints.remainingMilliliters - total
        guard abs(difference) <= moments.count else {
            return DailyPlanNormalizationResult(
                draft: draft,
                didNormalize: false,
                isSubstantiallyInvalid: true
            )
        }

        if difference != 0 {
            let step = difference > 0 ? 1 : -1
            for index in 0..<abs(difference) {
                moments[index].amountMilliliters += step
            }
        }

        let normalized = GeneratedDailyPlanDraft(
            moments: moments,
            explanation: draft.explanation
        )
        return DailyPlanNormalizationResult(
            draft: normalized,
            didNormalize: normalized != draft,
            isSubstantiallyInvalid: false
        )
    }
}
