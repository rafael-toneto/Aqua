import Foundation

enum HydrationDayPeriod: String, Codable, Sendable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening

    var id: Self { self }

    /// Keeps the afternoon as the main planning window while avoiding a
    /// disproportionate concentration near the end of the active day.
    var planningPriority: Double {
        switch self {
        case .morning: 1.0
        case .afternoon: 1.6
        case .evening: 0.8
        }
    }

    var startMinutesFromMidnight: Int {
        switch self {
        case .morning: 0
        case .afternoon: 12 * 60
        case .evening: 18 * 60
        }
    }

    var endMinutesFromMidnight: Int {
        switch self {
        case .morning: 12 * 60
        case .afternoon: 18 * 60
        case .evening: 24 * 60
        }
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let minute = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        return (startMinutesFromMidnight..<endMinutesFromMidnight).contains(minute)
    }

    func endDate(on calendarDay: Date, calendar: Calendar) -> Date {
        calendar.date(
            byAdding: .minute,
            value: endMinutesFromMidnight,
            to: calendar.startOfDay(for: calendarDay)
        ) ?? calendarDay
    }
}

struct HydrationPlanPeriodTarget: Codable, Sendable, Equatable, Identifiable {
    let period: HydrationDayPeriod
    let originalMilliliters: Int
    var plannedMilliliters: Int

    var id: HydrationDayPeriod { period }

    var wasAdjusted: Bool {
        plannedMilliliters != originalMilliliters
    }
}

struct DailyPlanPeriodPlanner: Sendable {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func initialTargets(
        goalMilliliters: Int,
        entries: [HydrationEntrySnapshot],
        moments: [HydrationPlanMoment],
        preferences: PlanningPreferences
    ) -> [HydrationPlanPeriodTarget] {
        var amounts = Dictionary(
            uniqueKeysWithValues: HydrationDayPeriod.allCases.map { ($0, 0) }
        )
        var amountLeft = max(goalMilliliters, 0)

        for entry in entries.sorted(by: { $0.date < $1.date }) where amountLeft > 0 {
            let accepted = min(max(entry.amountMilliliters, 0), amountLeft)
            amounts[period(containing: entry.date), default: 0] += accepted
            amountLeft -= accepted
        }

        for moment in moments.sorted(by: { $0.scheduledDate < $1.scheduledDate })
            where amountLeft > 0 {
            let accepted = min(max(moment.remainingMilliliters, 0), amountLeft)
            amounts[period(containing: moment.scheduledDate), default: 0] += accepted
            amountLeft -= accepted
        }

        if amountLeft > 0 {
            let weights = activeMinuteWeights(preferences: preferences)
            let fallback = allocate(amountLeft, weights: weights)
            for period in HydrationDayPeriod.allCases {
                amounts[period, default: 0] += fallback[period, default: 0]
            }
        }

        return HydrationDayPeriod.allCases.map { period in
            let amount = amounts[period, default: 0]
            return HydrationPlanPeriodTarget(
                period: period,
                originalMilliliters: amount,
                plannedMilliliters: amount
            )
        }
    }

    func synchronizedTargets(
        _ targets: [HydrationPlanPeriodTarget],
        entries: [HydrationEntrySnapshot],
        goalMilliliters: Int,
        now: Date,
        automaticRedistributionEnabled: Bool
    ) -> [HydrationPlanPeriodTarget] {
        let normalized = normalizedTargets(targets, goalMilliliters: goalMilliliters)
        guard automaticRedistributionEnabled else {
            return normalized.map {
                HydrationPlanPeriodTarget(
                    period: $0.period,
                    originalMilliliters: $0.originalMilliliters,
                    plannedMilliliters: $0.originalMilliliters
                )
            }
        }

        let consumed = consumedByPeriod(entries)
        var result = normalized
        var remainingGoal = max(goalMilliliters, 0)

        for index in HydrationDayPeriod.allCases.indices {
            let remainingPeriods = Array(HydrationDayPeriod.allCases[index...])
            let weights = Dictionary(uniqueKeysWithValues: remainingPeriods.map { period in
                let original = normalized.first(where: { $0.period == period })?.originalMilliliters ?? 0
                return (period, original)
            })
            let allocations = allocate(remainingGoal, weights: weights)
            let period = HydrationDayPeriod.allCases[index]
            let target = allocations[period, default: 0]

            if let targetIndex = result.firstIndex(where: { $0.period == period }) {
                result[targetIndex].plannedMilliliters = target
            }

            let actual = consumed[period, default: 0]
            let hasEnded = now >= period.endDate(on: now, calendar: calendar)
            let wasExceeded = actual > target
            guard hasEnded || wasExceeded else {
                for futurePeriod in remainingPeriods.dropFirst() {
                    if let futureIndex = result.firstIndex(where: { $0.period == futurePeriod }) {
                        result[futureIndex].plannedMilliliters = allocations[futurePeriod, default: 0]
                    }
                }
                break
            }

            remainingGoal = max(remainingGoal - actual, 0)
        }

        return result
    }

