import XCTest
@testable import Aqua

@MainActor
final class AdaptivePlanServiceTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var now = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 10)
        ) ?? .distantPast
    }

    func testFoundationModelsUnavailableUsesDeterministicFallback() async throws {
        let setup = makeSetup(adaptiveResult: .failure(PlanGenerationError.unavailable))
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(plan.generationSource, .deterministicFallback)
        XCTAssertEqual(plan.moments.reduce(0) { $0 + $1.plannedMilliliters }, 4_000)
    }

    func testInvalidFoundationModelsOutputTriggersFallback() async throws {
        let invalid = draft(offsets: [0, 0, 9_999], amounts: [100, 100, 100])
        let setup = makeSetup(adaptiveResult: .success(invalid))
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(plan.generationSource, .deterministicFallback)
        XCTAssertEqual(plan.moments.reduce(0) { $0 + $1.plannedMilliliters }, 4_000)
    }

    func testValidFoundationModelsDraftIsPersistedOnlyAfterValidation() async throws {
        let valid = try await validDistributionDraft()
        let setup = makeSetup(adaptiveResult: .success(valid))
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(plan.generationSource, .foundationModels)
        XCTAssertEqual(try setup.planRepository.plan(for: now), plan)
    }

    func testGeneratorReceivesExactUserPreferences() async throws {
        let setup = makeSetup()
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 9 * 60
        preferences.activeDayEndMinutes = 21 * 60
        preferences.preferredMomentCount = 4
        preferences.minimumIntervalMinutes = 90
        preferences.preferredAmountMilliliters = 650
        try setup.service.updatePlanningPreferences(preferences)

        _ = try await setup.service.preparePlan(now: now)

        XCTAssertEqual(setup.adaptiveGenerator.receivedPreferences, [preferences])
    }

    func testExistingConsumptionReducesFuturePlanExactTotal() async throws {
        let entry = HydrationEntry(amountInMilliliters: 1_000, date: now, source: .manual)
        let setup = makeSetup(entries: [entry])
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(plan.consumedMillilitersAtGeneration, 1_000)
        XCTAssertEqual(plan.moments.reduce(0) { $0 + $1.plannedMilliliters }, 3_000)
    }

    func testConfigurationRegenerationReplacesActiveMoments() async throws {
        let setup = makeSetup()
        let first = try await loadedPlan(from: setup.service.preparePlan(now: now))
        let originalMomentIDs = Set(first.moments.map(\.id))
        let second = try await loadedPlan(
            from: setup.service.preparePlan(
                now: now.addingTimeInterval(60),
                forceRegeneration: true
            )
        )
        XCTAssertEqual(second.revision, first.revision + 1)
        XCTAssertTrue(second.moments.allSatisfy { $0.generatedRevision == second.revision })
        XCTAssertTrue(originalMomentIDs.isDisjoint(with: second.moments.map(\.id)))
    }

    func testCompletedPeriodKeepsTargetsWithoutNewRevision() async throws {
        let setup = makeSetup()
        let first = try await loadedPlan(from: setup.service.preparePlan(now: now))
        let later = now.addingTimeInterval(2 * 60 * 60)
        let revised = try await loadedPlan(from: setup.service.preparePlan(now: later))

        XCTAssertEqual(revised.revision, first.revision)
        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
        XCTAssertTrue(revised.moments.contains { $0.status == .missed })
        XCTAssertFalse(revised.periodTargets?.contains(where: \.wasAdjusted) == true)
    }

    func testGoalChangeCreatesNewExactTotalPlan() async throws {
        let setup = makeSetup()
        _ = try await setup.service.preparePlan(now: now)
        try setup.goalService.updateDailyGoal(to: 5_000)
        let revised = try await loadedPlan(from: setup.service.preparePlan(now: now))
        let futureTotal = revised.moments
            .filter { $0.generatedRevision == revised.revision }
            .reduce(0) { $0 + $1.plannedMilliliters }
        XCTAssertEqual(revised.goalMilliliters, 5_000)
        XCTAssertEqual(futureTotal, 5_000)
    }

    func testDailyGoalChangeImmediatelyRegeneratesViewModelPlan() async throws {
        let setup = makeSetup()
        let viewModel = PlanViewModel(
            service: setup.service,
            goalService: setup.goalService,
            trackingService: setup.trackingService,
            dateProvider: FixedDateProvider(now: now)
        )
        await viewModel.refresh()
        let initialRevision = try XCTUnwrap(viewModel.state.data?.plan?.revision)

        try setup.goalService.updateDailyGoal(to: 5_000)
        viewModel.dailyGoalDidChange()

        for _ in 0..<20 {
            if viewModel.state.data?.plan?.goalMilliliters == 5_000 { break }
            try await Task.sleep(for: .milliseconds(25))
        }

        let updatedPlan = try XCTUnwrap(viewModel.state.data?.plan)
        XCTAssertEqual(updatedPlan.goalMilliliters, 5_000)
        XCTAssertEqual(updatedPlan.revision, initialRevision + 1)
        XCTAssertEqual(
            updatedPlan.moments
                .filter { $0.generatedRevision == updatedPlan.revision }
                .reduce(0) { $0 + $1.plannedMilliliters },
            5_000
        )
    }

    func testTodayAndAppIntentEntriesAffectExistingPlan() async throws {
        let setup = makeSetup()
        _ = try await setup.service.preparePlan(now: now)
        try await setup.trackingService.addWater(
            amountInMilliliters: 250,
            date: now.addingTimeInterval(60),
            source: .appIntent
        )
        let updated = try await loadedPlan(
            from: setup.service.preparePlan(now: now.addingTimeInterval(120))
        )
        XCTAssertEqual(updated.moments.reduce(0) { $0 + $1.completedMilliliters }, 250)
    }

    func testPlanActionCreatesRealEntryWithMomentMetadata() async throws {
        let setup = makeSetup()
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        let moment = try XCTUnwrap(plan.moments.first)
        _ = try await setup.service.addPlannedAmount(
            for: moment,
            in: plan,
            now: now.addingTimeInterval(60)
        )
        let entry = try XCTUnwrap(setup.hydrationRepository.storedEntries.first)
        XCTAssertEqual(entry.source, .plan)
        XCTAssertEqual(entry.planMomentID, moment.id)
        XCTAssertEqual(entry.planRevision, plan.revision)
    }

    func testGoalCompletionRemovesActiveFutureRecommendations() async throws {
        let entry = HydrationEntry(amountInMilliliters: 4_000, date: now, source: .manual)
        let setup = makeSetup(entries: [entry])
        let result = try await setup.service.preparePlan(now: now)
        guard case .completed = result else { return XCTFail("Expected completed state") }
    }

    func testDayChangeCreatesIndependentDailyPlan() async throws {
        let setup = makeSetup()
        let first = try await loadedPlan(from: setup.service.preparePlan(now: now))
        let nextDay = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let second = try await loadedPlan(from: setup.service.preparePlan(now: nextDay))
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(setup.planRepository.plansByDay.count, 2)
    }

    func testPreviousDayEntryDoesNotEnterCurrentPlan() async throws {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let setup = makeSetup(entries: [
            HydrationEntry(amountInMilliliters: 1_000, date: yesterday, source: .manual)
        ])
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(plan.consumedMillilitersAtGeneration, 0)
        XCTAssertEqual(plan.moments.reduce(0) { $0 + $1.plannedMilliliters }, 4_000)
    }

    func testInconsistentGeneratedExplanationIsReplaced() async throws {
        var generated = try await validDistributionDraft()
        generated.explanation = "Your remaining goal was spread across six moments."
        let setup = makeSetup(adaptiveResult: .success(generated))
        let plan = try await loadedPlan(from: setup.service.preparePlan(now: now))
        XCTAssertEqual(
            plan.adjustmentSummary,
            "Your remaining goal was divided across the rest of your active day."
        )
    }

    func testExistingPlanIsHiddenWhileRegenerationRuns() async throws {
        let valid = draft(offsets: [0, 120, 240, 360], amounts: [1_000, 1_000, 1_000, 1_000])
        let setup = makeSetup(adaptiveResult: .success(valid))
        let dateProvider = MutableDateProvider(now: now)
        let viewModel = PlanViewModel(
            service: setup.service,
            goalService: setup.goalService,
            trackingService: setup.trackingService,
            dateProvider: dateProvider
        )
        await viewModel.refresh()
        XCTAssertNotNil(viewModel.state.data?.plan)
        setup.adaptiveGenerator.delay = .milliseconds(200)

        viewModel.requestRefresh(forceRegeneration: true, displaysLoading: true)
        try await Task.sleep(for: .milliseconds(30))

        guard case .loading = viewModel.state else {
            return XCTFail("Expected the timeline to be replaced by loading")
        }
        XCTAssertNil(viewModel.state.data)
        XCTAssertTrue(viewModel.isPreparing)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNotNil(viewModel.state.data?.plan)
    }

    func testEnteringPlanKeepsTheExistingRevision() async throws {
        let setup = makeSetup()
        let viewModel = PlanViewModel(
            service: setup.service,
            goalService: setup.goalService,
            trackingService: setup.trackingService,
            dateProvider: FixedDateProvider(now: now)
        )
        await viewModel.refresh()
        let initialRevision = try XCTUnwrap(viewModel.state.data?.plan?.revision)

        viewModel.viewDidAppear()
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(viewModel.state.data?.plan?.revision, initialRevision)
        XCTAssertEqual(setup.adaptiveGenerator.callCount, 1)
    }

    func testEnteringPlanRegeneratesItWhenDailyGoalChangedWhileAway() async throws {
        let setup = makeSetup()
        let viewModel = PlanViewModel(
            service: setup.service,
            goalService: setup.goalService,
            trackingService: setup.trackingService,
            dateProvider: FixedDateProvider(now: now)
        )
        await viewModel.refresh()
        let initialRevision = try XCTUnwrap(viewModel.state.data?.plan?.revision)
        viewModel.viewDidDisappear()

        try setup.goalService.updateDailyGoal(to: 5_000)
        viewModel.viewDidAppear()

        for _ in 0..<20 {
            if viewModel.state.data?.plan?.goalMilliliters == 5_000 { break }
            try await Task.sleep(for: .milliseconds(25))
        }

        let updatedData = try XCTUnwrap(viewModel.state.data)
        let updatedPlan = try XCTUnwrap(updatedData.plan)
        XCTAssertEqual(updatedData.progress.dailyGoal, 5_000)
        XCTAssertEqual(updatedPlan.goalMilliliters, 5_000)
        XCTAssertEqual(updatedPlan.revision, initialRevision + 1)
        XCTAssertEqual(
            updatedPlan.moments
                .filter { $0.generatedRevision == updatedPlan.revision }
                .reduce(0) { $0 + $1.plannedMilliliters },
            5_000
        )
    }

    func testTimelineUsesRealEntriesAndOnlyCurrentRevisionMoments() async throws {
        let setup = makeSetup()
        let viewModel = PlanViewModel(
            service: setup.service,
            goalService: setup.goalService,
            trackingService: setup.trackingService,
            dateProvider: FixedDateProvider(now: now)
        )
        await viewModel.refresh()
        try await setup.trackingService.addWater(
            amountInMilliliters: 500,
            date: now,
            source: .quickAdd
        )

        await viewModel.refresh(forceRegeneration: true, displaysLoading: true)

        let data = try XCTUnwrap(viewModel.state.data)
        let plan = try XCTUnwrap(data.plan)
        XCTAssertEqual(data.entries, setup.hydrationRepository.storedEntries)
        XCTAssertEqual(data.entries.count, 1)
        XCTAssertTrue(data.visibleMoments.allSatisfy {
            $0.generatedRevision == plan.revision
                && ![.completed, .missed, .cancelled].contains($0.status)
        })
        XCTAssertGreaterThan(plan.moments.count, data.visibleMoments.count)
    }

    func testOlderConcurrentGenerationCannotOverwriteNewerConsumption() async throws {
        let hydrationRepository = FakeHydrationRepository()
        let trackingService = HydrationTrackingService(
            repository: hydrationRepository,
            calendar: calendar
        )
        let goalService = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore(
                dailyGoalInMilliliters: 4_000
            )
        )
        let planRepository = InMemoryDailyPlanRepository(calendar: calendar)
        let generator = DelayedContextualPlanGenerator()
        let service = AdaptivePlanService(
            trackingService: trackingService,
            goalService: goalService,
            preferencesStore: InMemoryPlanningPreferencesStore(),
            repository: planRepository,
            adaptiveGenerator: generator,
            fallbackGenerator: DeterministicAdaptivePlanGenerator(),
            calendar: calendar
        )

        let olderRequest = Task {
            try await service.preparePlan(now: now, forceRegeneration: true)
        }
        try await Task.sleep(for: .milliseconds(30))
        try await trackingService.addWater(
            amountInMilliliters: 500,
            date: now.addingTimeInterval(60),
            source: .appIntent
        )
        _ = try await service.preparePlan(
            now: now.addingTimeInterval(60),
            forceRegeneration: true
        )

        do {
            _ = try await olderRequest.value
            XCTFail("Expected the stale generation to be discarded")
        } catch is CancellationError {
            // Expected: only the plan containing the newest entry may be persisted.
        }

        let storedPlan = try XCTUnwrap(try planRepository.plan(for: now))
        XCTAssertEqual(storedPlan.consumedMillilitersAtGeneration, 500)
        XCTAssertEqual(
            storedPlan.moments
                .filter { $0.generatedRevision == storedPlan.revision }
                .reduce(0) { $0 + $1.plannedMilliliters },
            3_500
        )
    }

    private func makeSetup(
        entries: [HydrationEntry] = [],
        adaptiveResult: Result<GeneratedDailyPlanDraft, Error> = .failure(PlanGenerationError.unavailable)
    ) -> (
        service: AdaptivePlanService,
        hydrationRepository: FakeHydrationRepository,
        planRepository: InMemoryDailyPlanRepository,
        goalService: HydrationGoalService,
        trackingService: HydrationTrackingService,
        adaptiveGenerator: MockAdaptivePlanGenerator
    ) {
        let hydrationRepository = FakeHydrationRepository(entries: entries)
        let trackingService = HydrationTrackingService(
            repository: hydrationRepository,
            calendar: calendar
        )
        let goalService = HydrationGoalService(
            preferencesStore: InMemoryHydrationPreferencesStore(dailyGoalInMilliliters: 4_000)
        )
        let planRepository = InMemoryDailyPlanRepository(calendar: calendar)
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
        return (
            service,
            hydrationRepository,
            planRepository,
            goalService,
            trackingService,
            adaptiveGenerator
        )
    }

    private func loadedPlan(from result: DailyPlanLoadResult) async throws -> DailyHydrationPlan {
        guard case .plan(let plan) = result else {
            throw PlanGenerationError.invalidFallback
        }
        return plan
    }

    private func draft(offsets: [Int], amounts: [Int]) -> GeneratedDailyPlanDraft {
        GeneratedDailyPlanDraft(
            moments: zip(offsets, amounts).map {
                GeneratedPlanMoment(
                    minutesFromStart: $0.0,
                    amountMilliliters: $0.1,
                    rationale: "Part of the remaining goal."
                )
            },
            explanation: "The remaining goal was divided across the rest of today."
        )
    }

    private func validDistributionDraft() async throws -> GeneratedDailyPlanDraft {
        let context = DailyPlanContextBuilder(calendar: calendar).build(
            now: now,
            dailyGoalMilliliters: 4_000,
            entries: [],
            preferences: .defaults,
            existingPlan: nil
        )
        return try await DeterministicAdaptivePlanGenerator().generatePlan(
            from: context,
            preferences: .defaults,
            constraints: .make(from: context)
        )
    }
}

@MainActor
private final class DelayedContextualPlanGenerator: AdaptivePlanGenerating, @unchecked Sendable {
    private var callCount = 0

    func generatePlan(
        from context: DailyPlanContext,
        preferences: PlanningPreferences,
        constraints: DailyPlanConstraints
    ) async throws -> GeneratedDailyPlanDraft {
        callCount += 1
        if callCount == 1 {
            try await Task.sleep(for: .milliseconds(200))
        }
        return GeneratedDailyPlanDraft(
            moments: [
                GeneratedPlanMoment(
                    minutesFromStart: 0,
                    amountMilliliters: context.remainingMilliliters,
                    rationale: "Part of the remaining user-selected goal."
                )
            ],
            explanation: "The remaining goal was divided across the rest of today."
        )
    }
}
