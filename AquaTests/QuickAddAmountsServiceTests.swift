import Foundation
import XCTest
@testable import Aqua

@MainActor
final class QuickAddAmountsServiceTests: XCTestCase {
    func testUsesDefaultAmountsWhenNothingHasBeenConfigured() async throws {
        let suiteName = "QuickAddAmountsServiceTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = HydrationPreferencesStore(userDefaults: userDefaults)
        let service = QuickAddAmountsService(preferencesStore: store)

        XCTAssertEqual(service.amountsInMilliliters, HydrationDefaults.quickAddAmountsInMilliliters)
    }

    func testConfiguredAmountsPersistAndCanBeReadByANewStore() async throws {
        let suiteName = "QuickAddAmountsServiceTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let service = QuickAddAmountsService(
            preferencesStore: HydrationPreferencesStore(userDefaults: userDefaults)
        )
        try service.updateAmounts([250, 450, 750])

        let reopenedService = QuickAddAmountsService(
            preferencesStore: HydrationPreferencesStore(userDefaults: userDefaults)
        )

        XCTAssertEqual(reopenedService.amountsInMilliliters, [250, 450, 750])
    }

    func testInvalidAmountsAreRejectedWithoutChangingSavedValues() async {
        let preferences = InMemoryHydrationPreferencesStore()
        let service = QuickAddAmountsService(preferencesStore: preferences)

        XCTAssertThrowsError(try service.updateAmounts([200, 0, 500])) { error in
            XCTAssertEqual(error as? HydrationError, .invalidQuickAddAmounts)
        }
        XCTAssertEqual(service.amountsInMilliliters, HydrationDefaults.quickAddAmountsInMilliliters)
    }

    func testAmountAboveSingleEntryLimitIsRejectedWithoutChangingSavedValues() async {
        let preferences = InMemoryHydrationPreferencesStore()
        let service = QuickAddAmountsService(preferencesStore: preferences)

        XCTAssertThrowsError(try service.updateAmounts([200, 30_000.001, 500])) { error in
            XCTAssertEqual(error as? HydrationError, .quickAddAmountExceedsLimit)
        }
        XCTAssertEqual(service.amountsInMilliliters, HydrationDefaults.quickAddAmountsInMilliliters)
    }

    func testPreviouslyStoredQuickAddAboveLimitFallsBackToDefaults() async throws {
        let suiteName = "QuickAddAmountsServiceTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let store = HydrationPreferencesStore(userDefaults: userDefaults)

        store.quickAddAmountsInMilliliters = [200, 30_000.001, 500]

        XCTAssertEqual(
            store.quickAddAmountsInMilliliters,
            HydrationDefaults.quickAddAmountsInMilliliters
        )
    }
}
