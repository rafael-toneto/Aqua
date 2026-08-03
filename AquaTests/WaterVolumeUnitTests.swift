import XCTest
@testable import Aqua

@MainActor
final class WaterVolumeUnitTests: XCTestCase {
    func testFluidOuncesAreConvertedToMillilitersForStorage() async throws {
        let amountInMilliliters = try XCTUnwrap(
            WaterAmountFormatter.milliliters(
                fromDisplayedText: "8",
                unit: .fluidOunces
            )
        )

        XCTAssertEqual(amountInMilliliters, 236.5882365, accuracy: 0.000_001)
    }

    func testPrecisePlanAmountsKeepTwoFractionDigitsInLiters() {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."

        XCTAssertEqual(
            WaterAmountFormatter.preciseString(from: 3_100),
            "3\(decimalSeparator)10 L"
        )
        XCTAssertEqual(
            WaterAmountFormatter.preciseString(from: 3_380),
            "3\(decimalSeparator)38 L"
        )
        XCTAssertEqual(WaterAmountFormatter.preciseString(from: 285), "285 ml")
    }

    func testAddWaterViewModelUsesTheSelectedDisplayUnit() async throws {
        let repository = FakeHydrationRepository()
        let trackingService = HydrationTrackingService(repository: repository)
        let viewModel = AddWaterViewModel(
            trackingService: trackingService,
            dateProvider: FixedDateProvider(now: Date()),
            waterVolumeUnit: .fluidOunces
        )

        viewModel.amountText = "8.5"

        XCTAssertEqual(
            try XCTUnwrap(viewModel.amountInMilliliters),
            251.375_001_281_25,
            accuracy: 0.000_001
        )
    }

    func testAddWaterLimitIsAppliedAfterFluidOunceConversion() async {
        let repository = FakeHydrationRepository()
        let viewModel = AddWaterViewModel(
            trackingService: HydrationTrackingService(repository: repository),
            dateProvider: FixedDateProvider(now: Date()),
            waterVolumeUnit: .fluidOunces
        )

        viewModel.amountText = "1014.4"
        XCTAssertTrue(viewModel.canSave)

        viewModel.amountText = "1014.5"
        XCTAssertFalse(viewModel.canSave)
        let didSave = await viewModel.save()

        XCTAssertFalse(didSave)
        XCTAssertEqual(
            viewModel.errorMessage,
            HydrationError.amountExceedsSingleEntryLimit.localizedDescription
        )
        XCTAssertTrue(repository.storedEntries.isEmpty)
    }

    func testDailyGoalLimitIsAppliedAfterFluidOunceConversion() async throws {
        let suiteName = "WaterVolumeUnitTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let preferencesStore = InMemoryHydrationPreferencesStore()
        let viewModel = SettingsViewModel(
            goalService: HydrationGoalService(preferencesStore: preferencesStore),
            quickAddAmountsService: QuickAddAmountsService(preferencesStore: preferencesStore),
            userDefaults: userDefaults
        )
        viewModel.toggleVolumeDisplayUnit()

        viewModel.goalText = "1014.5"
        viewModel.save()

        XCTAssertEqual(
            viewModel.errorMessage,
            HydrationError.dailyGoalExceedsLimit.localizedDescription
        )
        XCTAssertEqual(
            preferencesStore.dailyGoalInMilliliters,
            HydrationDefaults.dailyGoalInMilliliters,
            accuracy: 0.001
        )
    }

    func testSettingsUnitPreferencePersists() async throws {
        let suiteName = "WaterVolumeUnitTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let preferencesStore = InMemoryHydrationPreferencesStore()
        let viewModel = SettingsViewModel(
            goalService: HydrationGoalService(preferencesStore: preferencesStore),
            quickAddAmountsService: QuickAddAmountsService(preferencesStore: preferencesStore),
            userDefaults: userDefaults
        )

        viewModel.toggleVolumeDisplayUnit()

        XCTAssertEqual(viewModel.volumeDisplayUnit, .fluidOunces)
        XCTAssertEqual(
            userDefaults.string(forKey: WaterVolumeUnit.preferenceKey),
            WaterVolumeUnit.fluidOunces.rawValue
        )
    }
}
