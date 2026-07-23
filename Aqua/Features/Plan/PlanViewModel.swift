import Combine
import Foundation

struct PlanViewData: Equatable {
    let plan: DailyHydrationPlan?
    let entries: [HydrationEntry]
    let progress: DailyHydrationProgress
    let isOutsideActiveHours: Bool
    let periods: [PlanPeriodViewData]

    init(
        plan: DailyHydrationPlan?,
        entries: [HydrationEntry],
        progress: DailyHydrationProgress,
        isOutsideActiveHours: Bool,
        now: Date,
        preferences: PlanningPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.plan = plan
        self.entries = entries
        self.progress = progress
        self.isOutsideActiveHours = isOutsideActiveHours

        let planner = DailyPlanPeriodPlanner(calendar: calendar)
        let checkpointPlanner = PlanCheckpointPlanner(calendar: calendar)
        let snapshots = entries.map(HydrationEntrySnapshot.init(entry:))
        let currentRevisionMoments: [HydrationPlanMoment]
        if let plan {
            currentRevisionMoments = plan.moments.filter {
                $0.generatedRevision == plan.revision
            }
        } else {
            currentRevisionMoments = []
        }
        let targets = plan?.periodTargets ?? planner.initialTargets(
            goalMilliliters: Self.safeIntegerMilliliters(progress.dailyGoal),
            entries: snapshots,
            moments: currentRevisionMoments.filter { $0.status != .cancelled },
            preferences: preferences
        )
        var targetByPeriod: [HydrationDayPeriod: Int] = [:]
        for target in targets {
            targetByPeriod[target.period] = target.plannedMilliliters
        }
        let entriesByPeriod = Dictionary(grouping: entries) {
            planner.period(containing: $0.date)
        }
        periods = HydrationDayPeriod.allCases.map { period in
            PlanPeriodViewData(
                period: period,
                entries: entriesByPeriod[period, default: []].sorted { $0.date < $1.date },
                plannedMilliliters: targetByPeriod[period, default: 0],
                checkpoints: checkpointPlanner.checkpoints(
                    for: period,
                    plannedMilliliters: targetByPeriod[period, default: 0],
                    moments: currentRevisionMoments,
                    preferences: preferences,
                    calendarDay: now
                ),
                now: now,
                calendar: calendar
            )
        }
    }

