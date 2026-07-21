import Foundation

@MainActor
protocol HydrationTrackingServiceProtocol {
    func entries(for date: Date) async throws -> [HydrationEntry]
    func summary(for date: Date, dailyGoal: Double) async throws -> HydrationDaySummary
    func addWater(
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource
    ) async throws
    func deleteEntry(id: UUID) async throws
    func progress(for date: Date, dailyGoal: Double) async throws -> DailyHydrationProgress
}

@MainActor
final class HydrationTrackingService: HydrationTrackingServiceProtocol {
    private let repository: any HydrationRepository
    private let calendar: Calendar

    init(repository: any HydrationRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    func entries(for date: Date) async throws -> [HydrationEntry] {
        try await repository.entries(for: date, calendar: calendar)
    }

    func summary(for date: Date, dailyGoal: Double) async throws -> HydrationDaySummary {
        let entries = try await repository.entries(for: date, calendar: calendar)
        return HydrationDaySummary(
            date: date,
            entries: entries,
            progress: DailyHydrationProgress.calculate(entries: entries, dailyGoal: dailyGoal)
        )
    }

    func addWater(
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource
    ) async throws {
        guard amountInMilliliters.isFinite, amountInMilliliters > 0 else {
            throw HydrationError.invalidAmount
        }

        let entry = HydrationEntry(
            amountInMilliliters: amountInMilliliters,
            date: date,
            source: source
        )
        try await repository.add(entry)
    }

    func deleteEntry(id: UUID) async throws {
        try await repository.deleteEntry(id: id)
    }

    func progress(for date: Date, dailyGoal: Double) async throws -> DailyHydrationProgress {
        try await summary(for: date, dailyGoal: dailyGoal).progress
    }
}
