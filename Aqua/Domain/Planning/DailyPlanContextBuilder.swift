import Foundation

struct DailyPlanContextBuilder: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    @MainActor
    func build(
        now: Date,
        dailyGoalMilliliters: Double,
        entries: [HydrationEntry],
        preferences: PlanningPreferences,
        existingPlan: DailyHydrationPlan?
    ) -> DailyPlanContext {
        let calendarDay = calendar.startOfDay(for: now)
        let goal = safeIntegerMilliliters(dailyGoalMilliliters)
        let snapshots = entries.map(HydrationEntrySnapshot.init(entry:))
        let consumed = snapshots.reduce(0) { partial, entry in
            let (sum, overflow) = partial.addingReportingOverflow(entry.amountMilliliters)
            return overflow ? Int.max : sum
        }
        let remaining = max(goal - min(consumed, goal), 0)
        let activeStart = date(on: calendarDay, minutesFromMidnight: preferences.activeDayStartMinutes)
        let activeEnd = date(on: calendarDay, minutesFromMidnight: preferences.activeDayEndMinutes)
        let effectiveDailyMomentCount = effectiveDailyMomentCount(
            goalMilliliters: goal,
            activeStart: activeStart,
            activeEnd: activeEnd,
            preferences: preferences
        )
        let preferredRemainingMomentCount = max(
            effectiveDailyMomentCount - min(snapshots.count, effectiveDailyMomentCount),
            1
        )
        let oneMinuteFromNow = calendar.date(byAdding: .minute, value: 1, to: now) ?? now
        var earliestFutureDate = max(activeStart, oneMinuteFromNow)
        if let lastEntryDate = snapshots.map(\.date).filter({ $0 <= now }).max(),
           let earliestAfterLastEntry = calendar.date(
               byAdding: .minute,
               value: preferences.minimumIntervalMinutes,
               to: lastEntryDate
           ) {
            earliestFutureDate = max(earliestFutureDate, earliestAfterLastEntry)
        }
        let planningStart = cadenceDate(
            onOrAfter: earliestFutureDate,
            activeStart: activeStart,
            activeEnd: activeEnd,
            momentCount: effectiveDailyMomentCount
        )
        let remainingMinutes = max(
            calendar.dateComponents([.minute], from: planningStart, to: activeEnd).minute ?? 0,
            0
        )

        return DailyPlanContext(
            calendar: calendar,
            now: now,
            calendarDay: calendarDay,
            dailyGoalMilliliters: goal,
            consumedMilliliters: consumed,
            remainingMilliliters: remaining,
            activeDayStart: activeStart,
            activeDayEnd: activeEnd,
            planningStart: planningStart,
            remainingActiveMinutes: remainingMinutes,
            preferredMomentCount: preferences.preferredMomentCount,
            preferredRemainingMomentCount: preferredRemainingMomentCount,
            preferredAmountMilliliters: preferences.preferredAmountMilliliters,
            minimumIntervalMinutes: preferences.minimumIntervalMinutes,
            existingPlan: existingPlan,
            todayEntries: snapshots,
            missedMoments: existingPlan?.moments.filter { $0.status == .missed } ?? [],
            partiallyCompletedMoments: existingPlan?.moments.filter {
                $0.status == .partiallyCompleted
            } ?? [],
            automaticRedistributionEnabled: preferences.automaticRedistributionEnabled,
            mayAddMoments: preferences.mayAddMoments,
            gracePeriodMinutes: DailyPlanRules.gracePeriodMinutes
        )
    }

    private func date(on day: Date, minutesFromMidnight: Int) -> Date {
        calendar.date(byAdding: .minute, value: minutesFromMidnight, to: day) ?? day
    }

    private func effectiveDailyMomentCount(
        goalMilliliters: Int,
        activeStart: Date,
        activeEnd: Date,
        preferences: PlanningPreferences
    ) -> Int {
        let activeMinutes = max(
            calendar.dateComponents([.minute], from: activeStart, to: activeEnd).minute ?? 0,
            0
        )
        guard activeMinutes > 0 else { return 1 }
        let maximumByInterval = max(
            ((activeMinutes - 1) / max(preferences.minimumIntervalMinutes, 1)) + 1,
            1
        )
        let amountBasedCount = ceilingDivision(
            goalMilliliters,
            by: max(preferences.preferredAmountMilliliters, 1)
        )
        return min(
            max(max(preferences.preferredMomentCount, amountBasedCount), 1),
            maximumByInterval
        )
    }

    private func cadenceDate(
        onOrAfter earliestDate: Date,
        activeStart: Date,
        activeEnd: Date,
        momentCount: Int
    ) -> Date {
        guard earliestDate < activeEnd else { return earliestDate }
        let activeMinutes = max(
            calendar.dateComponents([.minute], from: activeStart, to: activeEnd).minute ?? 0,
            0
        )
        guard activeMinutes > 0 else { return earliestDate }

        let latestOffset = max(activeMinutes - 1, 0)
        let offsets: [Int]
        if momentCount <= 1 {
            offsets = [latestOffset / 2]
        } else {
            offsets = (0..<momentCount).map { index in
                Int(
                    (Double(latestOffset) * Double(index) / Double(momentCount - 1)).rounded()
                )
            }
        }

        for offset in offsets {
            let candidate = calendar.date(
                byAdding: .minute,
                value: offset,
                to: activeStart
            ) ?? activeStart
            if candidate >= earliestDate, candidate < activeEnd {
                return candidate
            }
        }
        return earliestDate
    }

    private func ceilingDivision(_ numerator: Int, by denominator: Int) -> Int {
        guard numerator > 0, denominator > 0 else { return 0 }
        return numerator / denominator + (numerator % denominator == 0 ? 0 : 1)
    }

    private func safeIntegerMilliliters(_ amount: Double) -> Int {
        guard amount.isFinite, amount > 0 else { return 0 }
        let rounded = amount.rounded()
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }
}
