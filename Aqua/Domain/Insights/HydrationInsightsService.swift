import Foundation

@MainActor
final class HydrationInsightsService: HydrationInsightsProviding {
    static let analysisDayCount = 5

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
            guard validator.validate(generated, against: snapshot) else {
                throw HydrationInsightsGenerationError.invalidResponse
            }
            return HydrationInsightsReport(
                snapshot: snapshot,
                insights: generated
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
