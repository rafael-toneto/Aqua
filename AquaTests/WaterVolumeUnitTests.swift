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
