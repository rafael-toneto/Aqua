import Foundation
import WidgetKit

@MainActor
protocol QuickAddAmountsServiceProtocol: AnyObject {
    var amountsInMilliliters: [Double] { get }
    func updateAmounts(_ amountsInMilliliters: [Double]) throws
}

@MainActor
final class QuickAddAmountsService: QuickAddAmountsServiceProtocol {
    private let preferencesStore: any HydrationPreferencesStoring

    init(preferencesStore: any HydrationPreferencesStoring) {
        self.preferencesStore = preferencesStore
    }

    var amountsInMilliliters: [Double] {
        preferencesStore.quickAddAmountsInMilliliters
    }

    func updateAmounts(_ amountsInMilliliters: [Double]) throws {
        guard amountsInMilliliters.count == HydrationDefaults.quickAddAmountsInMilliliters.count,
              amountsInMilliliters.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            throw HydrationError.invalidQuickAddAmounts
        }
        guard amountsInMilliliters.allSatisfy({
            $0 <= HydrationLimits.maximumSingleEntryInMilliliters
        }) else {
            throw HydrationError.quickAddAmountExceedsLimit
        }

        preferencesStore.quickAddAmountsInMilliliters = amountsInMilliliters
        WidgetCenter.shared.reloadTimelines(ofKind: AquaSharedStore.widgetKind)
    }
}
