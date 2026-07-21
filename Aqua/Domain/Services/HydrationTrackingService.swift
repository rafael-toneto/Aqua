import Foundation

@MainActor
protocol HydrationTrackingServiceProtocol {
    func entries(for date: Date) async throws -> [HydrationEntry]
    func summary(for date: Date, dailyGoal: Double) async throws -> HydrationDaySummary
    func summaries(
        from startDate: Date,
        through endDate: Date,
        dailyGoal: Double
    ) async throws -> [HydrationDaySummary]
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

    func summaries(
        from startDate: Date,
        through endDate: Date,
        dailyGoal: Double
    ) async throws -> [HydrationDaySummary] {
        let firstDay = calendar.startOfDay(for: startDate)
        let lastDay = calendar.startOfDay(for: endDate)
        guard firstDay <= lastDay,
              let endExclusive = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            return []
        }

        let entries = try await repository.entries(from: firstDay, to: endExclusive)
        let entriesByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }

        var summaries: [HydrationDaySummary] = []
        var day = firstDay

        while day <= lastDay {
            let dayEntries = entriesByDay[day, default: []]
            summaries.append(
                HydrationDaySummary(
                    date: day,
                    entries: dayEntries,
                    progress: DailyHydrationProgress.calculate(
                        entries: dayEntries,
                        dailyGoal: dailyGoal
                    )
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return summaries
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
