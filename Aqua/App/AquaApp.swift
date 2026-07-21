import SwiftData
import SwiftUI

@main
struct AquaApp: App {
    private let dependenciesResult: Result<AppDependencies, Error>

    init() {
        do {
            dependenciesResult = .success(try AppDependencies())
        } catch {
            dependenciesResult = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch dependenciesResult {
            case .success(let dependencies):
                AquaRootView(
                    trackingService: dependencies.hydrationTrackingService,
                    goalService: dependencies.hydrationGoalService,
                    dateProvider: dependencies.dateProvider
                )
                .modelContainer(dependencies.modelContainer)

            case .failure(let error):
                AquaStartupErrorView(error: error)
            }
        }
    }
}
