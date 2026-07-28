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

    func testCalculatesMetricsUsingOnlyRecordedDays() async throws {
        let report = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)
        let snapshot = report.snapshot
        let expectedStart = day(offset: -4)

        XCTAssertEqual(snapshot.periodStart, expectedStart)
        XCTAssertEqual(snapshot.periodEnd, calendar.startOfDay(for: now))
        XCTAssertEqual(snapshot.analyzedDayCount, 5)
        XCTAssertEqual(snapshot.daysWithEntries, 5)
        XCTAssertEqual(snapshot.daysWithoutEntries, 0)
        XCTAssertEqual(snapshot.totalEntryCount, 8)
        XCTAssertEqual(snapshot.goalAchievementPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(snapshot.averageDailyConsumptionMilliliters, 1_300, accuracy: 0.001)
        XCTAssertEqual(snapshot.averageEntriesPerDay, 1.6, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageFirstEntryMinutes), 696, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageLastEntryMinutes), 900, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(snapshot.averageIntervalMinutes), 340, accuracy: 0.001)
        XCTAssertEqual(snapshot.planMomentAdherencePercentage, 12.5, accuracy: 0.001)
        XCTAssertEqual(report.availability, .available)
    }

    func testGoalAdherenceAndLateDayConcentrationUseRecordedVolume() async throws {
        let report = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)

        XCTAssertEqual(report.snapshot.goalAchievementPercentage, 40, accuracy: 0.001)
        XCTAssertEqual(
            report.snapshot.lateDayConsumptionPercentage,
            2_000.0 / 6_500.0 * 100,
            accuracy: 0.001
        )
        XCTAssertEqual(
            report.snapshot.eveningConsumptionPercentage,
            2_000.0 / 6_500.0 * 100,
            accuracy: 0.001
        )
        XCTAssertEqual(report.snapshot.recentTrendPercentage, -62.5, accuracy: 0.001)
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

    func testValidGeneratedInsightsSurviveAnInvalidSibling() async throws {
        let baseline = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)
        let valid = try XCTUnwrap(baseline.insights.first)
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
        let generator = MockHydrationInsightsGenerator(result: .success([valid, invalid]))

        let report = try await makeService(
            entries: representativeEntries(),
            generator: generator
        ).insights(asOf: now)

        XCTAssertEqual(report.insights, [valid])
    }

    func testValidatorAcceptsSnapshotNumbersAndRejectsInventedNumbers() async throws {
        let baseline = try await makeService(
            entries: representativeEntries()
        ).insights(asOf: now)
        let snapshot = baseline.snapshot
        let supported = HydrationInsight(
            id: "supported-number",
            title: "Goal progress",
            description: "Goal achievement is 40 percent across the analyzed window.",
            evidence: snapshot.evidence(for: .goalAchievement),
            evidenceMetric: .goalAchievement,
            suggestedAction: "Keep logging consistently.",
            category: .goalProgress,
            priority: .medium
        )
        let invented = HydrationInsight(
            id: "invented-number",
            title: "Goal progress",
            description: "Goal achievement is 99.9 percent across the analyzed window.",
            evidence: snapshot.evidence(for: .goalAchievement),
            evidenceMetric: .goalAchievement,
            suggestedAction: "Keep logging consistently.",
            category: .goalProgress,
            priority: .medium
        )
        let validator = HydrationInsightsValidator()

        XCTAssertTrue(validator.validate([supported], against: snapshot))
        XCTAssertFalse(validator.validate([invented], against: snapshot))
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

    func testFewerThanFiveRecordedDaysDoNotInvokeFoundationModelsAgent() async throws {
        let generator = MockHydrationInsightsGenerator(
            result: .failure(HydrationInsightsGenerationError.generationFailed)
        )
        let report = try await makeService(
            entries: [
                entry(dayOffset: -2, hour: 10, amount: 500),
                entry(dayOffset: -1, hour: 10, amount: 500),
                entry(dayOffset: 0, hour: 10, amount: 500)
            ],
            generator: generator
        ).insights(asOf: now)

        XCTAssertFalse(report.snapshot.hasSufficientHistory)
        XCTAssertEqual(report.snapshot.daysWithEntries, 3)
        XCTAssertEqual(report.insights, [])
        XCTAssertEqual(report.availability, .needsMoreRecordedDays(recordedDayCount: 3))
        XCTAssertEqual(generator.callCount, 0)
    }

    func testExactlyFiveRecentRecordedDaysProduceInsights() async throws {
        let report = try await makeService(
            entries: (-4...0).map {
                entry(dayOffset: $0, hour: 10, amount: 500)
            }
        ).insights(asOf: now)

        XCTAssertTrue(report.snapshot.hasSufficientHistory)
        XCTAssertEqual(report.snapshot.analyzedDayCount, 5)
        XCTAssertEqual(report.availability, .available)
        XCTAssertEqual(report.insights.count, 3)
    }

    func testEightRecordedDaysUseAllEightDays() async throws {
        let report = try await makeService(
            entries: (-7...0).map {
                entry(dayOffset: $0, hour: 10, amount: Double(800 + $0))
            }
        ).insights(asOf: now)

        XCTAssertEqual(report.snapshot.analyzedDayCount, 8)
        XCTAssertEqual(report.snapshot.daysWithEntries, 8)
        XCTAssertEqual(report.snapshot.periodStart, day(offset: -7))
        XCTAssertEqual(report.snapshot.periodEnd, day(offset: 0))
    }

    func testSixtyRecordedDaysUseOnlyTheLatestFourteenRecordedDays() async throws {
        let report = try await makeService(
            entries: (-59...0).map {
                entry(dayOffset: $0, hour: 10, amount: Double(1_000 + $0))
            }
        ).insights(asOf: now)

        XCTAssertEqual(report.snapshot.analyzedDayCount, 14)
        XCTAssertEqual(report.snapshot.daysWithEntries, 14)
        XCTAssertEqual(report.snapshot.totalEntryCount, 14)
        XCTAssertEqual(report.snapshot.periodStart, day(offset: -13))
        XCTAssertEqual(report.snapshot.periodEnd, day(offset: 0))
        XCTAssertEqual(
            report.snapshot.averageDailyConsumptionMilliliters,
            (-13...0).map { Double(1_000 + $0) }.reduce(0, +) / 14,
            accuracy: 0.001
        )
    }

    func testFiveDaysWithoutRecordsBlockInsightsAndSkipGenerator() async throws {
        let generator = MockHydrationInsightsGenerator(
            result: .failure(HydrationInsightsGenerationError.generationFailed)
        )
        let report = try await makeService(
            entries: (-9 ... -5).map {
                entry(dayOffset: $0, hour: 10, amount: 500)
            },
            generator: generator
        ).insights(asOf: now)

        XCTAssertEqual(report.availability, .needsRecentRecordedDays(recordedDayCount: 0))
        XCTAssertTrue(report.insights.isEmpty)
        XCTAssertEqual(generator.callCount, 0)
    }

    func testFourDaysWithoutRecordsKeepInsightsAvailable() async throws {
        let report = try await makeService(
            entries: (-8 ... -4).map {
                entry(dayOffset: $0, hour: 10, amount: 500)
            }
        ).insights(asOf: now)

        XCTAssertEqual(report.availability, .available)
        XCTAssertEqual(report.insights.count, 3)
    }

    func testInsightsReturnOnlyAfterFiveNewRecordedDaysFollowingInactivity() async throws {
        let oldEntries = (-14 ... -10).map {
            entry(dayOffset: $0, hour: 10, amount: 500)
        }
        let fourRecentEntries = (-3...0).map {
            entry(dayOffset: $0, hour: 10, amount: 750)
        }
        let blockedReport = try await makeService(
            entries: oldEntries + fourRecentEntries
        ).insights(asOf: now)

        XCTAssertEqual(
            blockedReport.availability,
            .needsRecentRecordedDays(recordedDayCount: 4)
        )
        XCTAssertEqual(blockedReport.snapshot.analyzedDayCount, 4)
        XCTAssertTrue(blockedReport.insights.isEmpty)

        let unlockedReport = try await makeService(
            entries: oldEntries + [
                entry(dayOffset: -4, hour: 10, amount: 750)
            ] + fourRecentEntries
        ).insights(asOf: now)

        XCTAssertEqual(unlockedReport.availability, .available)
        XCTAssertEqual(unlockedReport.snapshot.analyzedDayCount, 5)
        XCTAssertEqual(unlockedReport.snapshot.periodStart, day(offset: -4))
        XCTAssertEqual(unlockedReport.snapshot.periodEnd, day(offset: 0))
        XCTAssertEqual(unlockedReport.insights.count, 3)
    }

    func testNoRecordedEntriesDoNotInvokeFoundationModelsAgent() async throws {
        let generator = MockHydrationInsightsGenerator(
            result: .failure(HydrationInsightsGenerationError.generationFailed)
        )
        let report = try await makeService(
            entries: [],
            generator: generator
        ).insights(asOf: now)

        XCTAssertFalse(report.snapshot.hasSufficientHistory)
        XCTAssertTrue(report.insights.isEmpty)
        XCTAssertEqual(report.availability, .needsMoreRecordedDays(recordedDayCount: 0))
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
            entry(dayOffset: -3, hour: 9, amount: 1_000),
            entry(dayOffset: -3, hour: 15, amount: 1_000),
            entry(dayOffset: -2, hour: 19, amount: 1_000, isPlanEntry: true),
            entry(dayOffset: -1, hour: 12, amount: 500),
            entry(dayOffset: 0, hour: 10, amount: 1_000)
        ]
    }

    private func day(offset: Int) -> Date {
        calendar.date(
            byAdding: .day,
            value: offset,
            to: calendar.startOfDay(for: now)
        ) ?? .distantPast
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