    var visibleMoments: [HydrationPlanMoment] {
        guard let plan else { return [] }
        return plan.moments
            .filter { moment in
                moment.generatedRevision == plan.revision
                    && ![.completed, .missed, .cancelled].contains(moment.status)
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var hasTimelineItems: Bool {
        !periods.isEmpty
    }

    var hasRedistributedPeriods: Bool {
        plan?.periodTargets?.contains(where: \.wasAdjusted) == true
    }

    var completedPeriodCount: Int {
        periods.filter(\.isComplete).count
    }

    private static func safeIntegerMilliliters(_ amount: Double) -> Int {
        guard amount.isFinite, amount > 0 else { return 0 }
        let rounded = amount.rounded()
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }
}

enum PlanPeriodProgressState: Equatable {
    case completed
    case current
    case upcoming
    case missed
}

struct PlanCheckpointViewData: Identifiable, Equatable {
    let scheduledDate: Date
    let cumulativeMilliliters: Int

    var id: Date { scheduledDate }
}

struct PlanCheckpointPlanner {
    let calendar: Calendar

    init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    func checkpoints(
        for period: HydrationDayPeriod,
        plannedMilliliters: Int,
        moments: [HydrationPlanMoment],
        preferences: PlanningPreferences,
        calendarDay: Date
    ) -> [PlanCheckpointViewData] {
        let target = max(plannedMilliliters, 0)
        guard target > 0 else { return [] }

        let agentMoments = moments
            .filter {
                $0.plannedMilliliters > 0
                    && calendar.isDate($0.scheduledDate, inSameDayAs: calendarDay)
                    && period.contains($0.scheduledDate, calendar: calendar)
            }
            .sorted { $0.scheduledDate < $1.scheduledDate }

        if !agentMoments.isEmpty {
            return makeCheckpoints(
                dates: agentMoments.map(\.scheduledDate),
                weights: agentMoments.map(\.plannedMilliliters),
                target: target
            )
        }

        let dates = fallbackDates(
            for: period,
            target: target,
            preferences: preferences,
            calendarDay: calendarDay
        )
        return makeCheckpoints(
            dates: dates,
            weights: Array(repeating: 1, count: dates.count),
            target: target
        )
    }

    private func makeCheckpoints(
        dates: [Date],
        weights: [Int],
        target: Int
    ) -> [PlanCheckpointViewData] {
        let count = min(dates.count, weights.count, target)
        guard count > 0 else { return [] }

        let selectedDates = Array(dates.suffix(count))
        let selectedWeights = weights.suffix(count).map { max($0, 1) }
        let totalWeight = selectedWeights.reduce(0, +)
        var runningWeight = 0
        var previousTarget = 0

        return selectedDates.enumerated().map { index, date in
            runningWeight += selectedWeights[index]
            let remainingCheckpointCount = count - index - 1
            let proportionalTarget = Int(
                (Double(target) * Double(runningWeight) / Double(totalWeight)).rounded()
            )
            let cumulativeTarget = index == count - 1
                ? target
                : min(
                    max(proportionalTarget, previousTarget + 1),
                    target - remainingCheckpointCount
                )
            previousTarget = cumulativeTarget
            return PlanCheckpointViewData(
                scheduledDate: date,
                cumulativeMilliliters: cumulativeTarget
            )
        }
    }

    private func fallbackDates(
        for period: HydrationDayPeriod,
        target: Int,
        preferences: PlanningPreferences,
        calendarDay: Date
    ) -> [Date] {
        let overlapStartMinutes = max(
            period.startMinutesFromMidnight,
            preferences.activeDayStartMinutes
        )
        let overlapEndMinutes = min(
            period.endMinutesFromMidnight,
            preferences.activeDayEndMinutes
        )
        let overlapMinutes = max(overlapEndMinutes - overlapStartMinutes, 0)
        guard overlapMinutes > 0 else { return [] }

        let activeMinutes = max(
            preferences.activeDayEndMinutes - preferences.activeDayStartMinutes,
            1
        )
        let preferredAmount = max(preferences.preferredAmountMilliliters, 1)
        let amountBasedDailyCount = ceilingDivision(target, by: preferredAmount)
        let effectiveDailyCount = max(
            preferences.preferredMomentCount,
            amountBasedDailyCount
        )
        let proportionalCount = max(
            Int(
                (Double(effectiveDailyCount) * Double(overlapMinutes) / Double(activeMinutes))
                    .rounded()
            ),
            1
        )
        let amountBasedPeriodCount = ceilingDivision(target, by: preferredAmount)
        let requestedCount = preferences.mayAddMoments
            ? max(proportionalCount, amountBasedPeriodCount)
            : proportionalCount
        let minimumInterval = max(preferences.minimumIntervalMinutes, 1)
        let maximumByInterval = ((overlapMinutes - 1) / minimumInterval) + 1
        let count = min(
            max(requestedCount, 1),
            max(maximumByInterval, 1),
            24,
            target
        )
        let firstDate = calendar.date(
            byAdding: .minute,
            value: overlapStartMinutes,
            to: calendar.startOfDay(for: calendarDay)
        ) ?? calendarDay

        if count == 1 {
            return [
                calendar.date(
                    byAdding: .minute,
                    value: max((overlapMinutes - 1) / 2, 0),
                    to: firstDate
                ) ?? firstDate
            ]
        }

        let span = overlapMinutes - 1
        return (0..<count).map { index in
            let offset = Int(
                (Double(span) * Double(index) / Double(count - 1)).rounded()
            )
            return calendar.date(byAdding: .minute, value: offset, to: firstDate) ?? firstDate
        }
    }

    private func ceilingDivision(_ numerator: Int, by denominator: Int) -> Int {
        guard numerator > 0, denominator > 0 else { return 0 }
        return numerator / denominator + (numerator % denominator == 0 ? 0 : 1)
    }
}

struct PlanPeriodViewData: Identifiable, Equatable {
    let period: HydrationDayPeriod
    let entries: [HydrationEntry]
    let plannedMilliliters: Int
    let consumedMilliliters: Int
    let checkpoints: [PlanCheckpointViewData]
    let state: PlanPeriodProgressState

    var id: HydrationDayPeriod { period }
    var isComplete: Bool { state == .completed }
    var completedCheckpointCount: Int {
        checkpoints.filter { consumedMilliliters >= $0.cumulativeMilliliters }.count
    }

    init(
        period: HydrationDayPeriod,
        entries: [HydrationEntry],
        plannedMilliliters: Int,
        checkpoints: [PlanCheckpointViewData] = [],
        now: Date,
        calendar: Calendar
    ) {
        self.period = period
        self.entries = entries
        self.checkpoints = checkpoints
        let safePlanned = max(plannedMilliliters, 0)
        let consumed = entries.reduce(0) { partial, entry in
            let amount = Self.safeIntegerMilliliters(entry.amountInMilliliters)
            let addition = partial.addingReportingOverflow(amount)
            return addition.overflow ? Int.max : addition.partialValue
        }
        self.plannedMilliliters = safePlanned
        consumedMilliliters = consumed

        if consumed >= safePlanned {
            state = .completed
        } else if now >= period.endDate(on: now, calendar: calendar) {
            state = .missed
        } else if period.contains(now, calendar: calendar) {
            state = .current
        } else {
            state = .upcoming
        }
    }

    private static func safeIntegerMilliliters(_ amount: Double) -> Int {
        guard amount.isFinite, amount > 0 else { return 0 }
        let rounded = amount.rounded()
        guard rounded < Double(Int.max) else { return Int.max }
        return Int(rounded)
    }
}

enum PlanViewState: Equatable {
    case loading
    case empty(PlanViewData)
    case loaded(PlanViewData)
    case completed(PlanViewData)
    case outsideActiveHours(PlanViewData)
    case failed(message: String)

    var data: PlanViewData? {
        switch self {
        case .empty(let data), .loaded(let data), .completed(let data), .outsideActiveHours(let data):
            data
        case .loading, .failed:
            nil
        }
    }
}

@MainActor
final class PlanViewModel: ObservableObject {
    @Published private(set) var state: PlanViewState = .loading
    @Published private(set) var isPreparing = false
    @Published private(set) var feedbackTrigger = 0
    @Published private(set) var planningPreferences: PlanningPreferences
    @Published var errorMessage: String?

    private let service: AdaptivePlanService
    private let goalService: any HydrationGoalServiceProtocol
    private let trackingService: any HydrationTrackingServiceProtocol
    private let dateProvider: any DateProviding
    private var refreshTask: Task<Void, Never>?
    private var boundaryTask: Task<Void, Never>?
    private var activeRefreshID: UUID?
    private var hasPendingRefresh = false

    init(
        service: AdaptivePlanService,
        goalService: any HydrationGoalServiceProtocol,
        trackingService: any HydrationTrackingServiceProtocol,
        dateProvider: any DateProviding
    ) {
        self.service = service
        self.goalService = goalService
        self.trackingService = trackingService
        self.dateProvider = dateProvider
        planningPreferences = service.planningPreferences
    }

    func requestRefresh(
        forceRegeneration: Bool = false,
        debounce: Bool = false,
        displaysLoading: Bool = false
    ) {
        if isPreparing && !forceRegeneration {
            hasPendingRefresh = true
            if displaysLoading {
                boundaryTask?.cancel()
                state = .loading
            }
            return
        }
        refreshTask?.cancel()
        if displaysLoading {
            boundaryTask?.cancel()
            state = .loading
        }
        refreshTask = Task { [weak self] in
            if debounce {
                try? await Task.sleep(for: .milliseconds(300))
            }
            guard !Task.isCancelled else { return }
            await self?.refresh(
                forceRegeneration: forceRegeneration,
                displaysLoading: displaysLoading
            )
        }
    }

    func refresh(
        forceRegeneration: Bool = false,
        displaysLoading: Bool = false
    ) async {
        if isPreparing && !forceRegeneration { return }
        let refreshID = UUID()
        activeRefreshID = refreshID
        if displaysLoading {
            boundaryTask?.cancel()
            state = .loading
        }
        isPreparing = true
        defer {
            if activeRefreshID == refreshID {
                isPreparing = false
                activeRefreshID = nil
                performPendingRefreshIfNeeded()
            }
        }

        do {
            let result = try await service.preparePlan(
                now: dateProvider.now,
                forceRegeneration: forceRegeneration
            )
            guard !Task.isCancelled, activeRefreshID == refreshID else { return }
            try await apply(result)
            scheduleNextBoundaryRefresh()
            errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            if state.data == nil { state = .failed(message: error.localizedDescription) }
            errorMessage = error.localizedDescription
        }
    }

    func viewDidAppear() {
        let displayedGoal = state.data?.progress.dailyGoal
        let savedGoal = goalService.dailyGoalInMilliliters
        let dailyGoalChanged = displayedGoal.map { $0 != savedGoal } ?? false

        requestRefresh(
            forceRegeneration: dailyGoalChanged,
            displaysLoading: state.data == nil || dailyGoalChanged
        )
    }

    func viewDidDisappear() {
        refreshTask?.cancel()
        boundaryTask?.cancel()
        hasPendingRefresh = false
    }

    func addPlannedAmount(_ moment: HydrationPlanMoment) async {
        guard let plan = state.data?.plan else { return }
        boundaryTask?.cancel()
        isPreparing = true
        defer {
            isPreparing = false
            performPendingRefreshIfNeeded()
        }
        do {
            let result = try await service.addPlannedAmount(
                for: moment,
                in: plan,
                now: dateProvider.now
            )
            try await apply(result)
            scheduleNextBoundaryRefresh()
            feedbackTrigger += 1
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePreferences(_ preferences: PlanningPreferences) throws {
        let previousPreferences = planningPreferences
        try service.updatePlanningPreferences(preferences)
        planningPreferences = preferences

        guard preferences.requiresPlanRegeneration(comparedTo: previousPreferences) else {
            return
        }
        requestRefresh(forceRegeneration: true, displaysLoading: true)
    }

    func dailyGoalDidChange() {
        requestRefresh(forceRegeneration: true, displaysLoading: true)
    }

    private func apply(_ result: DailyPlanLoadResult) async throws {
        let summary = try await trackingService.summary(
            for: dateProvider.now,
            dailyGoal: goalService.dailyGoalInMilliliters
        )
        switch result {
        case .plan(let plan):
            let data = PlanViewData(
                plan: plan,
                entries: summary.entries,
                progress: summary.progress,
                isOutsideActiveHours: false,
                now: dateProvider.now,
                preferences: planningPreferences
            )
            state = data.hasTimelineItems ? .loaded(data) : .empty(data)
        case .completed(let plan):
            state = .completed(
                PlanViewData(
                    plan: plan,
                    entries: summary.entries,
                    progress: summary.progress,
                    isOutsideActiveHours: false,
                    now: dateProvider.now,
                    preferences: planningPreferences
                )
            )
        case .outsideActiveHours(let plan):
            state = .outsideActiveHours(
                PlanViewData(
                    plan: plan,
                    entries: summary.entries,
                    progress: summary.progress,
                    isOutsideActiveHours: true,
                    now: dateProvider.now,
                    preferences: planningPreferences
                )
            )
        }
    }

    private func scheduleNextBoundaryRefresh() {
        boundaryTask?.cancel()
        let now = dateProvider.now
        guard let nextBoundary = HydrationDayPeriod.allCases
            .map({ $0.endDate(on: now, calendar: Calendar.autoupdatingCurrent) })
            .filter({ $0 > now })
            .min() else { return }

        boundaryTask = Task { [weak self] in
            let duration = nextBoundary.timeIntervalSince(now)
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.requestRefresh()
        }
    }

    private func performPendingRefreshIfNeeded() {
        guard hasPendingRefresh else { return }
        hasPendingRefresh = false
        requestRefresh()
    }
}
