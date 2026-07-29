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
    let adaptivePlanService: AdaptivePlanService
    let hydrationInsightsGenerator: any HydrationInsightsGenerating
    let hydrationInsightsService: HydrationInsightsService
    let planningPreferencesStore: any PlanningPreferencesStoring
    private let dynamicPlanSynchronizer: DynamicPlanSynchronizer

    init(
        isStoredInMemoryOnly: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    ) throws {
        if !isStoredInMemoryOnly {
            AquaSharedStore.migrateLegacyPreferencesIfNeeded()
            try AquaSharedStore.migrateLegacyModelStoreIfNeeded()
        }
        let modelContainer = try AquaSharedStore.makeModelContainer(
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        let repository = SwiftDataHydrationRepository(modelContext: modelContainer.mainContext)
        let planRepository = SwiftDataDailyPlanRepository(modelContext: modelContainer.mainContext)
        let preferencesStore = HydrationPreferencesStore()
        let planningPreferencesStore = PlanningPreferencesStore()
        let hydrationTrackingService = HydrationTrackingService(repository: repository)
        let hydrationGoalService = HydrationGoalService(preferencesStore: preferencesStore)
        let dateProvider = SystemDateProvider()
        let insightsGenerator = FoundationModelsInsightsGenerator()

        let adaptivePlanService = AdaptivePlanService(
            trackingService: hydrationTrackingService,
            goalService: hydrationGoalService,
            preferencesStore: planningPreferencesStore,
            repository: planRepository,
            adaptiveGenerator: FoundationModelsAdaptivePlanGenerator(),
            fallbackGenerator: DeterministicAdaptivePlanGenerator()
        )
        let insightsService = HydrationInsightsService(
            trackingService: hydrationTrackingService,
            goalService: hydrationGoalService,
            generator: insightsGenerator
        )
        let dynamicPlanSynchronizer = DynamicPlanSynchronizer(
            planService: adaptivePlanService,
            dateProvider: dateProvider
        )
        hydrationTrackingService.setEntriesChangeObserver(dynamicPlanSynchronizer)

        self.modelContainer = modelContainer
        hydrationRepository = repository
        self.hydrationTrackingService = hydrationTrackingService
        self.hydrationGoalService = hydrationGoalService
        quickAddAmountsService = QuickAddAmountsService(preferencesStore: preferencesStore)
        self.dateProvider = dateProvider
        self.planningPreferencesStore = planningPreferencesStore
        self.adaptivePlanService = adaptivePlanService
        hydrationInsightsGenerator = insightsGenerator
        hydrationInsightsService = insightsService
        self.dynamicPlanSynchronizer = dynamicPlanSynchronizer
        hydrationIntentHandler = HydrationIntentHandler(
            trackingService: hydrationTrackingService,
            goalService: hydrationGoalService,
            dateProvider: dateProvider
        )
    }
}
