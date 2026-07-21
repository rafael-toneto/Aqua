import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    let modelContainer: ModelContainer
    let hydrationTrackingService: any HydrationTrackingServiceProtocol
    let hydrationGoalService: any HydrationGoalServiceProtocol
    let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    let dateProvider: any DateProviding

    init(
        isStoredInMemoryOnly: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    ) throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        let modelContainer = try ModelContainer(
            for: SwiftDataHydrationEntry.self,
            configurations: configuration
        )
        let repository = SwiftDataHydrationRepository(modelContext: modelContainer.mainContext)
        let preferencesStore = HydrationPreferencesStore()

        self.modelContainer = modelContainer
        hydrationTrackingService = HydrationTrackingService(repository: repository)
        hydrationGoalService = HydrationGoalService(preferencesStore: preferencesStore)
        quickAddAmountsService = QuickAddAmountsService(preferencesStore: preferencesStore)
        dateProvider = SystemDateProvider()
    }
}
