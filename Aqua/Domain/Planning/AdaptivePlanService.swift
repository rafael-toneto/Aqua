import Foundation

enum DailyPlanLoadResult: Sendable, Equatable {
    case plan(DailyHydrationPlan)
    case completed(DailyHydrationPlan?)
    case outsideActiveHours(DailyHydrationPlan?)
}

@MainActor
final class AdaptivePlanService {
    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let preferencesStore: any PlanningPreferencesStoring
    private let repository: any DailyPlanRepository
    private let adaptiveGenerator: any AdaptivePlanGenerating
    private let fallbackGenerator: any AdaptivePlanGenerating
    private let contextBuilder: DailyPlanContextBuilder
    private let validator: any DailyPlanValidating
    private let normalizer: DailyPlanNormalizer
    private let reconciler: any DailyPlanReconciling
    private let periodPlanner: DailyPlanPeriodPlanner
    private let calendar: Calendar
    private var latestPreparationID: UUID?

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        preferencesStore: any PlanningPreferencesStoring,
        repository: any DailyPlanRepository,
        adaptiveGenerator: any AdaptivePlanGenerating,
        fallbackGenerator: any AdaptivePlanGenerating,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.preferencesStore = preferencesStore
        self.repository = repository
        self.adaptiveGenerator = adaptiveGenerator
        self.fallbackGenerator = fallbackGenerator
        self.calendar = calendar
        contextBuilder = DailyPlanContextBuilder(calendar: calendar)
        validator = DailyPlanValidator(calendar: calendar)
        normalizer = DailyPlanNormalizer()
        reconciler = DailyPlanReconciler(calendar: calendar)
        periodPlanner = DailyPlanPeriodPlanner(calendar: calendar)
    }

    var planningPreferences: PlanningPreferences {
        preferencesStore.preferences
    }

    func updatePlanningPreferences(_ preferences: PlanningPreferences) throws {
        try preferencesStore.update(preferences)
    }

    func preparePlan(
        now: Date,
        forceRegeneration: Bool = false,
        allowsAdaptiveRegeneration: Bool = true
    ) async throws -> DailyPlanLoadResult {
        let preparationID = UUID()
        latestPreparationID = preparationID
        try Task.checkCancellation()
        let day = calendar.startOfDay(for: now)
        let entries = try await trackingService.entries(for: now)
        try ensureLatestPreparation(preparationID)
        let preferences = preferencesStore.preferences
        let storedPlan = try repository.plan(for: day)
        var context = contextBuilder.build(
            now: now,
            dailyGoalMilliliters: goalService.dailyGoalInMilliliters,
            entries: entries,
            preferences: preferences,
            existingPlan: storedPlan
        )

        if context.remainingMilliliters == 0 {
            if let storedPlan {
                if forceRegeneration
                    || storedPlan.goalMilliliters != context.dailyGoalMilliliters {
                    let plan = periodOnlyPlan(
                        context: context,
                        preferences: preferences,
                        now: now,
                        replacing: storedPlan
                    )
                    try ensureLatestPreparation(preparationID)
                    try repository.save(plan)
                    return .completed(plan)
                }
                let result = reconciler.reconcile(
                    plan: storedPlan,
                    entries: context.todayEntries,
                    now: now
                )
                let synchronizedPlan = synchronizePeriodTargets(
                    in: result.plan,
                    entries: context.todayEntries,
                    preferences: preferences,
                    now: now
                )
                try ensureLatestPreparation(preparationID)
                if result.didChange || synchronizedPlan != result.plan {
                    try repository.save(synchronizedPlan)
                }
                return .completed(synchronizedPlan)
            }
            let plan = periodOnlyPlan(
                context: context,
                preferences: preferences,
                now: now
            )
            try ensureLatestPreparation(preparationID)
            try repository.save(plan)
            return .completed(plan)
        }

        guard context.isWithinActiveHours, context.remainingActiveMinutes > 0 else {
            if let storedPlan {
                if forceRegeneration
                    || storedPlan.goalMilliliters != context.dailyGoalMilliliters {
                    let plan = periodOnlyPlan(
                        context: context,
                        preferences: preferences,
                        now: now,
                        replacing: storedPlan
                    )
                    try ensureLatestPreparation(preparationID)
                    try repository.save(plan)
                    return .outsideActiveHours(plan)
                }
                let reconciliation = reconciler.reconcile(
                    plan: storedPlan,
                    entries: context.todayEntries,
                    now: now
                )
                let synchronizedPlan = synchronizePeriodTargets(
                    in: reconciliation.plan,
                    entries: context.todayEntries,
                    preferences: preferences,
                    now: now
                )
                try ensureLatestPreparation(preparationID)
                if reconciliation.didChange || synchronizedPlan != reconciliation.plan {
                    try repository.save(synchronizedPlan)
                }
                return .outsideActiveHours(synchronizedPlan)
            }
            let plan = periodOnlyPlan(
                context: context,
                preferences: preferences,
                now: now
            )
            try ensureLatestPreparation(preparationID)
            try repository.save(plan)
            return .outsideActiveHours(plan)
        }

        var reconciledPlan: DailyHydrationPlan?
        var shouldRedistribute = false
        if let storedPlan {
            let reconciliation = reconciler.reconcile(
                plan: storedPlan,
                entries: context.todayEntries,
                now: now
            )
            let synchronizedPlan = synchronizePeriodTargets(
                in: reconciliation.plan,
                entries: context.todayEntries,
                preferences: preferences,
                now: now
            )
            reconciledPlan = synchronizedPlan
            shouldRedistribute = reconciliation.needsRedistribution

            if !allowsAdaptiveRegeneration {
                try ensureLatestPreparation(preparationID)
                if reconciliation.didChange || synchronizedPlan != reconciliation.plan {
                    try repository.save(synchronizedPlan)
                }
                return .plan(synchronizedPlan)
            }

            let goalChanged = reconciliation.plan.goalMilliliters != context.dailyGoalMilliliters

            if !forceRegeneration
                && !goalChanged {
                try ensureLatestPreparation(preparationID)
                if reconciliation.didChange || synchronizedPlan != reconciliation.plan {
                    try repository.save(synchronizedPlan)
                }
                return .plan(synchronizedPlan)
            }
        }

        try Task.checkCancellation()
        context = contextBuilder.build(
            now: now,
            dailyGoalMilliliters: goalService.dailyGoalInMilliliters,
            entries: entries,
            preferences: preferences,
            existingPlan: reconciledPlan
        )
        let constraints = DailyPlanConstraints.make(from: context)
        let generated = try await generateValidatedDraft(context: context, constraints: constraints)
        try Task.checkCancellation()
        try ensureLatestPreparation(preparationID)

        let newRevision = (reconciledPlan?.revision ?? -1) + 1
        let historicalMoments = reconciledPlan?.moments.filter { moment in
            moment.status == .completed
                || moment.status == .missed
                || moment.status == .partiallyCompleted
        } ?? []
        let generatedReason = resolvedReason(
            reconciledPlan: reconciledPlan,
            shouldRedistribute: shouldRedistribute,
            now: now
        )
        let newMoments = generated.draft.moments.enumerated().map { index, draftMoment in
            let scheduledDate = calendar.date(
                byAdding: .minute,
                value: draftMoment.minutesFromStart,
                to: context.planningStart
            ) ?? context.planningStart
            let isCurrent = index == 0 && scheduledDate.timeIntervalSince(now) <= 15 * 60
            return HydrationPlanMoment(
                id: UUID(),
                scheduledDate: scheduledDate,
                plannedMilliliters: draftMoment.amountMilliliters,
                completedMilliliters: 0,
                status: isCurrent ? .current : (newRevision == 0 ? .upcoming : .adjusted),
                originalPlannedMilliliters: nil,
                originalScheduledDate: nil,
                generatedReason: generatedReason,
                rationale: safeRationale(draftMoment.rationale),
                generatedRevision: newRevision
            )
        }
        let plan = DailyHydrationPlan(
            id: reconciledPlan?.id ?? UUID(),
            calendarDay: context.calendarDay,
            createdAt: reconciledPlan?.createdAt ?? now,
            updatedAt: now,
            goalMilliliters: context.dailyGoalMilliliters,
            consumedMillilitersAtGeneration: context.consumedMilliliters,
            moments: (historicalMoments + newMoments).sorted { $0.scheduledDate < $1.scheduledDate },
            revision: newRevision,
            generationSource: generated.source,
            adjustmentSummary: safeExplanation(
                generated.draft.explanation,
                momentCount: newMoments.count,
                isAdjustment: newRevision > 0
            ),
            wasNormalized: generated.wasNormalized,
            periodTargets: periodPlanner.initialTargets(
                goalMilliliters: context.dailyGoalMilliliters,
                entries: context.todayEntries,
                moments: newMoments,
                preferences: preferences
            )
        )
        try repository.save(plan)
        return .plan(plan)
    }

    func addPlannedAmount(
        for moment: HydrationPlanMoment,
        in plan: DailyHydrationPlan,
        now: Date
    ) async throws -> DailyPlanLoadResult {
        guard moment.remainingMilliliters > 0 else {
            return try await preparePlan(now: now)
        }
        try await trackingService.addWater(
            amountInMilliliters: Double(moment.remainingMilliliters),
            date: now,
            source: .plan,
            planMomentID: moment.id,
            planRevision: plan.revision
        )
        return try await preparePlan(
            now: now,
            allowsAdaptiveRegeneration: false
        )
    }

    private func generateValidatedDraft(
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) async throws -> (draft: GeneratedDailyPlanDraft, source: PlanGenerationSource, wasNormalized: Bool) {
        do {
            let draft = try await adaptiveGenerator.generatePlan(from: context, constraints: constraints)
            if validator.validate(draft: draft, context: context, constraints: constraints).isValid {
                return (draft, .foundationModels, false)
            }
            let normalized = normalizer.normalize(draft, context: context, constraints: constraints)
            if !normalized.isSubstantiallyInvalid,
               validator.validate(
                   draft: normalized.draft,
                   context: context,
                   constraints: constraints
               ).isValid {
                return (normalized.draft, .foundationModels, normalized.didNormalize)
            }
        } catch {
            // Model availability and generation failures intentionally fall through.
        }

        do {
            let fallback = try await fallbackGenerator.generatePlan(from: context, constraints: constraints)
            if validator.validate(draft: fallback, context: context, constraints: constraints).isValid {
                return (fallback, .deterministicFallback, false)
            }
        } catch {
            // The empty draft below is handled as an unavailable plan by the caller's UI.
        }
        throw PlanGenerationError.invalidFallback
    }

    private func resolvedReason(
        reconciledPlan: DailyHydrationPlan?,
        shouldRedistribute: Bool,
        now: Date
    ) -> PlanMomentReason {
        if reconciledPlan == nil { return .initialDistribution }
        if shouldRedistribute {
            return reconciledPlan?.moments.contains(where: { $0.status == .partiallyCompleted }) == true
                ? .partialCompletionRedistribution
                : .missedMomentRedistribution
        }
        if calendar.component(.hour, from: now) >= 18 { return .lateDayAdjustment }
        return .remainingGoal
    }

    private func safeRationale(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 160, !containsMedicalClaim(trimmed) else { return nil }
        return trimmed
    }

    private func safeExplanation(_ text: String, momentCount: Int, isAdjustment: Bool) -> String {
        let fallback = isAdjustment
            ? "Your remaining goal was redistributed across the rest of today."
            : "Your remaining goal was divided across the rest of your active day."
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 220, !containsMedicalClaim(trimmed) else {
            return fallback
        }

        let numberWords = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
        let lowercase = trimmed.lowercased()
        for (index, word) in numberWords.enumerated()
            where lowercase.contains("\(word) moment") && index + 1 != momentCount {
            return fallback
        }
        return trimmed
    }

    private func containsMedicalClaim(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return ["medical", "clinically", "optimal for your body", "healthy", "expert-recommended"]
            .contains(where: lowered.contains)
    }

    private func synchronizePeriodTargets(
        in plan: DailyHydrationPlan,
        entries: [HydrationEntrySnapshot],
        preferences: PlanningPreferences,
        now: Date
    ) -> DailyHydrationPlan {
        var updatedPlan = plan
        let currentMoments = plan.moments.filter {
            $0.generatedRevision == plan.revision && $0.status != .cancelled
        }
        let targets = plan.periodTargets ?? periodPlanner.initialTargets(
            goalMilliliters: plan.goalMilliliters,
            entries: entries,
            moments: currentMoments,
            preferences: preferences
        )
        updatedPlan.periodTargets = periodPlanner.synchronizedTargets(
            targets,
            entries: entries,
            goalMilliliters: plan.goalMilliliters,
            now: now,
            automaticRedistributionEnabled: preferences.automaticRedistributionEnabled
        )
        let periodAdjustmentSummary = "Later period goals were updated to keep today’s daily goal on track."
        if updatedPlan.periodTargets?.contains(where: \.wasAdjusted) == true {
            updatedPlan.adjustmentSummary = periodAdjustmentSummary
        } else if updatedPlan.adjustmentSummary == periodAdjustmentSummary {
            updatedPlan.adjustmentSummary = nil
        }
        return updatedPlan
    }

    private func periodOnlyPlan(
        context: DailyPlanContext,
        preferences: PlanningPreferences,
        now: Date,
        replacing existingPlan: DailyHydrationPlan? = nil
    ) -> DailyHydrationPlan {
        DailyHydrationPlan(
            id: existingPlan?.id ?? UUID(),
            calendarDay: context.calendarDay,
            createdAt: existingPlan?.createdAt ?? now,
            updatedAt: now,
            goalMilliliters: context.dailyGoalMilliliters,
            consumedMillilitersAtGeneration: context.consumedMilliliters,
            moments: [],
            revision: (existingPlan?.revision ?? -1) + 1,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false,
            periodTargets: periodPlanner.initialTargets(
                goalMilliliters: context.dailyGoalMilliliters,
                entries: context.todayEntries,
                moments: [],
                preferences: preferences
            )
        )
    }

    private func ensureLatestPreparation(_ preparationID: UUID) throws {
        guard latestPreparationID == preparationID else {
            throw CancellationError()
        }
        try Task.checkCancellation()
    }
}
