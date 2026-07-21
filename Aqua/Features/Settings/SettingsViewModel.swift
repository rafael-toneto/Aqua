import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var goalText = ""
    @Published private(set) var savedGoalInMilliliters = HydrationDefaults.dailyGoalInMilliliters
    @Published private(set) var feedbackTrigger = 0
    @Published var errorMessage: String?

    private let goalService: any HydrationGoalServiceProtocol

    init(goalService: any HydrationGoalServiceProtocol) {
        self.goalService = goalService
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

    func load() {
        let goal = goalService.dailyGoalInMilliliters
        savedGoalInMilliliters = goal
        goalText = String(Int(goal.rounded()))
        errorMessage = nil
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
}
