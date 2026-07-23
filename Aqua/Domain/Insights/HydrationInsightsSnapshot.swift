import Foundation

struct HydrationInsightsSnapshot: Equatable, Sendable {
    let periodStart: Date
    let periodEnd: Date
    let analyzedDayCount: Int
    let daysWithEntries: Int
    let daysWithoutEntries: Int
    let totalEntryCount: Int
    let dailyGoalMilliliters: Double
    let goalAchievementPercentage: Double
    let averageDailyConsumptionMilliliters: Double
    let averageEntriesPerDay: Double
    let averageFirstEntryMinutes: Double?
    let averageLastEntryMinutes: Double?
    let morningConsumptionPercentage: Double
    let afternoonConsumptionPercentage: Double
    let eveningConsumptionPercentage: Double
    let averageIntervalMinutes: Double?
    let lateDayConsumptionPercentage: Double
    /// Share of logs linked to a plan moment. It never infers unobserved missed moments.
    let planMomentAdherencePercentage: Double
    /// Difference between the latest and previous seven-day averages, relative to the saved goal.
    let recentTrendPercentage: Double

    var hasSufficientHistory: Bool {
        daysWithEntries >= 3 && totalEntryCount >= 3
    }

    func evidence(for metric: HydrationInsightEvidenceMetric) -> String {
        switch metric {
        case .goalAchievement:
            return "Goal reached on \(whole(goalAchievementPercentage))% of analyzed days"
        case .averageDailyConsumption:
            return "Average of \(whole(averageDailyConsumptionMilliliters)) ml per day"
        case .averageEntries:
            return "Average of \(decimal(averageEntriesPerDay)) entries per day"
        case .firstEntryTime:
            return "Average first entry at \(time(averageFirstEntryMinutes))"
        case .lastEntryTime:
            return "Average last entry at \(time(averageLastEntryMinutes))"
        case .dayDistribution:
            return "\(whole(morningConsumptionPercentage))% morning, \(whole(afternoonConsumptionPercentage))% afternoon, \(whole(eveningConsumptionPercentage))% evening"
        case .averageInterval:
            return "Average interval of \(whole(averageIntervalMinutes ?? 0)) minutes"
        case .lateDayConcentration:
            return "\(whole(lateDayConsumptionPercentage))% of recorded volume after 6 PM"
        case .planAdherence:
            return "\(whole(planMomentAdherencePercentage))% of entries linked to plan moments"
        case .daysWithoutEntries:
            return "\(daysWithoutEntries) of \(analyzedDayCount) days had no entries"
        case .recentTrend:
            let direction = recentTrendPercentage >= 0 ? "higher" : "lower"
            return "Recent daily average is \(whole(abs(recentTrendPercentage)))% \(direction) relative to your goal"
        }
    }

    var compactPrompt: String {
        """
        analyzedDays=\(analyzedDayCount)
        daysWithEntries=\(daysWithEntries)
        daysWithoutEntries=\(daysWithoutEntries)
        totalEntries=\(totalEntryCount)
        dailyGoalMilliliters=\(whole(dailyGoalMilliliters))
        goalAchievementPercent=\(decimal(goalAchievementPercentage))
        averageDailyMilliliters=\(decimal(averageDailyConsumptionMilliliters))
        averageEntriesPerDay=\(decimal(averageEntriesPerDay))
        averageFirstEntryMinutes=\(optionalDecimal(averageFirstEntryMinutes))
        averageLastEntryMinutes=\(optionalDecimal(averageLastEntryMinutes))
        morningConsumptionPercent=\(decimal(morningConsumptionPercentage))
        afternoonConsumptionPercent=\(decimal(afternoonConsumptionPercentage))
        eveningConsumptionPercent=\(decimal(eveningConsumptionPercentage))
        averageIntervalMinutes=\(optionalDecimal(averageIntervalMinutes))
        lateDayConsumptionPercent=\(decimal(lateDayConsumptionPercentage))
        planLinkedEntryPercent=\(decimal(planMomentAdherencePercentage))
        recentTrendRelativeToGoalPercent=\(decimal(recentTrendPercentage))
        """
    }

    private func time(_ minutes: Double?) -> String {
        guard let minutes else { return "unavailable" }
        let safeMinutes = min(max(Int(minutes.rounded()), 0), 1_439)
        let hour = safeMinutes / 60
        let minute = safeMinutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }

    private func whole(_ value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Int(value.rounded())
    }

    private func decimal(_ value: Double) -> String {
        guard value.isFinite else { return "0.0" }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func optionalDecimal(_ value: Double?) -> String {
        value.map(decimal) ?? "unavailable"
    }
}
