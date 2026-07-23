import XCTest
@testable import Aqua

@MainActor
final class DailyPlanReconcilerTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var day = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 22)) ?? .distantPast
    }

    func testMomentIsNotMissedInsideGracePeriod() {
        let result = reconcile(plan: plan(at: 8, amount: 500), nowHour: 8, minute: 20)
        XCTAssertNotEqual(result.plan.moments[0].status, .missed)
        XCTAssertFalse(result.needsRedistribution)
    }

    func testMomentBecomesMissedAfterGracePeriod() {
        let result = reconcile(plan: plan(at: 8, amount: 500), nowHour: 8, minute: 21)
        XCTAssertEqual(result.plan.moments[0].status, .missed)
        XCTAssertTrue(result.needsRedistribution)
    }

    func testPartialCompletionRedistributesOnlyUnfulfilledAmount() {
        let entry = HydrationEntry(
            amountInMilliliters: 300,
            date: date(hour: 12, minute: 10),
            source: .manual
        )
        let result = reconcile(
            plan: plan(at: 12, amount: 500),
            entries: [entry],
            nowHour: 12,
            minute: 31
        )
        XCTAssertEqual(result.plan.moments[0].completedMilliliters, 300)
        XCTAssertEqual(result.plan.moments[0].remainingMilliliters, 200)
        XCTAssertEqual(result.plan.moments[0].status, .partiallyCompleted)
        XCTAssertTrue(result.needsRedistribution)
    }

    func testCompletedMomentKeepsItsIdentityAndAmount() {
        let original = plan(at: 8, amount: 500)
        let entry = HydrationEntry(
            amountInMilliliters: 500,
            date: date(hour: 8, minute: 5),
            source: .quickAdd
        )
        let result = reconcile(plan: original, entries: [entry], nowHour: 9)
        XCTAssertEqual(result.plan.moments[0].id, original.moments[0].id)
        XCTAssertEqual(result.plan.moments[0].plannedMilliliters, 500)
        XCTAssertEqual(result.plan.moments[0].status, .completed)
    }

    func testConsumptionFlowsChronologicallyAndIsNeverCountedTwice() {
        var original = plan(at: 8, amount: 500)
        original.moments.append(moment(hour: 10, amount: 500))
        let entry = HydrationEntry(
            amountInMilliliters: 750,
            date: date(hour: 9),
            source: .appIntent
        )
        let result = reconcile(plan: original, entries: [entry], nowHour: 9)
        XCTAssertEqual(result.plan.moments.map(\.completedMilliliters), [500, 250])
        XCTAssertEqual(result.plan.moments.reduce(0) { $0 + $1.completedMilliliters }, 750)
    }

    func testPlanLinkedEntryIsAppliedToItsMomentFirst() {
        var original = plan(at: 8, amount: 500)
        let second = moment(hour: 10, amount: 500)
        original.moments.append(second)
        let entry = HydrationEntry(
            amountInMilliliters: 300,
            date: date(hour: 9),
            source: .plan,
            planMomentID: second.id,
            planRevision: 0
        )
        let result = reconcile(plan: original, entries: [entry], nowHour: 9)
        XCTAssertEqual(result.plan.moments.map(\.completedMilliliters), [0, 300])
    }

    func testDeletingAnEntryRemovesItsAllocation() {
        let original = plan(at: 10, amount: 500)
        let entry = HydrationEntry(
            amountInMilliliters: 500,
            date: date(hour: 10),
            source: .manual
        )
        let completed = reconcile(plan: original, entries: [entry], nowHour: 10)
        let afterDeletion = reconcile(plan: completed.plan, entries: [], nowHour: 10)
        XCTAssertEqual(completed.plan.moments[0].completedMilliliters, 500)
        XCTAssertEqual(afterDeletion.plan.moments[0].completedMilliliters, 0)
    }

    func testGoalCompletionCancelsFutureMoments() {
        let original = plan(at: 12, amount: 500, goal: 500)
        let entry = HydrationEntry(
            amountInMilliliters: 500,
            date: date(hour: 9),
            source: .shortcut
        )
        let result = reconcile(plan: original, entries: [entry], nowHour: 10)
        XCTAssertEqual(result.plan.moments[0].status, .cancelled)
        XCTAssertFalse(result.needsRedistribution)
    }

    func testStaleActiveMomentFromOlderRevisionIsRemoved() {
        var original = plan(at: 8, amount: 500)
        original.revision = 1
        original.moments[0].status = .current
        original.moments.append(
            HydrationPlanMoment(
                id: UUID(),
                scheduledDate: date(hour: 10),
                plannedMilliliters: 500,
                completedMilliliters: 0,
                status: .adjusted,
                originalPlannedMilliliters: nil,
                originalScheduledDate: nil,
                generatedReason: .remainingGoal,
                rationale: nil,
                generatedRevision: 1
            )
        )

        let result = reconcile(plan: original, nowHour: 9)

        XCTAssertEqual(result.plan.moments.count, 1)
        XCTAssertEqual(result.plan.moments.first?.generatedRevision, 1)
        XCTAssertTrue(result.didChange)
    }

    private func reconcile(
        plan: DailyHydrationPlan,
        entries: [HydrationEntry] = [],
        nowHour: Int,
        minute: Int = 0
    ) -> PlanReconciliationResult {
        DailyPlanReconciler(calendar: calendar).reconcile(
            plan: plan,
            entries: entries.map(HydrationEntrySnapshot.init(entry:)),
            now: date(hour: nowHour, minute: minute)
        )
    }

    private func plan(at hour: Int, amount: Int, goal: Int = 2_000) -> DailyHydrationPlan {
        let created = date(hour: 7)
        return DailyHydrationPlan(
            id: UUID(),
            calendarDay: day,
            createdAt: created,
            updatedAt: created,
            goalMilliliters: goal,
            consumedMillilitersAtGeneration: 0,
            moments: [moment(hour: hour, amount: amount)],
            revision: 0,
            generationSource: .deterministicFallback,
            adjustmentSummary: nil,
            wasNormalized: false
        )
    }

    private func moment(hour: Int, amount: Int) -> HydrationPlanMoment {
        HydrationPlanMoment(
            id: UUID(),
            scheduledDate: date(hour: hour),
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
