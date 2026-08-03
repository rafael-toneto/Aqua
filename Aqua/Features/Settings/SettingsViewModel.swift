import Combine
import Foundation
import WidgetKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var goalText = ""
    @Published private(set) var savedGoalInMilliliters = HydrationDefaults.dailyGoalInMilliliters
    @Published var quickAddAmountTexts = HydrationDefaults.quickAddAmountsInMilliliters.map {
        String(Int($0.rounded()))
    }
    @Published private(set) var savedQuickAddAmountsInMilliliters = HydrationDefaults.quickAddAmountsInMilliliters
    @Published private(set) var volumeDisplayUnit: WaterVolumeUnit
    @Published private(set) var liveActivitiesEnabled: Bool
    @Published private(set) var liveActivitiesAvailable: Bool
    @Published private(set) var feedbackTrigger = 0
    @Published var errorMessage: String?
    @Published var quickAddErrorMessage: String?

    private let goalService: any HydrationGoalServiceProtocol
    private let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    private let userDefaults: UserDefaults
    private let liveActivityController: (any HydrationLiveActivityControlling)?

    init(
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol,
        liveActivityController: (any HydrationLiveActivityControlling)? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.goalService = goalService
        self.quickAddAmountsService = quickAddAmountsService
        let resolvedUserDefaults = userDefaults ?? AquaSharedStore.userDefaults
        self.userDefaults = resolvedUserDefaults
        self.liveActivityController = liveActivityController
        volumeDisplayUnit = resolvedUserDefaults.string(forKey: WaterVolumeUnit.preferenceKey)
            .flatMap(WaterVolumeUnit.init(rawValue:)) ?? .metric
        liveActivitiesEnabled = liveActivityController?.isEnabled
            ?? Self.liveActivitiesEnabled(in: resolvedUserDefaults)
        liveActivitiesAvailable = liveActivityController?.areActivitiesAvailable ?? true
        load()
    }

    var proposedGoalInMilliliters: Double? {
        milliliters(fromDisplayedText: goalText)
    }

    var canSave: Bool {
        guard let proposedGoalInMilliliters else { return false }
        return proposedGoalInMilliliters <= HydrationLimits.maximumDailyGoalInMilliliters
            && proposedGoalInMilliliters != savedGoalInMilliliters
    }

    var proposedQuickAddAmountsInMilliliters: [Double]? {
        let amounts = quickAddAmountTexts.compactMap(milliliters(fromDisplayedText:))

        guard amounts.count == HydrationDefaults.quickAddAmountsInMilliliters.count else {
            return nil
        }
        return amounts
    }

    var canSaveQuickAddAmounts: Bool {
        guard let proposedQuickAddAmountsInMilliliters else { return false }
        return proposedQuickAddAmountsInMilliliters.allSatisfy {
            $0 <= HydrationLimits.maximumSingleEntryInMilliliters
        } && proposedQuickAddAmountsInMilliliters != savedQuickAddAmountsInMilliliters
    }

    func load() {
        let goal = goalService.dailyGoalInMilliliters
        savedGoalInMilliliters = goal
        goalText = editorText(from: goal)
        let quickAddAmounts = quickAddAmountsService.amountsInMilliliters
        savedQuickAddAmountsInMilliliters = quickAddAmounts
        quickAddAmountTexts = quickAddAmounts.map(editorText(from:))
        errorMessage = nil
        quickAddErrorMessage = nil
        liveActivitiesEnabled = liveActivityController?.isEnabled
            ?? Self.liveActivitiesEnabled(in: userDefaults)
        liveActivitiesAvailable = liveActivityController?.areActivitiesAvailable ?? true
    }

    func toggleVolumeDisplayUnit() {
        volumeDisplayUnit = volumeDisplayUnit == .metric ? .fluidOunces : .metric
        userDefaults.set(volumeDisplayUnit.rawValue, forKey: WaterVolumeUnit.preferenceKey)
        WidgetCenter.shared.reloadTimelines(ofKind: AquaSharedStore.widgetKind)

        goalText = editorText(from: savedGoalInMilliliters)
        quickAddAmountTexts = savedQuickAddAmountsInMilliliters.map(editorText(from:))
        errorMessage = nil
        quickAddErrorMessage = nil
        feedbackTrigger += 1

        Task { await liveActivityController?.synchronize() }
    }

    func setLiveActivitiesEnabled(_ isEnabled: Bool) {
        liveActivitiesEnabled = isEnabled
        userDefaults.set(isEnabled, forKey: AquaSharedStore.PreferenceKey.liveActivitiesEnabled)
        feedbackTrigger += 1

        Task {
            await liveActivityController?.setEnabled(isEnabled)
            liveActivitiesAvailable = liveActivityController?.areActivitiesAvailable ?? true
        }
    }

    func formattedAmount(from amountInMilliliters: Double) -> String {
        WaterAmountFormatter.string(from: amountInMilliliters, unit: volumeDisplayUnit)
    }

    func editorText(from amountInMilliliters: Double) -> String {
        WaterAmountFormatter.editorText(from: amountInMilliliters, unit: volumeDisplayUnit)
    }

    var maximumDailyGoalDescription: String {
        formattedAmount(from: HydrationLimits.maximumDailyGoalInMilliliters)
    }

    var maximumSingleEntryDescription: String {
        formattedAmount(from: HydrationLimits.maximumSingleEntryInMilliliters)
    }

    func save() {
        guard let proposedGoalInMilliliters else {
            errorMessage = HydrationError.invalidDailyGoal.localizedDescription
            return
        }

        do {
            try goalService.updateDailyGoal(to: proposedGoalInMilliliters)
            savedGoalInMilliliters = proposedGoalInMilliliters
            goalText = editorText(from: proposedGoalInMilliliters)
            errorMessage = nil
            feedbackTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveQuickAddAmounts() {
        guard let proposedQuickAddAmountsInMilliliters else {
            quickAddErrorMessage = HydrationError.invalidQuickAddAmounts.localizedDescription
            return
        }

        saveQuickAddAmounts(proposedQuickAddAmountsInMilliliters)
    }

    func saveQuickAddAmount(_ displayedText: String, at index: Int) {
        guard savedQuickAddAmountsInMilliliters.indices.contains(index),
              let amountInMilliliters = milliliters(fromDisplayedText: displayedText) else {
            quickAddErrorMessage = HydrationError.invalidQuickAddAmounts.localizedDescription
            return
        }

        var updatedAmounts = savedQuickAddAmountsInMilliliters
        updatedAmounts[index] = amountInMilliliters
        saveQuickAddAmounts(updatedAmounts)
    }

    private func saveQuickAddAmounts(_ amountsInMilliliters: [Double]) {
        do {
            try quickAddAmountsService.updateAmounts(amountsInMilliliters)
            savedQuickAddAmountsInMilliliters = amountsInMilliliters
            quickAddAmountTexts = amountsInMilliliters.map(editorText(from:))
            quickAddErrorMessage = nil
            feedbackTrigger += 1
        } catch {
            quickAddErrorMessage = error.localizedDescription
        }
    }

    private func milliliters(fromDisplayedText text: String) -> Double? {
        WaterAmountFormatter.milliliters(
            fromDisplayedText: text,
            unit: volumeDisplayUnit
        )
    }

    private static func liveActivitiesEnabled(in userDefaults: UserDefaults) -> Bool {
        guard userDefaults.object(forKey: AquaSharedStore.PreferenceKey.liveActivitiesEnabled) != nil else {
            return true
        }
        return userDefaults.bool(forKey: AquaSharedStore.PreferenceKey.liveActivitiesEnabled)
    }
}
