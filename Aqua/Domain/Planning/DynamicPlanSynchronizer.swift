import Foundation

/// Keeps the persisted daily plan in sync with hydration mutations, independently of any view.
@MainActor
final class DynamicPlanSynchronizer: HydrationEntriesChangeObserving {
    private let planService: AdaptivePlanService
    private let dateProvider: any DateProviding
    private var updateTask: Task<Void, Never>?
    private var updateSequence = 0

    init(
        planService: AdaptivePlanService,
        dateProvider: any DateProviding
    ) {
        self.planService = planService
        self.dateProvider = dateProvider
    }

    func hydrationEntriesDidChange() async {
        updateSequence += 1
        let sequence = updateSequence

        // A newer entry always wins. AdaptivePlanService checks cancellation again before saving,
        // so an older Foundation Models response cannot overwrite a more recent plan.
        updateTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await planService.preparePlan(
                    now: dateProvider.now,
                    forceRegeneration: false
                )
            } catch is CancellationError {
                return
            } catch {
                // Logging water must remain successful even if plan generation is unavailable.
                // The plan screen receives the notification below and can retry its normal load.
            }
        }
        updateTask = task
        await task.value

        guard sequence == updateSequence else { return }
        updateTask = nil
        NotificationCenter.default.post(name: .hydrationPlanDidChange, object: nil)
    }
}
