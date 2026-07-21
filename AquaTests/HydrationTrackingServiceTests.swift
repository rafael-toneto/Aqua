import XCTest
@testable import Aqua

@MainActor
final class HydrationTrackingServiceTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
    }

    func testProgressCalculatesDailyConsumedWater() async throws {
        let day = try date(year: 2026, month: 7, day: 20, hour: 12)
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 250, date: day, source: .manual),
            HydrationEntry(amountInMilliliters: 500, date: day, source: .quickAdd)
        ])
        let service = HydrationTrackingService(repository: repository, calendar: calendar)

        let progress = try await service.progress(for: day, dailyGoal: 2_000)

        XCTAssertEqual(progress.consumedAmount, 750, accuracy: 0.001)
    }

    func testProgressCalculatesRemainingWater() {
        let progress = DailyHydrationProgress(consumedAmount: 1_250, dailyGoal: 2_000)

        XCTAssertEqual(progress.remainingAmount, 750, accuracy: 0.001)
    }

    func testRemainingWaterNeverBecomesNegative() {
        let progress = DailyHydrationProgress(consumedAmount: 2_500, dailyGoal: 2_000)

        XCTAssertEqual(progress.remainingAmount, 0, accuracy: 0.001)
    }

    func testProgressCalculatesCompletionPercentage() {
        let progress = DailyHydrationProgress(consumedAmount: 1_250, dailyGoal: 2_000)

        XCTAssertEqual(progress.completionPercentage, 62.5, accuracy: 0.001)
    }

    func testIntakeAboveGoalKeepsRealTotalAndCapsVisualProgress() {
        let progress = DailyHydrationProgress(consumedAmount: 2_500, dailyGoal: 2_000)

        XCTAssertEqual(progress.consumedAmount, 2_500, accuracy: 0.001)
        XCTAssertEqual(progress.remainingAmount, 0, accuracy: 0.001)
        XCTAssertEqual(progress.completionPercentage, 100, accuracy: 0.001)
        XCTAssertTrue(progress.hasReachedGoal)
    }

    func testAddingZeroOrNegativeAmountIsRejected() async throws {
        let day = try date(year: 2026, month: 7, day: 20, hour: 12)
        let repository = FakeHydrationRepository()
        let service = HydrationTrackingService(repository: repository, calendar: calendar)

        for invalidAmount in [0.0, -250.0] {
            do {
                try await service.addWater(
                    amountInMilliliters: invalidAmount,
                    date: day,
                    source: .manual
                )
                XCTFail("Expected \(invalidAmount) ml to be rejected")
            } catch {
                XCTAssertEqual(error as? HydrationError, .invalidAmount)
            }
        }

        XCTAssertTrue(repository.storedEntries.isEmpty)
    }

    func testEntriesAreSeparatedByInjectedCalendarDay() async throws {
        let firstDay = try date(year: 2026, month: 7, day: 20, hour: 23)
        let secondDay = try date(year: 2026, month: 7, day: 21, hour: 1)
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 300, date: firstDay, source: .quickAdd),
            HydrationEntry(amountInMilliliters: 500, date: secondDay, source: .quickAdd)
        ])
        let service = HydrationTrackingService(repository: repository, calendar: calendar)

        let firstDayProgress = try await service.progress(for: firstDay, dailyGoal: 2_000)
        let secondDayProgress = try await service.progress(for: secondDay, dailyGoal: 2_000)

        XCTAssertEqual(firstDayProgress.consumedAmount, 300, accuracy: 0.001)
        XCTAssertEqual(secondDayProgress.consumedAmount, 500, accuracy: 0.001)
    }

    func testProgressUpdatesAfterAddingEntry() async throws {
        let day = try date(year: 2026, month: 7, day: 20, hour: 12)
        let repository = FakeHydrationRepository()
        let service = HydrationTrackingService(repository: repository, calendar: calendar)

        try await service.addWater(amountInMilliliters: 300, date: day, source: .quickAdd)
        let progress = try await service.progress(for: day, dailyGoal: 2_000)

        XCTAssertEqual(progress.consumedAmount, 300, accuracy: 0.001)
    }

    func testProgressUpdatesAfterDeletingEntry() async throws {
        let day = try date(year: 2026, month: 7, day: 20, hour: 12)
        let entryToDelete = HydrationEntry(amountInMilliliters: 300, date: day, source: .quickAdd)
        let repository = FakeHydrationRepository(entries: [
            entryToDelete,
            HydrationEntry(amountInMilliliters: 500, date: day, source: .quickAdd)
        ])
        let service = HydrationTrackingService(repository: repository, calendar: calendar)

        try await service.deleteEntry(id: entryToDelete.id)
        let progress = try await service.progress(for: day, dailyGoal: 2_000)

        XCTAssertEqual(progress.consumedAmount, 500, accuracy: 0.001)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
        try XCTUnwrap(
            calendar.date(from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            ))
        )
    }
}
