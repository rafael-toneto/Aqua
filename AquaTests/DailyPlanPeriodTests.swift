import XCTest
@testable import Aqua

@MainActor
final class DailyPlanPeriodTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var day = Date()
    private var planner = DailyPlanPeriodPlanner(calendar: fixedCalendar())

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        day = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22)
        ) ?? .distantPast
        planner = DailyPlanPeriodPlanner(calendar: calendar)
    }

    func testPeriodBoundariesMatchTheThreeFixedWindows() {
        XCTAssertEqual(planner.period(containing: date(hour: 0)), .morning)
        XCTAssertEqual(planner.period(containing: date(hour: 11, minute: 59)), .morning)
        XCTAssertEqual(planner.period(containing: date(hour: 12)), .afternoon)
        XCTAssertEqual(planner.period(containing: date(hour: 17, minute: 59)), .afternoon)
        XCTAssertEqual(planner.period(containing: date(hour: 18)), .evening)
        XCTAssertEqual(planner.period(containing: date(hour: 23, minute: 59)), .evening)
    }

    func testInitialTargetsPreferAfternoonWhenNoScheduleIsAvailable() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 8 * 60
        preferences.activeDayEndMinutes = 23 * 60

        let generated = planner.initialTargets(
            goalMilliliters: 5_400,
            entries: [],
            moments: [],
            preferences: preferences
        )
        let amounts = Dictionary(uniqueKeysWithValues: generated.map {
            ($0.period, $0.plannedMilliliters)
        })

        XCTAssertEqual(amounts.values.reduce(0, +), 5_400)
        XCTAssertGreaterThan(amounts[.afternoon, default: 0], amounts[.morning, default: 0])
        XCTAssertGreaterThan(amounts[.afternoon, default: 0], amounts[.evening, default: 0])
    }

    func testInitialTargetsNeverAllocateRemainderOutsideActivePeriods() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 12 * 60
        preferences.activeDayEndMinutes = 18 * 60

        let generated = planner.initialTargets(
            goalMilliliters: 1_001,
            entries: [],
            moments: [],
            preferences: preferences
        )

        XCTAssertEqual(plannedAmounts(generated), [0, 1_001, 0])
    }

    func testViewDataGroupsOnlyTheLogsInsideEachPeriod() {
        let entries = [
            entry(amount: 200, hour: 11, minute: 59),
            entry(amount: 300, hour: 12),
            entry(amount: 400, hour: 17, minute: 59),
            entry(amount: 500, hour: 18)
        ]
        let progress = DailyHydrationProgress.calculate(entries: entries, dailyGoal: 4_000)
        let plan = DailyHydrationPlan(
            id: UUID(),
            calendarDay: day,
            createdAt: date(hour: 8),
            updatedAt: date(hour: 8),
            goalMilliliters: 4_000,
            consumedMillilitersAtGeneration: 0,
            moments: [],
            revision: 0,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false,
            periodTargets: targets
        )

        let data = PlanViewData(
            plan: plan,
            entries: entries,
            progress: progress,
            isOutsideActiveHours: false,
            now: date(hour: 19),
            preferences: .defaults,
            calendar: calendar
        )

        XCTAssertEqual(data.periods.map { $0.entries.count }, [1, 2, 1])
        XCTAssertEqual(data.periods.map(\.consumedMilliliters), [200, 700, 500])
        XCTAssertTrue(data.periods.allSatisfy { !$0.checkpoints.isEmpty })
    }

    func testCheckpointsUseAgentTimesAndShowCumulativeTargets() {
        let moments = [
            moment(amount: 300, hour: 13),
            moment(amount: 200, hour: 13, minute: 30)
        ]

        let checkpoints = PlanCheckpointPlanner(calendar: calendar).checkpoints(
            for: .afternoon,
            plannedMilliliters: 500,
            moments: moments,
            preferences: .defaults,
            calendarDay: day
        )

        XCTAssertEqual(checkpoints.map(\.scheduledDate), moments.map(\.scheduledDate))
        XCTAssertEqual(checkpoints.map(\.cumulativeMilliliters), [300, 500])
    }

    func testCheckpointsScaleToAnAdjustedPeriodTarget() {
        let checkpoints = PlanCheckpointPlanner(calendar: calendar).checkpoints(
            for: .afternoon,
            plannedMilliliters: 1_000,
            moments: [
                moment(amount: 300, hour: 13),
                moment(amount: 200, hour: 13, minute: 30)
            ],
            preferences: .defaults,
            calendarDay: day
        )

        XCTAssertEqual(checkpoints.map(\.cumulativeMilliliters), [600, 1_000])
        XCTAssertEqual(checkpoints.last?.cumulativeMilliliters, 1_000)
    }

    func testViewDataCarriesCheckpointTargetsAcrossPeriodBoundaries() {
        let moments = [
            moment(amount: 1_000, hour: 10),
            moment(amount: 2_100, hour: 17, minute: 44),
            moment(amount: 280, hour: 18, minute: 34),
            moment(amount: 280, hour: 19, minute: 41),
            moment(amount: 280, hour: 20, minute: 48),
            moment(amount: 280, hour: 21, minute: 55),
            moment(amount: 280, hour: 23, minute: 2)
        ]
        let periodTargets = [
            target(.morning, amount: 1_000),
            target(.afternoon, amount: 2_100),
            target(.evening, amount: 1_400)
        ]
        let plan = DailyHydrationPlan(
            id: UUID(),
            calendarDay: day,
            createdAt: date(hour: 8),
            updatedAt: date(hour: 8),
            goalMilliliters: 4_500,
            consumedMillilitersAtGeneration: 0,
            moments: moments,
            revision: 0,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false,
            periodTargets: periodTargets
        )
        let progress = DailyHydrationProgress.calculate(entries: [], dailyGoal: 4_500)

        let data = PlanViewData(
            plan: plan,
            entries: [],
            progress: progress,
            isOutsideActiveHours: false,
            now: date(hour: 18),
            preferences: .defaults,
            calendar: calendar
        )

        XCTAssertEqual(
            data.periods.map(\.cumulativePlannedMillilitersBeforePeriod),
            [0, 1_000, 3_100]
        )
        XCTAssertEqual(
            data.periods.flatMap(\.checkpoints).map(\.cumulativeMilliliters),
            [1_000, 3_100, 3_380, 3_660, 3_940, 4_220, 4_500]
        )
    }

    func testCheckpointCompletionUsesConsumptionAccumulatedAcrossTheDay() {
        let checkpoint = PlanCheckpointViewData(
            scheduledDate: date(hour: 18, minute: 34),
            cumulativeMilliliters: 3_380
        )
        let period = PlanPeriodViewData(
            period: .evening,
            entries: [entry(amount: 280, hour: 18, minute: 30)],
            plannedMilliliters: 1_400,
            cumulativePlannedMillilitersBeforePeriod: 3_100,
            consumedMillilitersBeforePeriod: 3_100,
            checkpoints: [checkpoint],
            now: date(hour: 18, minute: 34),
            calendar: calendar
        )

        XCTAssertEqual(period.cumulativeConsumedMilliliters, 3_380)
        XCTAssertEqual(period.checkpointStates, [.completed])
    }

    func testCompletingDailyGoalMarksLaterPeriodsAsCompleted() {
        let entries = [
            entry(amount: 300, hour: 10),
            entry(amount: 5_750, hour: 15, minute: 45)
        ]
        let plan = DailyHydrationPlan(
            id: UUID(),
            calendarDay: day,
            createdAt: date(hour: 8),
            updatedAt: date(hour: 15, minute: 45),
            goalMilliliters: 5_700,
            consumedMillilitersAtGeneration: 0,
            moments: [],
            revision: 0,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false,
            periodTargets: [
                target(.morning, amount: 1_140),
                target(.afternoon, amount: 3_140),
                target(.evening, amount: 1_420)
            ]
        )
        let progress = DailyHydrationProgress.calculate(entries: entries, dailyGoal: 5_700)

        let data = PlanViewData(
            plan: plan,
            entries: entries,
            progress: progress,
            isOutsideActiveHours: false,
            now: date(hour: 15, minute: 47),
            preferences: .defaults,
            calendar: calendar
        )

        XCTAssertEqual(data.periods.map(\.state), [.missed, .completed, .completed])
        XCTAssertEqual(data.completedPeriodCount, 2)
        XCTAssertTrue(
            data.periods[2].checkpointStates.allSatisfy { $0 == .completed }
        )
    }

    func testConsumedVolumeCompletesCumulativeCheckpoints() {
        let entries = [entry(amount: 500, hour: 13, minute: 20)]
        let checkpoints = [
            PlanCheckpointViewData(
                scheduledDate: date(hour: 13),
                cumulativeMilliliters: 300
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 13, minute: 30),
                cumulativeMilliliters: 500
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 14),
                cumulativeMilliliters: 800
            )
        ]
        let period = PlanPeriodViewData(
            period: .afternoon,
            entries: entries,
            plannedMilliliters: 800,
            checkpoints: checkpoints,
            now: date(hour: 13, minute: 20),
            calendar: calendar
        )

        XCTAssertEqual(period.completedCheckpointCount, 2)
        XCTAssertEqual(period.checkpointStates, [.completed, .completed, .next])
    }

    func testPastUnreachedCheckpointsAreMissed() {
        let checkpoints = [
            PlanCheckpointViewData(
                scheduledDate: date(hour: 8),
                cumulativeMilliliters: 300
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 9),
                cumulativeMilliliters: 600
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 10),
                cumulativeMilliliters: 900
            )
        ]
        let period = PlanPeriodViewData(
            period: .morning,
            entries: [],
            plannedMilliliters: 900,
            checkpoints: checkpoints,
            now: date(hour: 13, minute: 36),
            calendar: calendar
        )

        XCTAssertEqual(period.completedCheckpointCount, 0)
        XCTAssertEqual(period.checkpointStates, [.missed, .missed, .missed])
    }

    func testNextCheckpointSkipsMissedCheckpoints() {
        let checkpoints = [
            PlanCheckpointViewData(
                scheduledDate: date(hour: 13),
                cumulativeMilliliters: 300
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 14),
                cumulativeMilliliters: 600
            ),
            PlanCheckpointViewData(
                scheduledDate: date(hour: 15),
                cumulativeMilliliters: 900
            )
        ]
        let period = PlanPeriodViewData(
            period: .afternoon,
            entries: [],
            plannedMilliliters: 900,
            checkpoints: checkpoints,
            now: date(hour: 13, minute: 36),
            calendar: calendar
        )

        XCTAssertEqual(period.completedCheckpointCount, 0)
        XCTAssertEqual(period.checkpointStates, [.missed, .next, .upcoming])
    }

    func testFallbackCheckpointsRespectConfiguredActivePeriodAndInterval() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 12 * 60
        preferences.activeDayEndMinutes = 18 * 60
        preferences.minimumIntervalMinutes = 90
        preferences.preferredMomentCount = 8
        preferences.preferredAmountMilliliters = 250

        let checkpoints = PlanCheckpointPlanner(calendar: calendar).checkpoints(
            for: .afternoon,
            plannedMilliliters: 1_000,
            moments: [],
            preferences: preferences,
            calendarDay: day
        )

        XCTAssertEqual(checkpoints.count, 4)
        XCTAssertEqual(checkpoints.last?.cumulativeMilliliters, 1_000)
        for pair in zip(checkpoints, checkpoints.dropFirst()) {
            XCTAssertGreaterThanOrEqual(
                pair.1.scheduledDate.timeIntervalSince(pair.0.scheduledDate),
                90 * 60
            )
        }
    }

    private var targets: [HydrationPlanPeriodTarget] {
        [
            target(.morning, amount: 1_000),
            target(.afternoon, amount: 1_500),
            target(.evening, amount: 1_500)
        ]
    }

    private func target(
        _ period: HydrationDayPeriod,
        amount: Int
    ) -> HydrationPlanPeriodTarget {
        HydrationPlanPeriodTarget(
            period: period,
            originalMilliliters: amount,
            plannedMilliliters: amount
        )
    }

    private func plannedAmounts(_ targets: [HydrationPlanPeriodTarget]) -> [Int] {
        targets.map(\.plannedMilliliters)
    }

    private func entry(
        amount: Int,
        hour: Int,
        minute: Int = 0
    ) -> HydrationEntry {
        HydrationEntry(
            amountInMilliliters: Double(amount),
            date: date(hour: hour, minute: minute),
            source: .manual
        )
    }

    private func snapshot(
        amount: Int,
        hour: Int,
        minute: Int = 0
    ) -> HydrationEntrySnapshot {
        HydrationEntrySnapshot(entry: entry(amount: amount, hour: hour, minute: minute))
    }

    private func moment(
        amount: Int,
        hour: Int,
        minute: Int = 0
    ) -> HydrationPlanMoment {
        HydrationPlanMoment(
            id: UUID(),
            scheduledDate: date(hour: hour, minute: minute),
            plannedMilliliters: amount,
            completedMilliliters: 0,
            status: .upcoming,
            originalPlannedMilliliters: nil,
            originalScheduledDate: nil,
            generatedReason: .initialDistribution,
            rationale: nil,
            generatedRevision: 0
        )
    }

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(
            byAdding: DateComponents(hour: hour, minute: minute),
            to: day
        ) ?? day
    }
}
