import Foundation
import SwiftData

@MainActor
final class AppDependencies {
    static let shared: Result<AppDependencies, Error> = Result {
        try AppDependencies()
    }

    let modelContainer: ModelContainer
    let hydrationRepository: any HydrationRepository
    let hydrationTrackingService: any HydrationTrackingServiceProtocol
    let hydrationGoalService: any HydrationGoalServiceProtocol
    let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    let dateProvider: any DateProviding
    let hydrationIntentHandler: any HydrationIntentHandling

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
        let hydrationTrackingService = HydrationTrackingService(repository: repository)
        let hydrationGoalService = HydrationGoalService(preferencesStore: preferencesStore)
        let dateProvider = SystemDateProvider()

        self.modelContainer = modelContainer
        hydrationRepository = repository
        self.hydrationTrackingService = hydrationTrackingService
        self.hydrationGoalService = hydrationGoalService
        quickAddAmountsService = QuickAddAmountsService(preferencesStore: preferencesStore)
        self.dateProvider = dateProvider
        hydrationIntentHandler = HydrationIntentHandler(
            trackingService: hydrationTrackingService,
            goalService: hydrationGoalService,
            dateProvider: dateProvider
        )
    }
}
