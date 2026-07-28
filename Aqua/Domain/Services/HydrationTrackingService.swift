import Foundation

@MainActor
protocol HydrationEntriesChangeObserving: AnyObject {
    func hydrationEntriesDidChange() async
}

@MainActor
protocol HydrationTrackingServiceProtocol {
    func entries(for date: Date) async throws -> [HydrationEntry]
    func summary(for date: Date, dailyGoal: Double) async throws -> HydrationDaySummary
    func summaries(
        from startDate: Date,
        through endDate: Date,
        dailyGoal: Double
    ) async throws -> [HydrationDaySummary]
    func recordedSummaries(
        through endDate: Date,
        limit: Int,
        dailyGoal: Double
    ) async throws -> [HydrationDaySummary]
    func addWater(
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource,
        planMomentID: UUID?,
        planRevision: Int?
    ) async throws
    func deleteEntry(id: UUID) async throws
    func progress(for date: Date, dailyGoal: Double) async throws -> DailyHydrationProgress
}

@MainActor
final class HydrationTrackingService: HydrationTrackingServiceProtocol {
    private let repository: any HydrationRepository
    private let calendar: Calendar
    private weak var entriesChangeObserver: (any HydrationEntriesChangeObserving)?

    init(repository: any HydrationRepository, calendar: Calendar = .autoupdatingCurrent) {
        self.repository = repository
        self.calendar = calendar
    }

    func setEntriesChangeObserver(_ observer: (any HydrationEntriesChangeObserving)?) {
        entriesChangeObserver = observer
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

    func recordedSummaries(
        through endDate: Date,
        limit: Int,
        dailyGoal: Double
    ) async throws -> [HydrationDaySummary] {
        guard limit > 0 else { return [] }

        let lastDay = calendar.startOfDay(for: endDate)
        guard let endExclusive = calendar.date(byAdding: .day, value: 1, to: lastDay) else {
            return []
        }

        let entries = try await repository.entries(
            from: .distantPast,
            to: endExclusive
        )
        let entriesByDay = Dictionary(grouping: entries) { entry in
            calendar.startOfDay(for: entry.date)
        }
        let recordedDays = entriesByDay.keys
            .sorted()
            .suffix(limit)

        return recordedDays.map { day in
            let dayEntries = entriesByDay[day, default: []]
                .sorted { $0.date < $1.date }
            return HydrationDaySummary(
                date: day,
                entries: dayEntries,
                progress: DailyHydrationProgress.calculate(
                    entries: dayEntries,
                    dailyGoal: dailyGoal
                )
            )
        }
    }

    func addWater(
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource,
        planMomentID: UUID? = nil,
        planRevision: Int? = nil
    ) async throws {
        guard amountInMilliliters.isFinite, amountInMilliliters > 0 else {
            throw HydrationError.invalidAmount
        }

        let entry = HydrationEntry(
            amountInMilliliters: amountInMilliliters,
            date: date,
            source: source,
            planMomentID: planMomentID,
            planRevision: planRevision
        )
        try await repository.add(entry)
        // Completing a recommendation already has an exact target and is reconciled by
        // AdaptivePlanService. Free-form entries synchronize the three period goals.
        if source != .plan {
            await entriesChangeObserver?.hydrationEntriesDidChange()
        }
        NotificationCenter.default.post(name: .hydrationEntriesDidChange, object: nil)
    }

    func deleteEntry(id: UUID) async throws {
        try await repository.deleteEntry(id: id)
        await entriesChangeObserver?.hydrationEntriesDidChange()
        NotificationCenter.default.post(name: .hydrationEntriesDidChange, object: nil)
    }

    func progress(for date: Date, dailyGoal: Double) async throws -> DailyHydrationProgress {
        try await summary(for: date, dailyGoal: dailyGoal).progress
    }
}

extension HydrationTrackingServiceProtocol {
    func addWater(
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource
    ) async throws {
        try await addWater(
            amountInMilliliters: amountInMilliliters,
            date: date,
            source: source,
            planMomentID: nil,
            planRevision: nil
        )
    }
}
