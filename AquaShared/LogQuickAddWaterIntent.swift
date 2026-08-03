import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// This intent belongs to both the app and widget-extension targets. Conforming to
/// `LiveActivityIntent` makes WidgetKit run it in the app process, where ActivityKit
/// can access and update the app's active Live Activities.
struct LogQuickAddWaterIntent: LiveActivityIntent {
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
              amountInMilliliters <= HydrationLimits.maximumSingleEntryInMilliliters else {
            throw LogQuickAddWaterError.invalidAmount
        }

        let now = Date()
        let modelContainer = try AquaSharedStore.makeModelContainer()
        let modelContext = ModelContext(modelContainer)
        modelContext.insert(
            SwiftDataHydrationEntry(
                id: UUID(),
                amountInMilliliters: amountInMilliliters,
                date: now,
                sourceRawValue: "widget"
            )
        )
        try modelContext.save()

        await updateLiveActivity(using: modelContext, now: now)
        WidgetCenter.shared.reloadTimelines(ofKind: AquaSharedStore.widgetKind)
        return .result()
    }

    @MainActor
    private func updateLiveActivity(using modelContext: ModelContext, now: Date) async {
        guard AquaSharedStore.liveActivitiesEnabled else { return }

        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: day) else { return }

        let descriptor = FetchDescriptor<SwiftDataHydrationEntry>(
            predicate: #Predicate { entry in
                entry.date >= day && entry.date < endOfDay
            }
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        let consumed = entries.reduce(0) { total, entry in
            total + max(entry.amountInMilliliters, 0)
        }
        let storedGoal = AquaSharedStore.userDefaults.double(
            forKey: AquaSharedStore.PreferenceKey.dailyGoalInMilliliters
        )
        let goal = storedGoal.isFinite
            && storedGoal > 0
            && storedGoal <= HydrationLimits.maximumDailyGoalInMilliliters
            ? storedGoal
            : HydrationDefaults.dailyGoalInMilliliters
        await HydrationLiveActivityCoordinator.synchronize(
            consumedInMilliliters: consumed,
            goalInMilliliters: goal,
            usesFluidOunces: AquaSharedStore.userDefaults.string(
                forKey: AquaSharedStore.PreferenceKey.volumeDisplayUnit
            ) == "fluidOunces",
            now: now,
            calendar: calendar
        )
    }
}

private enum LogQuickAddWaterError: LocalizedError {
    case invalidAmount

    var errorDescription: String? {
        "This quick-add amount is invalid. Open AquaFlow Settings and configure it again."
    }
}
