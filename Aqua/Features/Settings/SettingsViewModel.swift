import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var goalText = ""
    @Published private(set) var savedGoalInMilliliters = HydrationDefaults.dailyGoalInMilliliters
    @Published var quickAddAmountTexts = HydrationDefaults.quickAddAmountsInMilliliters.map {
        String(Int($0.rounded()))
    }
    @Published private(set) var savedQuickAddAmountsInMilliliters = HydrationDefaults.quickAddAmountsInMilliliters
    @Published private(set) var volumeDisplayUnit: WaterVolumeUnit
    @Published private(set) var feedbackTrigger = 0
    @Published var errorMessage: String?
    @Published var quickAddErrorMessage: String?

    private let goalService: any HydrationGoalServiceProtocol
    private let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    private let userDefaults: UserDefaults

    init(
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.goalService = goalService
        self.quickAddAmountsService = quickAddAmountsService
        self.userDefaults = userDefaults
        volumeDisplayUnit = userDefaults.string(forKey: WaterVolumeUnit.preferenceKey)
            .flatMap(WaterVolumeUnit.init(rawValue:)) ?? .metric
        load()
    }

    var proposedGoalInMilliliters: Double? {
        milliliters(fromDisplayedText: goalText)
    }

    var canSave: Bool {
        guard let proposedGoalInMilliliters else { return false }
        return proposedGoalInMilliliters != savedGoalInMilliliters
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
        return proposedQuickAddAmountsInMilliliters != savedQuickAddAmountsInMilliliters
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
    }

    func toggleVolumeDisplayUnit() {
        volumeDisplayUnit = volumeDisplayUnit == .metric ? .fluidOunces : .metric
        userDefaults.set(volumeDisplayUnit.rawValue, forKey: WaterVolumeUnit.preferenceKey)

        goalText = editorText(from: savedGoalInMilliliters)
        quickAddAmountTexts = savedQuickAddAmountsInMilliliters.map(editorText(from:))
        errorMessage = nil
        quickAddErrorMessage = nil
        feedbackTrigger += 1
    }

    func formattedAmount(from amountInMilliliters: Double) -> String {
        WaterAmountFormatter.string(from: amountInMilliliters, unit: volumeDisplayUnit)
    }

    func editorText(from amountInMilliliters: Double) -> String {
        WaterAmountFormatter.editorText(from: amountInMilliliters, unit: volumeDisplayUnit)
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
}
