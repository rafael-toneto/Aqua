import SwiftData
import XCTest
@testable import Aqua

@MainActor
final class HydrationIntentHandlerTests: XCTestCase {
    private var calendar = Calendar(identifier: .gregorian)
    private var today = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        today = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 21, hour: 10)
        ) ?? Date(timeIntervalSince1970: 0)
    }

    func testZeroAmountIsRejected() {
        XCTAssertThrowsError(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: 0, unit: UnitVolume.milliliters)
            )
        ) { error in
            XCTAssertEqual(error as? HydrationIntentError, .amountMustBePositive)
        }
    }

    func testNegativeAmountIsRejected() {
        XCTAssertThrowsError(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: -300, unit: UnitVolume.milliliters)
            )
        ) { error in
            XCTAssertEqual(error as? HydrationIntentError, .amountMustBePositive)
        }
    }

    func testNonFiniteAmountsAreRejected() {
        for amount in [Double.nan, .infinity, -.infinity] {
            XCTAssertThrowsError(
                try HydrationIntentHandler.convertToMilliliters(
                    Measurement(value: amount, unit: UnitVolume.liters)
                )
            ) { error in
                XCTAssertEqual(error as? HydrationIntentError, .invalidAmount)
            }
        }
    }

    func testTechnicallyUnreasonableAmountIsRejected() {
        XCTAssertThrowsError(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: 10.001, unit: UnitVolume.liters)
            )
        ) { error in
            XCTAssertEqual(error as? HydrationIntentError, .amountTooLarge)
        }
    }

    func testMillilitersAreStoredWithoutUnitConversion() async throws {
        let repository = FakeHydrationRepository()
        let handler = makeHandler(repository: repository)

        _ = try await handler.logWater(
            amount: Measurement(value: 300, unit: UnitVolume.milliliters)
        )

        XCTAssertEqual(repository.storedEntries.first?.amountInMilliliters, 300)
    }

    func testLitersAreConvertedToMilliliters() async throws {
        let repository = FakeHydrationRepository()
        let handler = makeHandler(repository: repository)

        _ = try await handler.logWater(
            amount: Measurement(value: 1, unit: UnitVolume.liters)
        )

        XCTAssertEqual(repository.storedEntries.first?.amountInMilliliters, 1_000)
    }

    func testDecimalLitersRoundToNearestWholeMilliliter() throws {
        XCTAssertEqual(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: 0.5, unit: UnitVolume.liters)
            ),
            500
        )
        XCTAssertEqual(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: 0.3335, unit: UnitVolume.liters)
            ),
            334
        )
        XCTAssertEqual(
            try HydrationIntentHandler.convertToMilliliters(
                Measurement(value: 0.3334, unit: UnitVolume.liters)
            ),
            333
        )
    }

    func testFluidOuncesAreConvertedToMilliliters() async throws {
        let repository = FakeHydrationRepository()
        let handler = makeHandler(repository: repository)

        _ = try await handler.logWater(
            amount: Measurement(value: 8, unit: UnitVolume.fluidOunces)
        )

        XCTAssertEqual(repository.storedEntries.first?.amountInMilliliters, 237)
    }

    func testValidInputCallsSharedTrackingService() async throws {
        let repository = FakeHydrationRepository()
        let handler = makeHandler(repository: repository)

        _ = try await handler.logWater(
            amount: Measurement(value: 250, unit: UnitVolume.milliliters)
        )

        XCTAssertEqual(repository.storedEntries.count, 1)
    }

    func testSiriCreatedEntryUsesAppIntentSource() async throws {
        let repository = FakeHydrationRepository()
        let handler = makeHandler(repository: repository)

        _ = try await handler.logWater(
            amount: Measurement(value: 250, unit: UnitVolume.milliliters)
        )

        XCTAssertEqual(repository.storedEntries.first?.source, .appIntent)
    }

    func testProgressResponseUsesSharedDailyGoal() async throws {
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 1_000, date: today, source: .manual)
        ])
        let handler = makeHandler(repository: repository, dailyGoal: 2_000)

        let response = try await handler.hydrationProgress()

        XCTAssertTrue(response.contains("of your 2 liters goal"))
        XCTAssertTrue(response.contains("50 percent"))
    }

    func testRemainingWaterNeverBecomesNegative() async throws {
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 2_500, date: today, source: .manual)
        ])
        let handler = makeHandler(repository: repository, dailyGoal: 2_000)

        let response = try await handler.remainingWater()

        XCTAssertEqual(
            DailyHydrationProgress(consumedAmount: 2_500, dailyGoal: 2_000).remainingAmount,
            0
        )
        XCTAssertEqual(
            response,
            "You have already exceeded today’s hydration goal by 500 milliliters."
        )
    }

    func testCompletedGoalLogResponseIsCorrect() async throws {
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 1_700, date: today, source: .manual)
        ])
        let handler = makeHandler(repository: repository, dailyGoal: 2_000)

        let response = try await handler.logWater(
            amount: Measurement(value: 300, unit: UnitVolume.milliliters)
        )

        XCTAssertEqual(
            response,
            "300 milliliters added. You have reached today’s hydration goal."
        )
    }

    func testPersistenceErrorBecomesUserFriendlyError() async {
        let handler = makeHandler(repository: FailingHydrationRepository())

        do {
            _ = try await handler.logWater(
                amount: Measurement(value: 300, unit: UnitVolume.milliliters)
            )
            XCTFail("Expected the save to fail")
        } catch {
            XCTAssertEqual(error as? HydrationIntentError, .saveFailed)
            XCTAssertEqual(
                error.localizedDescription,
                "AquaFlow could not save this water entry. Please try again."
            )
        }
    }

    func testIntentCreatedEntryAppearsThroughSwiftDataRepository() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: SwiftDataHydrationEntry.self,
            configurations: configuration
        )
        let repository = SwiftDataHydrationRepository(modelContext: container.mainContext)
        let trackingService = HydrationTrackingService(repository: repository, calendar: calendar)
        let goalService = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore()
        )
        let handler = HydrationIntentHandler(
            trackingService: trackingService,
            goalService: goalService,
            dateProvider: FixedDateProvider(now: today)
        )

        _ = try await handler.logWater(
            amount: Measurement(value: 500, unit: UnitVolume.milliliters)
        )
        let entries = try await trackingService.entries(for: today)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.amountInMilliliters, 500)
        XCTAssertEqual(entries.first?.source, .appIntent)
    }

    func testChangingDailyGoalChangesIntentResponse() async throws {
        let repository = FakeHydrationRepository(entries: [
            HydrationEntry(amountInMilliliters: 1_000, date: today, source: .manual)
        ])
        let preferences = InMemoryHydrationPreferencesStore(dailyGoalInMilliliters: 2_000)
        let goalService = HydrationGoalService(preferencesStore: preferences)
        let handler = HydrationIntentHandler(
            trackingService: HydrationTrackingService(repository: repository, calendar: calendar),
            goalService: goalService,
            dateProvider: FixedDateProvider(now: today)
        )

        let initialResponse = try await handler.hydrationProgress()
        try goalService.updateDailyGoal(to: 4_000)
        let updatedResponse = try await handler.hydrationProgress()

        XCTAssertTrue(initialResponse.contains("50 percent"))
        XCTAssertTrue(updatedResponse.contains("25 percent"))
        XCTAssertTrue(updatedResponse.contains("4 liters goal"))
    }

    private func makeHandler(
        repository: any HydrationRepository,
        dailyGoal: Double = 2_000
    ) -> HydrationIntentHandler {
        let preferences = InMemoryHydrationPreferencesStore(
            dailyGoalInMilliliters: dailyGoal
        )
        return HydrationIntentHandler(
            trackingService: HydrationTrackingService(repository: repository, calendar: calendar),
            goalService: HydrationGoalService(preferencesStore: preferences),
            dateProvider: FixedDateProvider(now: today)
        )
    }
}

@MainActor
private final class FailingHydrationRepository: HydrationRepository {
    private enum Failure: Error {
        case expected
    }

    func add(_ entry: HydrationEntry) async throws {
        throw Failure.expected
    }

    func deleteEntry(id: UUID) async throws {}

    func entries(for date: Date, calendar: Calendar) async throws -> [HydrationEntry] {
        []
    }

    func entries(from startDate: Date, to endDate: Date) async throws -> [HydrationEntry] {
        []
    }
}
