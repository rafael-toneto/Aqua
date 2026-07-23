import Foundation

struct DailyPlanConstraints: Sendable, Equatable {
    let earliestDate: Date
    let latestDate: Date
    let calendarDay: Date
    let remainingMilliliters: Int
    let minimumIntervalMinutes: Int
    let maximumMomentCount: Int
    let maximumMomentMilliliters: Int

    static func make(from context: DailyPlanContext) -> DailyPlanConstraints {
        DailyPlanConstraints(
            earliestDate: context.planningStart,
            latestDate: context.activeDayEnd,
            calendarDay: context.calendarDay,
            remainingMilliliters: context.remainingMilliliters,
            minimumIntervalMinutes: context.minimumIntervalMinutes,
            maximumMomentCount: 24,
            maximumMomentMilliliters: 10_000
        )
    }
}

enum DailyPlanValidationFailure: String, Error, Sendable, Equatable {
    case expectedEmptyPlan
    case expectedMoments
    case nonPositiveAmount
    case wrongTotal
    case unorderedMoments
    case duplicateTimes
    case outsideActiveWindow
    case outsideCalendarDay
    case insufficientInterval
    case tooManyMoments
    case amountExceedsGuardrail
    case integerOverflow
    case unexpectedMomentCount
    case unevenMomentAmounts
    case unbalancedPeriodDistribution
}

enum DailyPlanValidationResult: Sendable, Equatable {
    case valid
    case invalid([DailyPlanValidationFailure])

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

protocol DailyPlanValidating: Sendable {
    func validate(
        draft: GeneratedDailyPlanDraft,
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) -> DailyPlanValidationResult
}

struct DailyPlanValidator: DailyPlanValidating {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func validate(
        draft: GeneratedDailyPlanDraft,
        context: DailyPlanContext,
        constraints: DailyPlanConstraints
    ) -> DailyPlanValidationResult {
        var failures: [DailyPlanValidationFailure] = []

        if constraints.remainingMilliliters == 0, !draft.moments.isEmpty {
            failures.append(.expectedEmptyPlan)
        }
        if constraints.remainingMilliliters > 0, draft.moments.isEmpty {
            failures.append(.expectedMoments)
        }
        if draft.moments.count > constraints.maximumMomentCount {
            failures.append(.tooManyMoments)
        }
        if draft.moments.contains(where: { $0.amountMilliliters <= 0 }) {
            failures.append(.nonPositiveAmount)
        }
        if draft.moments.contains(where: {
            $0.amountMilliliters > constraints.maximumMomentMilliliters
        }) {
            failures.append(.amountExceedsGuardrail)
        }

        var total = 0
        for moment in draft.moments {
            let addition = total.addingReportingOverflow(moment.amountMilliliters)
            if addition.overflow {
                failures.append(.integerOverflow)
                break
            }
            total = addition.partialValue
        }
        if total != constraints.remainingMilliliters {
            failures.append(.wrongTotal)
        }

        let dates = draft.moments.map { moment in
            calendar.date(
                byAdding: .minute,
                value: moment.minutesFromStart,
                to: context.planningStart
            ) ?? .distantPast
        }
        if dates != dates.sorted() {
            failures.append(.unorderedMoments)
        }
        if Set(dates).count != dates.count {
            failures.append(.duplicateTimes)
        }
        if dates.contains(where: {
            $0 < constraints.earliestDate || $0 >= constraints.latestDate || $0 <= context.now
        }) {
            failures.append(.outsideActiveWindow)
        }
        if dates.contains(where: { !calendar.isDate($0, inSameDayAs: constraints.calendarDay) }) {
            failures.append(.outsideCalendarDay)
        }

        let minimumInterval = TimeInterval(constraints.minimumIntervalMinutes * 60)
        if zip(dates, dates.dropFirst()).contains(where: { second, first in
            first.timeIntervalSince(second) < minimumInterval
        }) {
            failures.append(.insufficientInterval)
        }

        if let expectedDistribution = try? DailyPlanDistributionPolicy().makeDistribution(
            context: context,
            constraints: constraints
        ) {
            if draft.moments.count != expectedDistribution.moments.count {
                failures.append(.unexpectedMomentCount)
            }

            let expectedAmounts = expectedDistribution.moments
                .map(\.amountMilliliters)
                .sorted()
            let actualAmounts = draft.moments
                .map(\.amountMilliliters)
                .sorted()
            if actualAmounts != expectedAmounts {
                failures.append(.unevenMomentAmounts)
            }

            let hasUnexpectedPeriodCount = HydrationDayPeriod.allCases.contains { period in
                let expectedCount = expectedDistribution.momentCount(
                    in: period,
                    planningStart: context.planningStart,
                    calendar: calendar
                )
                let actualCount = dates.count {
                    period.contains($0, calendar: calendar)
                }
                let expectedAmount = expectedDistribution.amountMilliliters(
                    in: period,
                    planningStart: context.planningStart,
                    calendar: calendar
                )
                var actualAmount = 0
                for (date, moment) in zip(dates, draft.moments)
                    where period.contains(date, calendar: calendar) {
                    let addition = actualAmount.addingReportingOverflow(
                        moment.amountMilliliters
                    )
                    actualAmount = addition.overflow ? Int.max : addition.partialValue
                }
                return actualCount != expectedCount || actualAmount != expectedAmount
            }
            if hasUnexpectedPeriodCount {
                failures.append(.unbalancedPeriodDistribution)
            }
        }

        let uniqueFailures = Array(Set(failures)).sorted { $0.rawValue < $1.rawValue }
        return uniqueFailures.isEmpty ? .valid : .invalid(uniqueFailures)
    }
}
