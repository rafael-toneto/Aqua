import XCTest
@testable import Aqua

@MainActor
final class DailyPlanAlgorithmTests: XCTestCase {
    private var calendar = fixedCalendar()
    private var now = Date()

    override func setUp() {
        super.setUp()
        calendar = fixedCalendar()
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 10)
        ) ?? .distantPast
    }

    func testRemainingAmountIsCalculatedFromRealEntries() {
        let context = makeContext(goal: 4_000, consumed: [600, 400])
        XCTAssertEqual(context.consumedMilliliters, 1_000)
        XCTAssertEqual(context.remainingMilliliters, 3_000)
    }

    func testPlanningStartUsesWholeDayCadenceInsteadOfFiveMinuteOffset() {
        let context = makeContext(goal: 4_000)
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: context.planningStart
        )

        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 6)
        XCTAssertGreaterThan(context.planningStart.timeIntervalSince(now), 60 * 60)
    }

    func testPlanningStartRespectsConfiguredDayAndMomentCount() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 8 * 60
        preferences.activeDayEndMinutes = 20 * 60
        preferences.preferredMomentCount = 4
        preferences.preferredAmountMilliliters = 10_000
        preferences.minimumIntervalMinutes = 120

        let context = makeContext(goal: 4_000, preferences: preferences)
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: context.planningStart
        )

        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 0)
    }

    func testFoundationPromptIncludesExactUserPreferences() {
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 9 * 60
        preferences.activeDayEndMinutes = 21 * 60
        preferences.preferredMomentCount = 4
        preferences.preferredAmountMilliliters = 650
        preferences.minimumIntervalMinutes = 90
        let context = makeContext(goal: 4_000, preferences: preferences)

        let prompt = FoundationModelsAdaptivePlanGenerator().prompt(
            context: context,
            preferences: preferences,
            constraints: .make(from: context)
        )

        XCTAssertTrue(prompt.contains("Active day starts at minute 540 after midnight"))
        XCTAssertTrue(prompt.contains("Active day ends at minute 1260 after midnight"))
        XCTAssertTrue(prompt.contains("Preferred total moment count: 4"))
        XCTAssertTrue(prompt.contains("Preferred amount per moment: 650 ml"))
        XCTAssertTrue(prompt.contains("Minimum interval between moments: 90 minutes"))
    }

    func testLoggedWaterCountsAsCompletedWholeDayMoment() {
        let context = makeContext(goal: 4_000, consumed: [250])

        XCTAssertEqual(context.preferredMomentCount, 6)
        XCTAssertEqual(context.todayEntries.count, 1)
        XCTAssertEqual(context.preferredRemainingMomentCount, 9)
    }

    func testRecentLogPushesNextMomentToConfiguredCadence() {
        let entry = HydrationEntry(
            amountInMilliliters: 250,
            date: now,
            source: .quickAdd
        )
        let context = DailyPlanContextBuilder(calendar: calendar).build(
            now: now,
            dailyGoalMilliliters: 4_000,
            entries: [entry],
            preferences: .defaults,
            existingPlan: nil
        )
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: context.planningStart
        )

        XCTAssertGreaterThanOrEqual(
            context.planningStart.timeIntervalSince(entry.date),
            60 * 60
        )
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 6)
    }

    func testZeroRemainingProducesNoFallbackMoments() async throws {
        let context = makeContext(goal: 2_000, consumed: [2_000])
        let draft = try await DeterministicAdaptivePlanGenerator().generatePlan(
            from: context,
            preferences: .defaults,
            constraints: .make(from: context)
        )
        XCTAssertTrue(draft.moments.isEmpty)
    }

    func testFallbackMomentsSumExactlyToRemainingAmount() async throws {
        let context = makeContext(goal: 4_000, consumed: [1_000])
        let draft = try await fallback(context)
        XCTAssertEqual(draft.moments.reduce(0) { $0 + $1.amountMilliliters }, 3_000)
    }

    func testIntegerRemainderNeverLosesMilliliters() async throws {
        var preferences = PlanningPreferences.defaults
        preferences.preferredMomentCount = 3
        preferences.preferredAmountMilliliters = 10_000
        let context = makeContext(goal: 1_001, preferences: preferences)
        let draft = try await fallback(context, preferences: preferences)
        XCTAssertEqual(draft.moments.map(\.amountMilliliters), [334, 334, 333])
    }

    func testFallbackMomentsAreChronologicallyOrdered() async throws {
        let draft = try await fallback(makeContext(goal: 4_000))
        XCTAssertEqual(
            draft.moments.map(\.minutesFromStart),
            draft.moments.map(\.minutesFromStart).sorted()
        )
    }

    func testSingleFallbackMomentUsesCalculatedDailyCadence() async throws {
        var preferences = PlanningPreferences.defaults
        preferences.preferredMomentCount = 1
        preferences.preferredAmountMilliliters = 10_000
        let context = makeContext(goal: 1_000, preferences: preferences)

        let draft = try await fallback(context, preferences: preferences)

        XCTAssertEqual(draft.moments.count, 1)
        XCTAssertEqual(draft.moments.first?.minutesFromStart, 0)
    }

    func testFallbackMomentsStayInsideActiveWindow() async throws {
        let context = makeContext(goal: 4_000)
        let draft = try await fallback(context)
        let result = DailyPlanValidator(calendar: calendar).validate(
            draft: draft,
            context: context,
            constraints: .make(from: context)
        )
        XCTAssertEqual(result, .valid)
    }

    func testFallbackRespectsMinimumInterval() async throws {
        var preferences = PlanningPreferences.defaults
        preferences.minimumIntervalMinutes = 90
        let draft = try await fallback(
            makeContext(goal: 4_000, preferences: preferences),
            preferences: preferences
        )
        let offsets = draft.moments.map(\.minutesFromStart)
        for pair in zip(offsets, offsets.dropFirst()) {
            XCTAssertGreaterThanOrEqual(pair.1 - pair.0, 90)
        }
    }

    func testReportedConfigurationPrioritizesAfternoonOverEvening() async throws {
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 14, minute: 32)
        ) ?? .distantPast
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 8 * 60
        preferences.activeDayEndMinutes = 23 * 60
        preferences.preferredMomentCount = 5
        preferences.minimumIntervalMinutes = 15
        preferences.preferredAmountMilliliters = 300
        let context = makeContext(goal: 5_400, preferences: preferences)
        let generated = try await fallback(context, preferences: preferences)
        let grouped = momentsByPeriod(generated, context: context)

        XCTAssertEqual(generated.moments.count, 18)
        XCTAssertTrue(generated.moments.allSatisfy { $0.amountMilliliters == 300 })
        XCTAssertEqual(grouped[.morning, default: []].count, 0)
        XCTAssertGreaterThan(
            grouped[.afternoon, default: []].count,
            grouped[.evening, default: []].count
        )
        XCTAssertGreaterThan(
            grouped[.afternoon, default: []].reduce(0) { $0 + $1.amountMilliliters },
            grouped[.evening, default: []].reduce(0) { $0 + $1.amountMilliliters }
        )
    }

    func testWholeDayPlanUsesMorningAndStillPrioritizesAfternoon() async throws {
        now = calendar.date(
            from: DateComponents(year: 2026, month: 7, day: 22, hour: 7, minute: 59)
        ) ?? .distantPast
        var preferences = PlanningPreferences.defaults
        preferences.activeDayStartMinutes = 8 * 60
        preferences.activeDayEndMinutes = 23 * 60
        preferences.preferredMomentCount = 5
        preferences.minimumIntervalMinutes = 15
        preferences.preferredAmountMilliliters = 300

        let context = makeContext(goal: 5_400, preferences: preferences)
        let generated = try await fallback(context, preferences: preferences)
        let grouped = momentsByPeriod(generated, context: context)

        XCTAssertFalse(grouped[.morning, default: []].isEmpty)
        XCTAssertGreaterThan(
            grouped[.afternoon, default: []].count,
            grouped[.morning, default: []].count
        )
        XCTAssertGreaterThan(
            grouped[.afternoon, default: []].count,
            grouped[.evening, default: []].count
        )
    }

    func testValidatorRejectsZeroAndNegativeAmounts() {
        let context = makeContext(goal: 1_000)
        for amount in [0, -100] {
            let failures = failures(
                for: GeneratedDailyPlanDraft(
                    moments: [GeneratedPlanMoment(
                        minutesFromStart: 0,
                        amountMilliliters: amount,
                        rationale: ""
                    )],
                    explanation: ""
                ),
                context: context
            )
            XCTAssertTrue(failures.contains(.nonPositiveAmount))
        }
    }

    func testValidatorRejectsWrongTotal() {
        let context = makeContext(goal: 1_000)
        let failures = failures(
            for: draft(offsets: [0, 60], amounts: [400, 400]),
            context: context
        )
        XCTAssertTrue(failures.contains(.wrongTotal))
    }

    func testValidatorRejectsDuplicateTimes() {
        let context = makeContext(goal: 1_000)
        let failures = failures(
            for: draft(offsets: [0, 0], amounts: [500, 500]),
            context: context
        )
        XCTAssertTrue(failures.contains(.duplicateTimes))
    }

    func testValidatorRejectsUnorderedTimes() {
        let context = makeContext(goal: 1_000)
        let failures = failures(
            for: draft(offsets: [60, 0], amounts: [500, 500]),
            context: context
        )
        XCTAssertTrue(failures.contains(.unorderedMoments))
    }

    func testValidatorRejectsMomentOutsideWindow() {
        let context = makeContext(goal: 1_000)
        let failures = failures(
            for: draft(offsets: [context.remainingActiveMinutes], amounts: [1_000]),
            context: context
        )
        XCTAssertTrue(failures.contains(.outsideActiveWindow))
    }

    func testValidatorRejectsAmountAboveApplicationGuardrail() {
        let context = makeContext(goal: 10_001)
        let failures = failures(
            for: draft(offsets: [0], amounts: [10_001]),
            context: context
        )
        XCTAssertTrue(failures.contains(.amountExceedsGuardrail))
    }

    func testValidatorRejectsUnevenAgentAmounts() async throws {
        let context = makeContext(goal: 4_000)
        var generated = try await fallback(context)
        generated.moments[0].amountMilliliters += 100
        generated.moments[generated.moments.count - 1].amountMilliliters -= 100

        XCTAssertTrue(
            failures(for: generated, context: context).contains(.unevenMomentAmounts)
        )
    }

    func testNormalizerRepairsOnlySmallRoundingDifference() {
        let context = makeContext(goal: 1_001)
        let input = draft(offsets: [0, 60, 120], amounts: [333, 333, 333])
        let normalized = DailyPlanNormalizer().normalize(
            input,
            context: context,
            constraints: .make(from: context)
        )
        XCTAssertFalse(normalized.isSubstantiallyInvalid)
        XCTAssertTrue(normalized.didNormalize)
        XCTAssertEqual(normalized.draft.moments.reduce(0) { $0 + $1.amountMilliliters }, 1_001)
    }

    func testNormalizerRejectsSubstantiallyWrongOutput() {
        let context = makeContext(goal: 4_000)
        let normalized = DailyPlanNormalizer().normalize(
            draft(offsets: [0], amounts: [1]),
            context: context,
            constraints: .make(from: context)
        )
        XCTAssertTrue(normalized.isSubstantiallyInvalid)
    }

    func testFallbackAlwaysValidAcrossRepresentativeScenarios() async throws {
        for remaining in [1, 250, 1_001, 4_000, 10_001, 25_000] {
            let context = makeContext(goal: remaining)
            let generated = try await fallback(context)
            XCTAssertEqual(
                DailyPlanValidator(calendar: calendar).validate(
                    draft: generated,
                    context: context,
                    constraints: .make(from: context)
                ),
                .valid,
                "Failed for \(remaining) ml"
            )
        }
    }

    private func fallback(
        _ context: DailyPlanContext,
        preferences: PlanningPreferences = .defaults
    ) async throws -> GeneratedDailyPlanDraft {
        try await DeterministicAdaptivePlanGenerator().generatePlan(
            from: context,
            preferences: preferences,
            constraints: .make(from: context)
        )
    }

    private func makeContext(
        goal: Int,
        consumed: [Int] = [],
        preferences: PlanningPreferences? = nil
    ) -> DailyPlanContext {
        let resolvedPreferences = preferences ?? .defaults
        let entries = consumed.enumerated().map { index, amount in
            HydrationEntry(
                amountInMilliliters: Double(amount),
                date: now.addingTimeInterval(TimeInterval(-3_600 + index)),
                source: .manual
            )
        }
        return DailyPlanContextBuilder(calendar: calendar).build(
            now: now,
            dailyGoalMilliliters: Double(goal),
            entries: entries,
            preferences: resolvedPreferences,
            existingPlan: nil
        )
    }

    private func draft(offsets: [Int], amounts: [Int]) -> GeneratedDailyPlanDraft {
        GeneratedDailyPlanDraft(
            moments: zip(offsets, amounts).map {
                GeneratedPlanMoment(minutesFromStart: $0.0, amountMilliliters: $0.1, rationale: "")
            },
            explanation: ""
        )
    }

    private func momentsByPeriod(
        _ draft: GeneratedDailyPlanDraft,
        context: DailyPlanContext
    ) -> [HydrationDayPeriod: [GeneratedPlanMoment]] {
        Dictionary(grouping: draft.moments) { moment in
            let date = calendar.date(
                byAdding: .minute,
                value: moment.minutesFromStart,
                to: context.planningStart
            ) ?? context.planningStart
            return DailyPlanPeriodPlanner(calendar: calendar).period(containing: date)
        }
    }

    private func failures(
        for draft: GeneratedDailyPlanDraft,
        context: DailyPlanContext
    ) -> [DailyPlanValidationFailure] {
        let result = DailyPlanValidator(calendar: calendar).validate(
            draft: draft,
            context: context,
            constraints: .make(from: context)
        )
        if case .invalid(let failures) = result { return failures }
        return []
    }
}
