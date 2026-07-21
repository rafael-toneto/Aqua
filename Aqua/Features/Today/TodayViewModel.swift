import Combine
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published private(set) var entries: [HydrationEntry] = []
    @Published private(set) var progress = DailyHydrationProgress(
        consumedAmount: 0,
        dailyGoal: HydrationDefaults.dailyGoalInMilliliters
    )
    @Published private(set) var displayedDate: Date
    @Published private(set) var isLoading = false
    @Published private(set) var feedbackTrigger = 0
    @Published var errorMessage: String?

    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let dateProvider: any DateProviding

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        dateProvider: any DateProviding
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.dateProvider = dateProvider
        displayedDate = dateProvider.now
    }

    func load() async {
        await load(showLoadingIndicator: entries.isEmpty)
    }

    func addQuickWater(amountInMilliliters: Double) async {
        do {
            try await trackingService.addWater(
                amountInMilliliters: amountInMilliliters,
                date: dateProvider.now,
                source: .quickAdd
            )
            await load(showLoadingIndicator: false)
            feedbackTrigger += 1
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntries(at offsets: IndexSet) async {
        let entryIDs = offsets.compactMap { index in
            entries.indices.contains(index) ? entries[index].id : nil
        }

        do {
            for entryID in entryIDs {
                try await trackingService.deleteEntry(id: entryID)
            }
            await load(showLoadingIndicator: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func didAddCustomWater() async {
        await load(showLoadingIndicator: false)
        feedbackTrigger += 1
    }

    private func load(showLoadingIndicator: Bool) async {
        if showLoadingIndicator {
            isLoading = true
        }
        defer { isLoading = false }

        let date = dateProvider.now
        let dailyGoal = goalService.dailyGoalInMilliliters

        do {
            let summary = try await trackingService.summary(for: date, dailyGoal: dailyGoal)
            displayedDate = summary.date
            entries = summary.entries
            progress = summary.progress
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
