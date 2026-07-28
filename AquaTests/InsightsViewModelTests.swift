import XCTest
@testable import Aqua

@MainActor
final class InsightsViewModelTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var now = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 12)
        ) ?? .distantPast
    }

    func testRefreshAfterNewEntryUpdatesLoadedSnapshot() async throws {
        let entries = [
            entry(dayOffset: -4, amount: 500),
            entry(dayOffset: -3, amount: 500),
            entry(dayOffset: -2, amount: 500),
            entry(dayOffset: -1, amount: 500),
            entry(dayOffset: 0, amount: 500)
        ]
        let repository = FakeHydrationRepository(entries: entries)
        let tracking = HydrationTrackingService(repository: repository, calendar: calendar)
        let service = makeInsightsService(tracking: tracking)
        let viewModel = InsightsViewModel(
            service: service,
            dateProvider: FixedDateProvider(now: now)
        )
        await viewModel.refresh(displaysLoading: true)
        XCTAssertEqual(viewModel.state.report?.snapshot.totalEntryCount, 5)

        try await tracking.addWater(
            amountInMilliliters: 250,
            date: now,
            source: .quickAdd
        )
        await viewModel.refresh()

        XCTAssertEqual(viewModel.state.report?.snapshot.totalEntryCount, 6)
    }

    func testNewRefreshCancelsPreviousGenerationAndLatestResultWins() async throws {
        let first = report(totalEntries: 3)
        let second = report(totalEntries: 7)
        let service = SequencedInsightsService(responses: [
            .init(delay: .milliseconds(250), result: .success(first)),
            .init(delay: nil, result: .success(second))
        ])
        let viewModel = InsightsViewModel(
            service: service,
            dateProvider: FixedDateProvider(now: now)
        )

        viewModel.requestRefresh(displaysLoading: true)
        try await Task.sleep(for: .milliseconds(30))
        viewModel.requestRefresh()

        for _ in 0..<30 {
            if viewModel.state.report?.snapshot.totalEntryCount == 7 { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(service.callCount, 2)
        XCTAssertEqual(service.cancellationCount, 1)
        XCTAssertEqual(viewModel.state.report?.snapshot.totalEntryCount, 7)
    }

    func testServiceErrorProducesFailedState() async {
        let service = SequencedInsightsService(responses: [
            .init(delay: nil, result: .failure(ExpectedInsightsError.failed))
        ])
        let viewModel = InsightsViewModel(
            service: service,
            dateProvider: FixedDateProvider(now: now)
        )

        await viewModel.refresh(displaysLoading: true)

        guard case .failed(let message) = viewModel.state else {
            return XCTFail("Expected failed state")
        }
        XCTAssertFalse(message.isEmpty)
    }

    func testInsufficientHistoryProducesEmptyState() async {
        let emptyReport = report(
            totalEntries: 3,
            availability: .needsMoreRecordedDays(recordedDayCount: 3)
        )
        let service = SequencedInsightsService(responses: [
            .init(delay: nil, result: .success(emptyReport))
        ])
        let viewModel = InsightsViewModel(
            service: service,
            dateProvider: FixedDateProvider(now: now)
        )

        await viewModel.refresh(displaysLoading: true)

        guard case .empty(let report) = viewModel.state else {
            return XCTFail("Expected empty state")
        }
        XCTAssertFalse(report.snapshot.hasSufficientHistory)
        XCTAssertTrue(report.insights.isEmpty)
    }

    func testInsufficientRecentHistoryProducesEmptyState() async {
        let emptyReport = report(
            totalEntries: 2,
            availability: .needsRecentRecordedDays(recordedDayCount: 2)
        )
        let service = SequencedInsightsService(responses: [
            .init(delay: nil, result: .success(emptyReport))
        ])
        let viewModel = InsightsViewModel(
            service: service,
            dateProvider: FixedDateProvider(now: now)
        )

        await viewModel.refresh(displaysLoading: true)

        guard case .empty(let report) = viewModel.state else {
            return XCTFail("Expected empty state")
        }
        XCTAssertEqual(
            report.availability,
            .needsRecentRecordedDays(recordedDayCount: 2)
        )
        XCTAssertTrue(report.insights.isEmpty)
    }

    private func makeInsightsService(
        tracking: HydrationTrackingService
    ) -> HydrationInsightsService {
        let goal = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore(
                dailyGoalInMilliliters: 2_000
            )
        )
        return HydrationInsightsService(
            trackingService: tracking,
            goalService: goal,
            generator: ValidHydrationInsightsGenerator(),
            calendar: calendar
        )
    }

    private func entry(dayOffset: Int, amount: Double) -> HydrationEntry {
        let day = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ) ?? now
        return HydrationEntry(
            amountInMilliliters: amount,
            date: calendar.date(byAdding: .hour, value: 10, to: day) ?? day,
            source: .manual
        )
    }

    private func report(
        totalEntries: Int,
        availability: HydrationInsightsAvailability = .available
    ) -> HydrationInsightsReport {
        let recordedDayCount: Int
        switch availability {
        case .available:
            recordedDayCount = 5
        case .needsMoreRecordedDays(let count), .needsRecentRecordedDays(let count):
            recordedDayCount = count
        }
        let snapshot = HydrationInsightsSnapshot(
            periodStart: calendar.date(
                byAdding: .day,
                value: -(max(recordedDayCount, 1) - 1),
                to: now
            ) ?? now,
            periodEnd: now,
            analyzedDayCount: recordedDayCount,
            daysWithEntries: recordedDayCount,
            daysWithoutEntries: 0,
            totalEntryCount: totalEntries,
            dailyGoalMilliliters: 2_000,
            goalAchievementPercentage: 25,
            averageDailyConsumptionMilliliters: 1_000,
            averageEntriesPerDay: 2,
            averageFirstEntryMinutes: 600,
            averageLastEntryMinutes: 1_000,
            morningConsumptionPercentage: 30,
            afternoonConsumptionPercentage: 45,
            eveningConsumptionPercentage: 25,
            averageIntervalMinutes: 180,
            lateDayConsumptionPercentage: 25,
            planMomentAdherencePercentage: 10,
            recentTrendPercentage: 5
        )
        guard availability == .available else {
            return HydrationInsightsReport(
                snapshot: snapshot,
                insights: [],
                availability: availability
            )
        }
        let metrics: [(
            HydrationInsightCategory,
            HydrationInsightEvidenceMetric,
            String
        )] = [
            (.consistency, .averageEntries, "Build a steady rhythm"),
            (.timing, .firstEntryTime, "Anchor the first entry"),
            (.goalProgress, .goalAchievement, "Keep goal progress visible")
        ]
        let insights = metrics.map { category, metric, title in
            HydrationInsight(
                id: "\(category.rawValue).\(metric.rawValue)",
                title: title,
                description: "This pattern is based on recent aggregate history.",
                evidence: snapshot.evidence(for: metric),
                evidenceMetric: metric,
                suggestedAction: "Use the existing plan as a practical cue.",
                category: category,
                priority: .medium
            )
        }
        return HydrationInsightsReport(
            snapshot: snapshot,
            insights: insights,
            availability: availability
        )
    }
}

private enum ExpectedInsightsError: LocalizedError {
    case failed

    var errorDescription: String? { "Expected insights failure" }
}

@MainActor
private final class SequencedInsightsService: HydrationInsightsProviding {
    struct Response {
        let delay: Duration?
        let result: Result<HydrationInsightsReport, Error>
    }

    private let responses: [Response]
    private(set) var callCount = 0
    private(set) var cancellationCount = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    func insights(asOf date: Date) async throws -> HydrationInsightsReport {
        let index = min(callCount, responses.count - 1)
        callCount += 1
        let response = responses[index]
        if let delay = response.delay {
            do {
                try await Task.sleep(for: delay)
            } catch is CancellationError {
                cancellationCount += 1
                throw CancellationError()
            }
        }
        return try response.result.get()
    }
}
