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
    @Published private(set) var feedbackTrigger = 0
    @Published var errorMessage: String?
    @Published var quickAddErrorMessage: String?

    private let goalService: any HydrationGoalServiceProtocol
    private let quickAddAmountsService: any QuickAddAmountsServiceProtocol

    init(
        goalService: any HydrationGoalServiceProtocol,
        quickAddAmountsService: any QuickAddAmountsServiceProtocol
    ) {
        self.goalService = goalService
        self.quickAddAmountsService = quickAddAmountsService
        load()
    }

    var proposedGoalInMilliliters: Double? {
        let trimmedText = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Int(trimmedText), amount > 0 else {
            return nil
        }
        return Double(amount)
    }

    var canSave: Bool {
        guard let proposedGoalInMilliliters else { return false }
        return proposedGoalInMilliliters != savedGoalInMilliliters
    }

    var proposedQuickAddAmountsInMilliliters: [Double]? {
        let amounts = quickAddAmountTexts.compactMap { text -> Double? in
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let amount = Int(trimmedText), amount > 0 else { return nil }
            return Double(amount)
        }

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
        goalText = String(Int(goal.rounded()))
        let quickAddAmounts = quickAddAmountsService.amountsInMilliliters
        savedQuickAddAmountsInMilliliters = quickAddAmounts
        quickAddAmountTexts = quickAddAmounts.map { String(Int($0.rounded())) }
        errorMessage = nil
        quickAddErrorMessage = nil
    }

    func save() {
        guard let proposedGoalInMilliliters else {
            errorMessage = HydrationError.invalidDailyGoal.localizedDescription
            return
        }

        do {
            try goalService.updateDailyGoal(to: proposedGoalInMilliliters)
            savedGoalInMilliliters = proposedGoalInMilliliters
            goalText = String(Int(proposedGoalInMilliliters.rounded()))
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

        do {
            try quickAddAmountsService.updateAmounts(proposedQuickAddAmountsInMilliliters)
            savedQuickAddAmountsInMilliliters = proposedQuickAddAmountsInMilliliters
            quickAddAmountTexts = proposedQuickAddAmountsInMilliliters.map { String(Int($0.rounded())) }
            quickAddErrorMessage = nil
            feedbackTrigger += 1
        } catch {
            quickAddErrorMessage = error.localizedDescription
        }
    }
}
