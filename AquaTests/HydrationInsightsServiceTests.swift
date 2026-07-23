import XCTest
@testable import Aqua

@MainActor
final class HydrationInsightsServiceTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var now = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 21)
        ) ?? .distantPast
    }

    func testCalculatesFiveDayAggregateMetricsIncludingMissingDays() async throws {
        let report = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)
        let snapshot = report.snapshot
        let expectedStart = try XCTUnwrap(
            calendar.date(byAdding: .day, value: -4, to: calendar.startOfDay(for: now))
        )

        XCTAssertEqual(snapshot.periodStart, expectedStart)
        XCTAssertEqual(snapshot.periodEnd, calendar.startOfDay(for: now))
        XCTAssertEqual(snapshot.analyzedDayCount, 5)
        XCTAssertEqual(snapshot.daysWithEntries, 3)
        XCTAssertEqual(snapshot.daysWithoutEntries, 2)
        XCTAssertEqual(snapshot.totalEntryCount, 6)
        XCTAssertEqual(snapshot.goalAchievementPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(snapshot.averageDailyConsumptionMilliliters, 1_000, accuracy: 0.001)
        XCTAssertEqual(snapshot.averageEntriesPerDay, 1.2, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageFirstEntryMinutes), 720, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageLastEntryMinutes), 1_060, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageIntervalMinutes), 340, accuracy: 0.001)
        XCTAssertEqual(snapshot.planMomentAdherencePercentage, 1.0 / 6.0 * 100, accuracy: 0.001)
    }

    func testGoalAdherenceAndLateDayConcentrationUseRecordedVolume() async throws {
        let report = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)

        XCTAssertEqual(report.snapshot.goalAchievementPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(report.snapshot.lateDayConsumptionPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(report.snapshot.eveningConsumptionPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(report.snapshot.recentTrendPercentage, -25, accuracy: 0.001)
    }

    func testFoundationModelsInsightsAreValidatedAndReturned() async throws {
        let report = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)

        XCTAssertEqual(report.insights.count, 3)
        XCTAssertTrue(
            HydrationInsightsValidator().validate(
                report.insights,
                against: report.snapshot
            )
        )
    }

    func testInvalidFoundationModelsOutputIsRejected() async {
        let invalid = HydrationInsight(
            id: "invalid",
            title: "Invented 99 day claim",
            description: "Unsupported content",
            evidence: "Not in the snapshot",
            evidenceMetric: .goalAchievement,
            suggestedAction: "Change the goal",
            category: .goalProgress,
            priority: .high
        )
        let generator = MockHydrationInsightsGenerator(result: .success([invalid]))

        do {
            _ = try await makeService(
                entries: representativeEntries(),
                generator: generator
            ).insights(asOf: now)
            XCTFail("Expected invalid Foundation Models output to be rejected")
        } catch let error as HydrationInsightsGenerationError {
            XCTAssertEqual(error, .invalidResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFoundationModelsUnavailabilityIsReportedWithoutFallback() async {
        let generator = MockHydrationInsightsGenerator(
            result: .failure(HydrationInsightsGenerationError.unavailable)
        )

        do {
            _ = try await makeService(
                entries: representativeEntries(),
                generator: generator
            ).insights(asOf: now)
            XCTFail("Expected Foundation Models unavailability")
        } catch let error as HydrationInsightsGenerationError {
            XCTAssertEqual(error, .unavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancelledFoundationModelsGenerationPropagatesCancellation() async throws {
        let generator = MockHydrationInsightsGenerator(result: .success([]))
        generator.delay = .seconds(1)
        let service = makeService(
            entries: representativeEntries(),
            generator: generator
        )
        let task = Task { try await service.insights(asOf: now) }
        try await Task.sleep(for: .milliseconds(20))

        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: there is no non-Foundation Models fallback.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInsufficientHistoryDoesNotInvokeFoundationModelsAgent() async throws {
        let generator = MockHydrationInsightsGenerator(
            result: .failure(HydrationInsightsGenerationError.generationFailed)
        )
        let report = try await makeService(
            entries: [entry(dayOffset: 0, hour: 10, amount: 500)],
            generator: generator
        ).insights(asOf: now)

        XCTAssertFalse(report.snapshot.hasSufficientHistory)
        XCTAssertTrue(report.insights.isEmpty)
        XCTAssertEqual(generator.callCount, 0)
    }

    private func makeService(
        entries: [HydrationEntry],
        generator: (any HydrationInsightsGenerating)? = nil
    ) -> HydrationInsightsService {
        let tracking = HydrationTrackingService(
            repository: FakeHydrationRepository(entries: entries),
            calendar: calendar
        )
        let goal = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore(
                dailyGoalInMilliliters: 2_000
            )
        )
        return HydrationInsightsService(
            trackingService: tracking,
            goalService: goal,
            generator: generator ?? ValidHydrationInsightsGenerator(),
            calendar: calendar
        )
    }

    private func representativeEntries() -> [HydrationEntry] {
        [
            entry(dayOffset: -4, hour: 8, amount: 500),
            entry(dayOffset: -4, hour: 13, amount: 500),
            entry(dayOffset: -4, hour: 19, amount: 1_000),
            entry(dayOffset: -2, hour: 9, amount: 1_000),
            entry(dayOffset: -2, hour: 15, amount: 1_000),
            entry(dayOffset: 0, hour: 19, amount: 1_000, isPlanEntry: true)
        ]
    }

    private func entry(
        dayOffset: Int,
        hour: Int,
        amount: Double,
        isPlanEntry: Bool = false
    ) -> HydrationEntry {
        let day = calendar.date(
            byAdding: .day,
            value: dayOffset,
            to: calendar.startOfDay(for: now)
        ) ?? now
        let date = calendar.date(byAdding: .hour, value: hour, to: day) ?? day
        return HydrationEntry(
            amountInMilliliters: amount,
            date: date,
            source: isPlanEntry ? .plan : .manual,
            planMomentID: isPlanEntry ? UUID() : nil,
            planRevision: isPlanEntry ? 0 : nil
        )
    }
}
