import Foundation

struct PlanReconciliationResult: Sendable, Equatable {
    let plan: DailyHydrationPlan
    let needsRedistribution: Bool
    let didChange: Bool
}

protocol DailyPlanReconciling: Sendable {
    func reconcile(
        plan: DailyHydrationPlan,
        entries: [HydrationEntrySnapshot],
        now: Date
    ) -> PlanReconciliationResult
}

struct DailyPlanReconciler: DailyPlanReconciling {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func reconcile(
        plan: DailyHydrationPlan,
        entries: [HydrationEntrySnapshot],
        now: Date
    ) -> PlanReconciliationResult {
        let originalPlan = plan
        var updatedPlan = plan
        updatedPlan.moments.removeAll { moment in
            moment.generatedRevision < plan.revision
                && ![.completed, .missed, .partiallyCompleted].contains(moment.status)
        }
        let totalConsumed = entries.reduce(0) { partial, entry in
            let result = partial.addingReportingOverflow(entry.amountMilliliters)
            return result.overflow ? Int.max : result.partialValue
        }

        if totalConsumed >= plan.goalMilliliters {
            for index in updatedPlan.moments.indices where
                updatedPlan.moments[index].generatedRevision == plan.revision
                    && updatedPlan.moments[index].status != .completed {
                updatedPlan.moments[index].status = .cancelled
            }
            updatedPlan.updatedAt = now
            return PlanReconciliationResult(
                plan: updatedPlan,
                needsRedistribution: false,
                didChange: updatedPlan != originalPlan
            )
        }

        let revisionIndices = updatedPlan.moments.indices.filter {
            updatedPlan.moments[$0].generatedRevision == plan.revision
                && updatedPlan.moments[$0].status != .cancelled
        }
        for index in revisionIndices {
            updatedPlan.moments[index].completedMilliliters = 0
        }

        var consumptionToAllocate = max(totalConsumed - plan.consumedMillilitersAtGeneration, 0)

        let linkedEntries = entries
            .filter { $0.planRevision == plan.revision && $0.planMomentID != nil }
            .sorted { $0.date < $1.date }
        for entry in linkedEntries where consumptionToAllocate > 0 {
            guard let momentID = entry.planMomentID,
                  let index = revisionIndices.first(where: {
                      updatedPlan.moments[$0].id == momentID
                  }) else { continue }
            let available = updatedPlan.moments[index].remainingMilliliters
            let allocated = min(entry.amountMilliliters, available, consumptionToAllocate)
            updatedPlan.moments[index].completedMilliliters += allocated
            consumptionToAllocate -= allocated
        }

        for index in revisionIndices.sorted(by: {
            updatedPlan.moments[$0].scheduledDate < updatedPlan.moments[$1].scheduledDate
        }) where consumptionToAllocate > 0 {
            let available = updatedPlan.moments[index].remainingMilliliters
            let allocated = min(available, consumptionToAllocate)
            updatedPlan.moments[index].completedMilliliters += allocated
            consumptionToAllocate -= allocated
        }

        var needsRedistribution = false
        let graceInterval = TimeInterval(DailyPlanRules.gracePeriodMinutes * 60)
        let currentLeadInterval: TimeInterval = 15 * 60

        for index in revisionIndices {
            let moment = updatedPlan.moments[index]
            let graceEnd = moment.scheduledDate.addingTimeInterval(graceInterval)

            if moment.completedMilliliters >= moment.plannedMilliliters {
                updatedPlan.moments[index].status = .completed
            } else if now > graceEnd {
                if moment.completedMilliliters > 0 {
                    updatedPlan.moments[index].status = .partiallyCompleted
                } else {
                    updatedPlan.moments[index].status = .missed
                }
                needsRedistribution = true
            } else if now >= moment.scheduledDate.addingTimeInterval(-currentLeadInterval) {
                updatedPlan.moments[index].status = moment.completedMilliliters > 0
                    ? .partiallyCompleted
                    : .current
            } else if moment.status != .adjusted {
                updatedPlan.moments[index].status = .upcoming
            }
        }

        updatedPlan.updatedAt = now
        return PlanReconciliationResult(
            plan: updatedPlan,
            needsRedistribution: needsRedistribution,
            didChange: updatedPlan != originalPlan
        )
    }
}
