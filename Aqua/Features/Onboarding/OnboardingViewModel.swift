import Combine
import Foundation

enum OnboardingPreferences {
    static let completionKey = "aqua.onboarding.completed.v1"
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome
        case overview
        case goal
        case plan

        var id: Int { rawValue }
    }

    @Published private(set) var step: Step = .welcome
    @Published var goalText: String
    @Published private(set) var planningPreferences: PlanningPreferences
    @Published private(set) var preferredCheckpointsPerPeriod: Int
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSaving = false

    let volumeUnit: WaterVolumeUnit

    private let goalService: any HydrationGoalServiceProtocol
    private let planningPreferencesStore: any PlanningPreferencesStoring

    nonisolated deinit {}

    init(
        goalService: any HydrationGoalServiceProtocol,
        planningPreferencesStore: any PlanningPreferencesStoring,
        volumeUnit: WaterVolumeUnit,
        initialPlanningPreferences: PlanningPreferences? = nil
    ) {
        self.goalService = goalService
        self.planningPreferencesStore = planningPreferencesStore
        self.volumeUnit = volumeUnit
        let preferences = initialPlanningPreferences ?? planningPreferencesStore.preferences
        planningPreferences = preferences
        preferredCheckpointsPerPeriod =
            preferences.preferredCheckpointsPerActivePeriod
        goalText = ""
    }

    var proposedGoalInMilliliters: Double? {
        WaterAmountFormatter.milliliters(
            fromDisplayedText: goalText,
            unit: volumeUnit
        )
    }

    var canContinue: Bool {
        switch step {
        case .goal:
            proposedGoalInMilliliters.map {
                $0 <= HydrationLimits.maximumDailyGoalInMilliliters
            } ?? false
        case .plan:
            planningPreferences.isValid
        case .welcome, .overview:
            true
        }
    }

    var isLastStep: Bool { step == .plan }

    var maximumDailyGoalDescription: String {
        WaterAmountFormatter.string(
            from: HydrationLimits.maximumDailyGoalInMilliliters,
            unit: volumeUnit
        )
    }

    func move(to newStep: Step) {
        step = newStep
        errorMessage = nil
    }

    func moveForward() {
        guard canContinue,
              let next = Step(rawValue: step.rawValue + 1) else {
            if step == .goal {
                errorMessage = HydrationError.invalidDailyGoal.localizedDescription
            }
            return
        }
        move(to: next)
    }

    func moveBack() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        move(to: previous)
    }

    func updateActiveDayStart(minutes: Int) {
        planningPreferences.activeDayStartMinutes = min(
            max(minutes, 0),
            planningPreferences.activeDayEndMinutes - 15
        )
        synchronizeDailyCadence()
    }

    func updateActiveDayEnd(minutes: Int) {
        planningPreferences.activeDayEndMinutes = max(
            min(minutes, 24 * 60),
            planningPreferences.activeDayStartMinutes + 15
        )
        synchronizeDailyCadence()
    }

    func updatePreferredCheckpointsPerPeriod(_ count: Int) {
        preferredCheckpointsPerPeriod = min(max(count, 1), 4)
        synchronizeDailyCadence()
    }

    func updateMinimumInterval(_ minutes: Int) {
        planningPreferences.minimumIntervalMinutes = min(max(minutes, 15), 240)
    }

    func updatePreferredAmount(_ milliliters: Int) {
        planningPreferences.preferredAmountMilliliters = min(
            max(milliliters, 50),
            10_000
        )
    }

    func finish() -> Bool {
        guard let proposedGoalInMilliliters else {
            errorMessage = HydrationError.invalidDailyGoal.localizedDescription
            return false
        }
        guard planningPreferences.isValid else {
            errorMessage = HydrationError.invalidPlanningPreferences.localizedDescription
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            // Planning preferences are validated before either local setting is
            // committed, so the goal update cannot leave a partially valid draft.
            try planningPreferencesStore.update(planningPreferences)
            try goalService.updateDailyGoal(to: proposedGoalInMilliliters)
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func synchronizeDailyCadence() {
        planningPreferences.setPreferredCheckpointsPerActivePeriod(
            preferredCheckpointsPerPeriod
        )
        errorMessage = nil
    }
}
