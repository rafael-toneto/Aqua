import AppIntents
import SwiftData
import SwiftUI

@main
struct AquaApp: App {
    private let dependenciesResult: Result<AppDependencies, Error>

    init() {
        AquaShortcutsProvider.updateAppShortcutParameters()
        dependenciesResult = AppDependencies.shared
    }

    var body: some Scene {
        WindowGroup {
            switch dependenciesResult {
            case .success(let dependencies):
                AquaRootView(
                    trackingService: dependencies.hydrationTrackingService,
                    goalService: dependencies.hydrationGoalService,
                    quickAddAmountsService: dependencies.quickAddAmountsService,
                    dateProvider: dependencies.dateProvider,
                    adaptivePlanService: dependencies.adaptivePlanService,
                    insightsService: dependencies.hydrationInsightsService,
                    planningPreferencesStore: dependencies.planningPreferencesStore
                )
                .modelContainer(dependencies.modelContainer)

            case .failure(let error):
                AquaStartupErrorView(error: error)
            }
        }
    }
}
