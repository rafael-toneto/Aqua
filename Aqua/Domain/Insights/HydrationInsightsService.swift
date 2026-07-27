import Foundation
import OSLog

@MainActor
final class HydrationInsightsService: HydrationInsightsProviding {
    static let analysisDayCount = 14

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Aqua",
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
        let periodEnd = calendar.startOfDay(for: date)
        guard let periodStart = calendar.date(
            byAdding: .day,
            value: -(Self.analysisDayCount - 1),
            to: periodEnd
        ) else {
            throw HydrationInsightsGenerationError.invalidResponse
        }
        // The goal is read from the UserDefaults-backed preferences service and the summaries
        // come from the SwiftData-backed hydration repository.
        let dailyGoal = goalService.dailyGoalInMilliliters
        let summaries = try await trackingService.summaries(
            from: periodStart,
            through: periodEnd,
            dailyGoal: dailyGoal
        )
        let snapshot = calculator.makeSnapshot(
            summaries: summaries,
            dailyGoalMilliliters: dailyGoal,
            periodStart: periodStart,
            periodEnd: periodEnd
        )
        guard snapshot.hasSufficientHistory else {
            return HydrationInsightsReport(
                snapshot: snapshot,
                insights: []
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
                insights: validated
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as HydrationInsightsGenerationError {
            throw error
        } catch {
            throw HydrationInsightsGenerationError.generationFailed
        }
    }
}
