import Foundation
import FoundationModels

@Generable(description: "A draft schedule that organizes only the supplied remaining hydration goal.")
private struct FoundationGeneratedDailyPlanDraft {
    @Guide(
        description: "Future hydration moments in chronological order, within the supplied active window.",
        .maximumCount(24)
    )
    var moments: [FoundationGeneratedPlanMoment]

    @Guide(description: "A short supportive explanation without medical or health claims.")
    var explanation: String
}

@Generable(description: "One future hydration moment.")
private struct FoundationGeneratedPlanMoment {
    @Guide(description: "Whole minutes from the supplied planning start.", .range(0...1_440))
    var minutesFromStart: Int

    @Guide(description: "A positive whole-number amount in milliliters.", .range(1...10_000))
    var amountMilliliters: Int

    @Guide(description: "A concise rationale based only on the supplied schedule facts.")
    var rationale: String
}

struct FoundationModelsAdaptivePlanGenerator: AdaptivePlanGenerating {
    func generatePlan(
        from context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw PlanGenerationError.unavailable
        }

        let session = LanguageModelSession(model: model, instructions: """
            You organize a hydration goal that the user already selected.
            Organize only the exact remaining amount supplied by the app.
            Never change the goal, invent consumption, or provide medical advice.
            Never describe a plan as healthy, medically optimal, clinical, or expert-recommended.
            Use only future relative minutes within the supplied active window.
            Do not encourage exceeding the remaining amount.
            Return only the requested structured result.
            Prefer practical, reasonably even spacing and avoid concentrating everything at day end.
            Add moments only when the supplied context permits it.
            """)

