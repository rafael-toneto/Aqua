import Foundation

struct DailyPlanDistribution: Sendable, Equatable {
    let moments: [GeneratedPlanMoment]

    func momentCount(
        in period: HydrationDayPeriod,
        planningStart: Date,
        calendar: Calendar
    ) -> Int {
        moments.count { moment in
            period.contains(
                calendar.date(
                    byAdding: .minute,
                    value: moment.minutesFromStart,
                    to: planningStart
                ) ?? planningStart,
                calendar: calendar
            )
        }
    }

    func amountMilliliters(
        in period: HydrationDayPeriod,
        planningStart: Date,
        calendar: Calendar
    ) -> Int {
        moments.reduce(0) { total, moment in
            let date = calendar.date(
                byAdding: .minute,
                value: moment.minutesFromStart,
                to: planningStart
            ) ?? planningStart
            return period.contains(date, calendar: calendar)
                ? total + moment.amountMilliliters
                : total
        }
    }
}

struct DailyPlanDistributionPolicy: Sendable {
    func makeDistribution(
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) throws -> DailyPlanDistribution {
        guard context.remainingMilliliters > 0 else {
            return DailyPlanDistribution(moments: [])
        }
        guard context.remainingActiveMinutes > 0 else {
            throw PlanGenerationError.noActiveTimeRemaining
        }

        let count = targetMomentCount(context: context, constraints: constraints)
        guard count > 0 else { throw PlanGenerationError.invalidFallback }

        let baseAmount = context.remainingMilliliters / count
        let remainder = context.remainingMilliliters % count
        guard baseAmount > 0, baseAmount <= constraints.maximumMomentMilliliters else {
            throw PlanGenerationError.invalidFallback
        }

        let offsets = weightedOffsets(
            count: count,
            context: context,
            minimumIntervalMinutes: constraints.minimumIntervalMinutes
        )
        guard offsets.count == count else { throw PlanGenerationError.invalidFallback }

        return DailyPlanDistribution(
            moments: offsets.enumerated().map { index, offset in
                GeneratedPlanMoment(
                    minutesFromStart: offset,
                    amountMilliliters: baseAmount + (index < remainder ? 1 : 0),
                    rationale: "Part of the remaining user-selected goal."
                )
            }
        )
    }

    private func targetMomentCount(
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) -> Int {
        let minimumInterval = max(constraints.minimumIntervalMinutes, 1)
        let maximumByInterval = max(
            min(
                ((context.remainingActiveMinutes - 1) / minimumInterval) + 1,
                constraints.maximumMomentCount
            ),
            1
        )
        let guardrailBasedCount = ceilingDivision(
            context.remainingMilliliters,
            by: constraints.maximumMomentMilliliters
        )
        var requestedCount = max(context.preferredRemainingMomentCount, guardrailBasedCount)

        if context.mayAddMoments {
            let preferredAmount = max(context.preferredAmountMilliliters, 1)
            let toleratedAmount = preferredAmount + preferredAmount / 4
            requestedCount = max(
                requestedCount,
                ceilingDivision(context.remainingMilliliters, by: toleratedAmount)
            )
        }

        return min(
            max(requestedCount, 1),
            maximumByInterval,
            context.remainingMilliliters
        )
    }

    private func weightedOffsets(
        count: Int,
        context: DailyPlanContext,
        minimumIntervalMinutes: Int
    ) -> [Int] {
        guard count > 1 else { return [0] }

        let latestOffset = max(context.remainingActiveMinutes - 1, 0)
        let segments = weightedSegments(context: context)
        let totalWeight = segments.reduce(0.0) { $0 + $1.weightedDuration }
        guard totalWeight > 0 else {
            return evenlySpacedOffsets(count: count, latestOffset: latestOffset)
        }

        let targets = (0..<count).map { index -> Int in
            let quantile = Double(index) / Double(count - 1)
            let weightedPosition = totalWeight * quantile
            var traversedWeight = 0.0

            for (segmentIndex, segment) in segments.enumerated() {
                let segmentEndWeight = traversedWeight + segment.weightedDuration
                let isLastSegment = segmentIndex == segments.count - 1
                if weightedPosition <= segmentEndWeight || isLastSegment {
                    let positionInsideSegment = max(weightedPosition - traversedWeight, 0)
                    let unweightedMinutes = positionInsideSegment / segment.weight
                    return min(
                        Int((Double(segment.startOffset) + unweightedMinutes).rounded()),
                        latestOffset
                    )
                }
                traversedWeight = segmentEndWeight
            }
            return latestOffset
        }

        let minimumInterval = max(minimumIntervalMinutes, 1)
        var result: [Int] = []
        result.reserveCapacity(count)
        for index in targets.indices {
            let lowerBound = index * minimumInterval
            let upperBound = latestOffset - (count - index - 1) * minimumInterval
            let previousMinimum = (result.last ?? -minimumInterval) + minimumInterval
            result.append(
                min(max(max(targets[index], lowerBound), previousMinimum), upperBound)
            )
        }
        return result
    }

    private func weightedSegments(
        context: DailyPlanContext
    ) -> [WeightedTimeSegment] {
        HydrationDayPeriod.allCases.compactMap { period in
            let periodStart = context.calendar.date(
                byAdding: .minute,
                value: period.startMinutesFromMidnight,
                to: context.calendarDay
            ) ?? context.calendarDay
            let periodEnd = context.calendar.date(
                byAdding: .minute,
                value: period.endMinutesFromMidnight,
                to: context.calendarDay
            ) ?? context.activeDayEnd
            let start = max(context.planningStart, periodStart)
            let end = min(context.activeDayEnd, periodEnd)
            let duration = context.calendar.dateComponents(
                [.minute],
                from: start,
                to: end
            ).minute ?? 0
            guard duration > 0 else { return nil }

            let startOffset = max(
                context.calendar.dateComponents(
                    [.minute],
                    from: context.planningStart,
                    to: start
                ).minute ?? 0,
                0
            )
            return WeightedTimeSegment(
                startOffset: startOffset,
                duration: duration,
                weight: period.planningPriority
            )
        }
    }

    private func evenlySpacedOffsets(count: Int, latestOffset: Int) -> [Int] {
        (0..<count).map { index in
            Int(
                (Double(latestOffset) * Double(index) / Double(count - 1)).rounded()
            )
        }
    }

    private func ceilingDivision(_ numerator: Int, by denominator: Int) -> Int {
        guard numerator > 0, denominator > 0 else { return 0 }
        return numerator / denominator + (numerator % denominator == 0 ? 0 : 1)
    }
}

private struct WeightedTimeSegment {
    let startOffset: Int
    let duration: Int
    let weight: Double

    var weightedDuration: Double {
        Double(duration) * weight
    }
}
