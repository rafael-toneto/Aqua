import Foundation

struct HydrationInsightsMetricsCalculator: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func makeSnapshot(
        summaries: [HydrationDaySummary],
        dailyGoalMilliliters: Double,
        periodStart: Date,
        periodEnd: Date
    ) -> HydrationInsightsSnapshot {
        let ordered = summaries.sorted { $0.date < $1.date }
        let analyzedDays = ordered.count
        let entriesByDay = ordered.map { summary in
            summary.entries
                .filter { $0.amountInMilliliters.isFinite && $0.amountInMilliliters > 0 }
                .sorted { $0.date < $1.date }
        }
        let allEntries = entriesByDay.flatMap { $0 }
        let daysWithEntries = entriesByDay.count { !$0.isEmpty }
        let dailyAmounts = entriesByDay.map { entries in
            entries.reduce(0.0) { $0 + $1.amountInMilliliters }
        }
        let totalAmount = dailyAmounts.reduce(0, +)
        let safeGoal = dailyGoalMilliliters.isFinite ? max(dailyGoalMilliliters, 0) : 0
        let reachedGoalDays = safeGoal > 0
            ? dailyAmounts.count { $0 >= safeGoal }
            : 0

        let firstEntryMinutes = entriesByDay.compactMap { entries in
            entries.first.map(minutesFromMidnight)
        }
        let lastEntryMinutes = entriesByDay.compactMap { entries in
            entries.last.map(minutesFromMidnight)
        }
        let intervals = entriesByDay.flatMap { entries in
            zip(entries, entries.dropFirst()).compactMap { first, second -> Double? in
                let minutes = second.date.timeIntervalSince(first.date) / 60
                return minutes.isFinite && minutes >= 0 ? minutes : nil
            }
        }

        var periodAmounts = Dictionary(
            uniqueKeysWithValues: HydrationDayPeriod.allCases.map { ($0, 0.0) }
        )
        for entry in allEntries {
            let period = HydrationDayPeriod.allCases.first {
                $0.contains(entry.date, calendar: calendar)
            } ?? .evening
            periodAmounts[period, default: 0] += entry.amountInMilliliters
        }

        let linkedPlanEntryCount = allEntries.count {
            $0.planMomentID != nil || $0.source == .plan
        }
        // Compare equally sized recent and previous groups of recorded days. A maximum of
        // seven days per group keeps the comparison meaningful in the fourteen-record window.
        let comparisonDayCount = min(7, dailyAmounts.count / 2)
        let recentAmounts = Array(dailyAmounts.suffix(comparisonDayCount))
        let previousAmounts = Array(dailyAmounts.prefix(comparisonDayCount))
        let previousAverage = average(previousAmounts)
        let recentAverage = average(recentAmounts)
        let recentTrend = safeGoal > 0
            ? ((recentAverage - previousAverage) / safeGoal) * 100
            : 0

        return HydrationInsightsSnapshot(
            periodStart: calendar.startOfDay(for: periodStart),
            periodEnd: calendar.startOfDay(for: periodEnd),
            analyzedDayCount: analyzedDays,
            daysWithEntries: daysWithEntries,
            daysWithoutEntries: max(analyzedDays - daysWithEntries, 0),
            totalEntryCount: allEntries.count,
            dailyGoalMilliliters: safeGoal,
            goalAchievementPercentage: percentage(reachedGoalDays, of: analyzedDays),
            averageDailyConsumptionMilliliters: average(dailyAmounts),
            averageEntriesPerDay: analyzedDays > 0
                ? Double(allEntries.count) / Double(analyzedDays)
                : 0,
            averageFirstEntryMinutes: optionalAverage(firstEntryMinutes),
            averageLastEntryMinutes: optionalAverage(lastEntryMinutes),
            morningConsumptionPercentage: percentage(
                periodAmounts[.morning, default: 0],
                of: totalAmount
            ),
            afternoonConsumptionPercentage: percentage(
                periodAmounts[.afternoon, default: 0],
                of: totalAmount
            ),
            eveningConsumptionPercentage: percentage(
                periodAmounts[.evening, default: 0],
                of: totalAmount
            ),
            averageIntervalMinutes: optionalAverage(intervals),
            lateDayConsumptionPercentage: percentage(
                periodAmounts[.evening, default: 0],
                of: totalAmount
            ),
            planMomentAdherencePercentage: percentage(
                linkedPlanEntryCount,
                of: allEntries.count
            ),
            recentTrendPercentage: recentTrend.isFinite ? recentTrend : 0
        )
    }

    private func minutesFromMidnight(_ entry: HydrationEntry) -> Double {
        Double(
            calendar.component(.hour, from: entry.date) * 60
                + calendar.component(.minute, from: entry.date)
        )
    }

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private func optionalAverage(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : average(values)
    }

    private func percentage(_ value: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total) * 100
    }

    private func percentage(_ value: Double, of total: Double) -> Double {
        guard total > 0, value.isFinite, total.isFinite else { return 0 }
        return value / total * 100
    }
}
