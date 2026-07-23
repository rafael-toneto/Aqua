import XCTest
@testable import Aqua

@MainActor
final class DynamicPlanSynchronizationTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var now = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 10)
        ) ?? .distantPast
    }

    func testAppIntentCreatesFoundationPlanWithoutPlanView() async throws {
        let validDraft = try await validDistributionDraft(
            goal: 4_000,
            consumedAmount: 250
        )
        let setup = makeSetup(adaptiveResult: .success(validDraft))
        let handler = HydrationIntentHandler(
            trackingService: setup.trackingService,
            goalService: setup.goalService,
            dateProvider: setup.dateProvider
        )

        _ = try await handler.logWater(
            amount: Measurement(value: 250, unit: UnitVolume.milliliters)
        )

        let plan = try XCTUnwrap(try setup.planRepository.plan(for: now))
        XCTAssertEqual(plan.generationSource, .foundationModels)
        XCTAssertEqual(plan.consumedMillilitersAtGeneration, 250)
        XCTAssertEqual(plan.revision, 0)
        XCTAssertEqual(currentRevisionTotal(in: plan), 3_750)
        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
    }

    func testQuickAddSynchronizesExistingPlanWithoutRegeneratingIt() async throws {
        let setup = makeSetup(adaptiveResult: .failure(PlanGenerationError.unavailable))

        try await setup.trackingService.addWater(
            amountInMilliliters: 250,
            date: now,
            source: .quickAdd
        )
        let initialPlan = try XCTUnwrap(try setup.planRepository.plan(for: now))

        var preferences = setup.service.planningPreferences
        preferences.preferredMomentCount = 2
        preferences.preferredAmountMilliliters = 10_000
        preferences.minimumIntervalMinutes = 90
        preferences.automaticRedistributionEnabled = false
        preferences.mayAddMoments = false
        try setup.service.updatePlanningPreferences(preferences)

        setup.dateProvider.now = now.addingTimeInterval(60)
        try await setup.trackingService.addWater(
            amountInMilliliters: 250,
            date: setup.dateProvider.now,
            source: .quickAdd
        )

        let updatedPlan = try XCTUnwrap(try setup.planRepository.plan(for: now))
        XCTAssertEqual(updatedPlan.revision, initialPlan.revision)
        XCTAssertEqual(updatedPlan.consumedMillilitersAtGeneration, 250)
        XCTAssertEqual(updatedPlan.moments.map(\.id), initialPlan.moments.map(\.id))
        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
    }

    func testAddingPlannedAmountCompletesMomentWithoutRegeneratingSchedule() async throws {
        let setup = makeSetup(adaptiveResult: .success(draft(total: 4_000)))
        let initialPlan = try await loadedPlan(
            from: setup.service.preparePlan(now: now, forceRegeneration: true)
        )
        let completedMoment = try XCTUnwrap(initialPlan.moments.first)
        let untouchedMomentIDs = Set(initialPlan.moments.dropFirst().map(\.id))
        setup.dateProvider.now = completedMoment.scheduledDate.addingTimeInterval(3 * 60 * 60)

        let updatedPlan = try await loadedPlan(
            from: setup.service.addPlannedAmount(
                for: completedMoment,
                in: initialPlan,
                now: setup.dateProvider.now
            )
        )

        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
        XCTAssertEqual(updatedPlan.revision, initialPlan.revision)
        XCTAssertEqual(
            updatedPlan.moments.first(where: { $0.id == completedMoment.id })?.status,
            .completed
        )
        XCTAssertEqual(
            Set(updatedPlan.moments.filter { $0.id != completedMoment.id }.map(\.id)),
            untouchedMomentIDs
        )
        XCTAssertEqual(setup.hydrationRepository.storedEntries.first?.source, .plan)
    }

    func testDeletingEntryAlsoSynchronizesWithoutRegenerating() async throws {
        let setup = makeSetup(adaptiveResult: .success(draft(total: 3_750)))

        try await setup.trackingService.addWater(
            amountInMilliliters: 250,
            date: now,
            source: .manual
        )
        let entryID = try XCTUnwrap(setup.hydrationRepository.storedEntries.first?.id)
        let initialPlan = try XCTUnwrap(try setup.planRepository.plan(for: now))
        setup.adaptiveGenerator.result = .success(draft(total: 4_000))

        try await setup.trackingService.deleteEntry(id: entryID)

        let updatedPlan = try XCTUnwrap(try setup.planRepository.plan(for: now))
        XCTAssertEqual(updatedPlan.revision, initialPlan.revision)
        XCTAssertEqual(updatedPlan.consumedMillilitersAtGeneration, 250)
        XCTAssertEqual(updatedPlan.moments.map(\.id), initialPlan.moments.map(\.id))
        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
    }

    private func makeSetup(
        adaptiveResult: Result<GeneratedDailyPlanDraft, Error>
    ) -> (
        service: AdaptivePlanService,
        hydrationRepository: FakeHydrationRepository,
        planRepository: InMemoryDailyPlanRepository,
        goalService: HydrationGoalService,
        trackingService: HydrationTrackingService,
        adaptiveGenerator: MockAdaptivePlanGenerator,
        dateProvider: MutableDateProvider,
        synchronizer: DynamicPlanSynchronizer
    ) {
        let hydrationRepository = FakeHydrationRepository()
        let planRepository = InMemoryDailyPlanRepository(calendar: calendar)
        let trackingService = HydrationTrackingService(
            repository: hydrationRepository,
            calendar: calendar
        )
        let goalService = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore(
                dailyGoalInMilliliters: 4_000
            )
        )
        let adaptiveGenerator = MockAdaptivePlanGenerator(result: adaptiveResult)
        let service = AdaptivePlanService(
            trackingService: trackingService,
            goalService: goalService,
            preferencesStore: InMemoryPlanningPreferencesStore(),
            repository: planRepository,
            adaptiveGenerator: adaptiveGenerator,
            fallbackGenerator: DeterministicAdaptivePlanGenerator(),
            calendar: calendar
        )
        let dateProvider = MutableDateProvider(now: now)
        let synchronizer = DynamicPlanSynchronizer(
            planService: service,
            dateProvider: dateProvider
        )
        trackingService.setEntriesChangeObserver(synchronizer)
        return (
            service,
            hydrationRepository,
            planRepository,
            goalService,
            trackingService,
            adaptiveGenerator,
            dateProvider,
            synchronizer
        )
    }

    private func draft(total: Int, count: Int = 4) -> GeneratedDailyPlanDraft {
        let baseAmount = total / count
        let remainder = total % count
        return GeneratedDailyPlanDraft(
            moments: (0..<count).map { index in
                GeneratedPlanMoment(
                    minutesFromStart: index * 120,
                    amountMilliliters: baseAmount + (index < remainder ? 1 : 0),
                    rationale: "Part of the remaining user-selected goal."
                )
            },
            explanation: "The remaining goal was divided across the rest of today."
        )
    }

    private func validDistributionDraft(
        goal: Int,
        consumedAmount: Int
    ) async throws -> GeneratedDailyPlanDraft {
        let entry = HydrationEntry(
            amountInMilliliters: Double(consumedAmount),
            date: now,
            source: .appIntent
        )
        let context = DailyPlanContextBuilder(calendar: calendar).build(
            now: now,
            dailyGoalMilliliters: Double(goal),
            entries: [entry],
            preferences: .defaults,
            existingPlan: nil
        )
        return try await DeterministicAdaptivePlanGenerator().generatePlan(
            from: context,
            constraints: .make(from: context)
        )
    }

    private func currentRevisionTotal(in plan: DailyHydrationPlan) -> Int {
        plan.moments
            .filter { $0.generatedRevision == plan.revision }
            .reduce(0) { $0 + $1.plannedMilliliters }
    }

    private func loadedPlan(from result: DailyPlanLoadResult) async throws -> DailyHydrationPlan {
        guard case .plan(let plan) = result else {
            throw PlanGenerationError.invalidFallback
        }
        return plan
    }
}
