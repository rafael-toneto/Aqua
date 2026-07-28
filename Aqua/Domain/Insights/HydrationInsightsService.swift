import Foundation
import OSLog

@MainActor
final class HydrationInsightsService: HydrationInsightsProviding {
    static let analysisDayCount = 14
    static let inactivityDayCount = 5

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AquaFlow",
        category: "HydrationInsights"
    )

    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let generator: any HydrationInsightsGenerating
    private let validator: HydrationInsightsValidator
    private let calculator: HydrationInsightsMetricsCalculator
    private let calendar: Calendar

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        generator: any HydrationInsightsGenerating,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.generator = generator
        self.calendar = calendar
        validator = HydrationInsightsValidator()
        calculator = HydrationInsightsMetricsCalculator(calendar: calendar)
    }

    func insights(asOf date: Date) async throws -> HydrationInsightsReport {
        // The goal is read from the UserDefaults-backed preferences service and the summaries
        // come from the SwiftData-backed hydration repository.
        let dailyGoal = goalService.dailyGoalInMilliliters
        let recordedSummaries = try await trackingService.recordedSummaries(
            through: date,
            limit: Self.analysisDayCount,
            dailyGoal: dailyGoal
        )
        let availability = availability(
            for: recordedSummaries,
            asOf: date
        )
        let summaries = summariesForAnalysis(
            from: recordedSummaries,
            availability: availability
        )
        let fallbackDay = calendar.startOfDay(for: date)
        let periodStart = summaries.first?.date ?? fallbackDay
        let periodEnd = summaries.last?.date ?? fallbackDay
        let snapshot = calculator.makeSnapshot(
            summaries: summaries,
            dailyGoalMilliliters: dailyGoal,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
        guard availability == .available, snapshot.hasSufficientHistory else {
            return HydrationInsightsReport(
                snapshot: snapshot,
                insights: [],
                availability: availability
            )
        }

        do {
            let generated = try await generator.generateInsights(from: snapshot)
            let validated = validator.validInsights(from: generated, against: snapshot)
            guard !validated.isEmpty else {
                Self.logger.error(
                    "Foundation Models returned no insights accepted by app validation."
                )
                throw HydrationInsightsGenerationError.invalidResponse
            }
            Self.logger.notice(
                "Produced \(validated.count) validated insights from \(snapshot.daysWithEntries) recorded days in the \(snapshot.analyzedDayCount)-day window."
            )
            return HydrationInsightsReport(
                snapshot: snapshot,
                insights: validated,
                availability: .available
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HydrationInsightsGenerationError {
            throw error
        } catch {
            throw HydrationInsightsGenerationError.generationFailed
        }
    }

    private func availability(
        for recordedSummaries: [HydrationDaySummary],
        asOf date: Date
    ) -> HydrationInsightsAvailability {
        let requiredDayCount = HydrationInsightsAvailability.requiredRecordedDayCount
        guard recordedSummaries.count >= requiredDayCount else {
            return .needsMoreRecordedDays(recordedDayCount: recordedSummaries.count)
        }
        guard let latestRecordedDay = recordedSummaries.last?.date else {
            return .needsMoreRecordedDays(recordedDayCount: 0)
        }

        let today = calendar.startOfDay(for: date)
        let latestDay = calendar.startOfDay(for: latestRecordedDay)
        let daysSinceLatestRecord = calendar.dateComponents(
            [.day],
            from: latestDay,
            to: today
        ).day ?? 0
        guard daysSinceLatestRecord < Self.inactivityDayCount else {
            return .needsRecentRecordedDays(recordedDayCount: 0)
        }

        let recentCount = recentRecordedSummaries(from: recordedSummaries).count
        guard recentCount >= requiredDayCount else {
            return .needsRecentRecordedDays(recordedDayCount: recentCount)
        }
        return .available
    }

    private func summariesForAnalysis(
        from recordedSummaries: [HydrationDaySummary],
        availability: HydrationInsightsAvailability
    ) -> [HydrationDaySummary] {
        switch availability {
        case .available, .needsRecentRecordedDays:
            return recentRecordedSummaries(from: recordedSummaries)
        case .needsMoreRecordedDays:
            return recordedSummaries
        }
    }

    private func recentRecordedSummaries(
        from recordedSummaries: [HydrationDaySummary]
    ) -> [HydrationDaySummary] {
        guard !recordedSummaries.isEmpty else { return [] }

        var startIndex = recordedSummaries.startIndex
        for index in recordedSummaries.indices.dropFirst() {
            let previousIndex = recordedSummaries.index(before: index)
            let previousDay = calendar.startOfDay(for: recordedSummaries[previousIndex].date)
            let currentDay = calendar.startOfDay(for: recordedSummaries[index].date)
            let elapsedDays = calendar.dateComponents(
                [.day],
                from: previousDay,
                to: currentDay
            ).day ?? 0
            if elapsedDays >= Self.inactivityDayCount {
                startIndex = index
            }
        }
        return Array(recordedSummaries[startIndex...])
    }
}
