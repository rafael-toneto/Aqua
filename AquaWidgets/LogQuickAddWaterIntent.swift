import AppIntents
import Foundation
import SwiftData
import WidgetKit

struct LogQuickAddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Water"
    static let description = IntentDescription("Logs a configured quick-add amount in AquaFlow.")
    static let openAppWhenRun = false
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false

    @Parameter(title: "Amount in milliliters")
    var amountInMilliliters: Double

    init() {}

    init(amountInMilliliters: Double) {
        self.amountInMilliliters = amountInMilliliters
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard amountInMilliliters.isFinite,
              amountInMilliliters > 0,
              amountInMilliliters <= 10_000 else {
            throw LogQuickAddWaterError.invalidAmount
        }

        let modelContainer = try AquaSharedStore.makeModelContainer()
        let modelContext = ModelContext(modelContainer)
        modelContext.insert(
            SwiftDataHydrationEntry(
                id: UUID(),
                amountInMilliliters: amountInMilliliters,
                date: Date(),
                sourceRawValue: "widget"
            )
        )
        try modelContext.save()

        WidgetCenter.shared.reloadTimelines(ofKind: AquaSharedStore.widgetKind)
        return .result()
    }
}

private enum LogQuickAddWaterError: LocalizedError {
    case invalidAmount

    var errorDescription: String? {
        "This quick-add amount is invalid. Open AquaFlow Settings and configure it again."
    }
}