    func consumedByPeriod(
        _ entries: [HydrationEntrySnapshot]
    ) -> [HydrationDayPeriod: Int] {
        var result = Dictionary(
            uniqueKeysWithValues: HydrationDayPeriod.allCases.map { ($0, 0) }
        )
        for entry in entries {
            let period = period(containing: entry.date)
            let addition = result[period, default: 0].addingReportingOverflow(
                max(entry.amountMilliliters, 0)
            )
            result[period] = addition.overflow ? Int.max : addition.partialValue
        }
        return result
    }

    func period(containing date: Date) -> HydrationDayPeriod {
        HydrationDayPeriod.allCases.first(where: { $0.contains(date, calendar: calendar) })
            ?? .evening
    }

    private func normalizedTargets(
        _ targets: [HydrationPlanPeriodTarget],
        goalMilliliters: Int
    ) -> [HydrationPlanPeriodTarget] {
        var originals: [HydrationDayPeriod: Int] = [:]
        for target in targets {
            originals[target.period] = max(target.originalMilliliters, 0)
        }
        let allocated = allocate(max(goalMilliliters, 0), weights: originals)
        return HydrationDayPeriod.allCases.map { period in
            let amount = allocated[period, default: 0]
            return HydrationPlanPeriodTarget(
                period: period,
                originalMilliliters: amount,
                plannedMilliliters: amount
            )
        }
    }

    private func activeMinuteWeights(
        preferences: PlanningPreferences
    ) -> [HydrationDayPeriod: Int] {
        Dictionary(uniqueKeysWithValues: HydrationDayPeriod.allCases.map { period in
            let overlapStart = max(
                period.startMinutesFromMidnight,
                preferences.activeDayStartMinutes
            )
            let overlapEnd = min(
                period.endMinutesFromMidnight,
                preferences.activeDayEndMinutes
            )
            let overlapMinutes = max(overlapEnd - overlapStart, 0)
            return (
                period,
                Int((Double(overlapMinutes) * period.planningPriority * 100).rounded())
            )
        })
    }

    private func allocate(
        _ amount: Int,
        weights: [HydrationDayPeriod: Int]
    ) -> [HydrationDayPeriod: Int] {
        let configuredPeriods = HydrationDayPeriod.allCases.filter { weights[$0] != nil }
        guard !configuredPeriods.isEmpty else { return [:] }
        let safeAmount = max(amount, 0)
        var safeWeights = Dictionary(uniqueKeysWithValues: configuredPeriods.map {
            ($0, max(weights[$0, default: 0], 0))
        })
        if safeWeights.values.reduce(0, +) == 0 {
            safeWeights = Dictionary(uniqueKeysWithValues: configuredPeriods.map { ($0, 1) })
        }
        let periods = configuredPeriods.filter { safeWeights[$0, default: 0] > 0 }
        let totalWeight = safeWeights.values.reduce(0, +)
        var result: [HydrationDayPeriod: Int] = [:]
        var fractionalRemainders: [HydrationDayPeriod: Double] = [:]
        var assigned = 0

        for period in periods {
            let exactShare = Double(safeAmount) * Double(safeWeights[period, default: 0])
                / Double(totalWeight)
            let share = Int(exactShare.rounded(.down))
            result[period] = share
            fractionalRemainders[period] = exactShare - Double(share)
            assigned += share
        }

        var remainder = safeAmount - assigned
        let remainderOrder = periods.sorted { first, second in
            let firstFraction = fractionalRemainders[first, default: 0]
            let secondFraction = fractionalRemainders[second, default: 0]
            if firstFraction != secondFraction {
                return firstFraction > secondFraction
            }
            if first.planningPriority != second.planningPriority {
                return first.planningPriority > second.planningPriority
            }
            return (HydrationDayPeriod.allCases.firstIndex(of: first) ?? 0)
                < (HydrationDayPeriod.allCases.firstIndex(of: second) ?? 0)
        }
        var index = 0
        while remainder > 0 {
            result[remainderOrder[index % remainderOrder.count], default: 0] += 1
            remainder -= 1
            index += 1
        }
        return result
    }
}