        let response = try await session.respond(
            to: prompt(context: context, constraints: constraints),
            generating: FoundationGeneratedDailyPlanDraft.self,
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 1_200)
        )

        return GeneratedDailyPlanDraft(
            moments: response.content.moments.map {
                GeneratedPlanMoment(
                    minutesFromStart: $0.minutesFromStart,
                    amountMilliliters: $0.amountMilliliters,
                    rationale: $0.rationale
                )
            },
            explanation: response.content.explanation
        )
    }

    private func prompt(context: DailyPlanContext, constraints: DailyPlanConstraints) -> String {
        let existingMomentCount = context.existingPlan?.moments.filter {
            $0.generatedRevision == context.existingPlan?.revision
        }.count ?? 0
        let activeDayMinutes = max(
            Int(context.activeDayEnd.timeIntervalSince(context.activeDayStart) / 60),
            0
        )
        let nowMinute = Int(context.now.timeIntervalSince(context.activeDayStart) / 60)
        let planningStartMinute = Int(
            context.planningStart.timeIntervalSince(context.activeDayStart) / 60
        )
        return """
            Create the remaining portion of a whole-day schedule using these exact facts and constraints:
            - User-selected daily goal: \(context.dailyGoalMilliliters) ml
            - Already consumed: \(context.consumedMilliliters) ml
            - Exact amount still to organize: \(context.remainingMilliliters) ml
            - Whole active day length: \(activeDayMinutes) minutes
            - Current time is active-day minute: \(nowMinute)
            - Cadence-adjusted planning start is active-day minute: \(planningStartMinute)
            - In the output, that planning start is minute 0
            - Active minutes remaining after planning start: \(context.remainingActiveMinutes)
            - Preferred total moment count for the whole day: \(context.preferredMomentCount)
            - Logged moments so far: \(context.todayEntries.count)
            - Cadence-adjusted preferred remaining moments: \(context.preferredRemainingMomentCount)
            - Preferred amount: \(context.preferredAmountMilliliters) ml
            - Minimum interval: \(constraints.minimumIntervalMinutes) minutes
            - Maximum moments: \(constraints.maximumMomentCount)
            - Application guardrail per moment: \(constraints.maximumMomentMilliliters) ml
            - Existing current-revision moments: \(existingMomentCount)
            - Missed moments: \(context.missedMoments.count)
            - Partially completed moments: \(context.partiallyCompletedMoments.count)
            - Automatic missed-moment redistribution: \(context.automaticRedistributionEnabled)
            - May add moments: \(context.mayAddMoments)

            Hydration already logged today (times are minutes from active-day start):
            \(hydrationHistory(context))

            Existing current-revision schedule being adapted:
            \(existingSchedule(context))

            Every amount must be positive. Moments must be chronological, unique, separated by at
            least the minimum interval, and use offsets from 0 through
            \(max(context.remainingActiveMinutes - 1, 0)). The amounts must total exactly
            \(context.remainingMilliliters) ml. The explanation may describe only this validated
            distribution and must not make health or medical claims. Treat logged events as already
            completed moments and never recreate them. Plan the rest as a continuation of the whole
            active day. Use the user's total moment count, preferred amount, interval, prior drinking
            times, and remaining window as joint scheduling signals. Do not bias the first result
            toward the current time merely because it is the first output item; use the day-wide
            cadence and spread useful moments through the remaining window.

            Required distribution profile:
            \(distributionProfile(context: context, constraints: constraints))

            Follow the required count and milliliter total for every period exactly. Keep individual
            amounts even: use only the listed per-moment amounts. The afternoon is intentionally the
            primary planning window. A period that has already passed must remain empty; never place
            a moment in the past just to fill its target.
            """
    }

    private func distributionProfile(
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) -> String {
        guard let distribution = try? DailyPlanDistributionPolicy().makeDistribution(
            context: context,
            constraints: constraints
        ) else {
            return "- No valid future distribution is available."
        }

        var lines = HydrationDayPeriod.allCases.map { period in
            let count = distribution.momentCount(
                in: period,
                planningStart: context.planningStart,
                calendar: context.calendar
            )
            let amount = distribution.amountMilliliters(
                in: period,
                planningStart: context.planningStart,
                calendar: context.calendar
            )
            return "- \(period.rawValue.capitalized): exactly \(count) moments totaling \(amount) ml"
        }
        let allowedAmounts = Set(distribution.moments.map(\.amountMilliliters)).sorted()
        lines.append("- Exact total moment count: \(distribution.moments.count)")
        lines.append("- Allowed per-moment amounts: \(allowedAmounts.map(String.init).joined(separator: ", ")) ml")
        return lines.joined(separator: "\n")
    }

    private func hydrationHistory(_ context: DailyPlanContext) -> String {
        guard !context.todayEntries.isEmpty else { return "- No hydration logged yet." }
        let sortedEntries = context.todayEntries.sorted { $0.date < $1.date }
        let recentEntries = sortedEntries.suffix(24)
        var lines: [String] = []
        if sortedEntries.count > recentEntries.count {
            lines.append("- \(sortedEntries.count - recentEntries.count) earlier logs omitted; their volume is included in already consumed.")
        }
        lines.append(contentsOf: recentEntries.map { entry in
            let minute = Int(entry.date.timeIntervalSince(context.activeDayStart) / 60)
            return "- Minute \(minute): \(entry.amountMilliliters) ml (\(entry.source.rawValue))"
        })
        return lines.joined(separator: "\n")
    }

    private func existingSchedule(_ context: DailyPlanContext) -> String {
        guard let plan = context.existingPlan else { return "- No previous schedule." }
        let moments = plan.moments
            .filter { $0.generatedRevision == plan.revision }
            .sorted { $0.scheduledDate < $1.scheduledDate }
            .prefix(24)
        guard !moments.isEmpty else { return "- No active previous moments." }
        return moments.map { moment in
            let minute = Int(moment.scheduledDate.timeIntervalSince(context.activeDayStart) / 60)
            return "- Minute \(minute): \(moment.remainingMilliliters) ml remaining (\(moment.status.rawValue))"
        }.joined(separator: "\n")
    }
}
