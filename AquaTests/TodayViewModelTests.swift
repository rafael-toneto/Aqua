import XCTest
@testable import Aqua

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testQuickAddImmediatelyRefreshesEntriesAndProgress() async throws {
        let calendar = fixedCalendar()
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9))
        )
        let repository = FakeHydrationRepository()
        let trackingService = HydrationTrackingService(repository: repository, calendar: calendar)
        let preferences = InMemoryHydrationPreferencesStore()
        let goalService = HydrationGoalService(preferencesStore: preferences)
        let viewModel = TodayViewModel(
            trackingService: trackingService,
            goalService: goalService,
            dateProvider: FixedDateProvider(now: date)
        )

        await viewModel.addQuickWater(amountInMilliliters: 300)

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.entries.first?.source, .quickAdd)
        XCTAssertEqual(viewModel.progress.consumedAmount, 300, accuracy: 0.001)
        XCTAssertEqual(viewModel.feedbackTrigger, 1)
    }

    func testDeletingEntryImmediatelyRefreshesProgress() async throws {
        let calendar = fixedCalendar()
        let date = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9))
        )
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 200, date: date, source: .quickAdd),
            HydrationEntry(amountInMilliliters: 500, date: date, source: .quickAdd)
        ])
        let trackingService = HydrationTrackingService(repository: repository, calendar: calendar)
        let goalService = HydrationGoalService(preferencesStore: InMemoryHydrationPreferencesStore())
        let viewModel = TodayViewModel(
            trackingService: trackingService,
            goalService: goalService,
            dateProvider: FixedDateProvider(now: date)
        )
        await viewModel.load()

        await viewModel.deleteEntries(at: IndexSet(integer: 0))

        XCTAssertEqual(viewModel.entries.count, 1)
        XCTAssertEqual(viewModel.progress.consumedAmount, 500, accuracy: 0.001)
    }
}
