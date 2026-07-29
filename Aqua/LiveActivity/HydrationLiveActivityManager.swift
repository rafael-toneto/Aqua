import ActivityKit
import Foundation

@MainActor
protocol HydrationLiveActivityControlling: AnyObject {
    var isEnabled: Bool { get }
    var areActivitiesAvailable: Bool { get }

    func setEnabled(_ isEnabled: Bool) async
    func synchronize() async
}

@MainActor
final class HydrationLiveActivityManager: HydrationLiveActivityControlling {
    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let dateProvider: any DateProviding
    private let calendar: Calendar

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        dateProvider: any DateProviding,
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    var isEnabled: Bool {
        AquaSharedStore.liveActivitiesEnabled
    }

    var areActivitiesAvailable: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func setEnabled(_ isEnabled: Bool) async {
        AquaSharedStore.liveActivitiesEnabled = isEnabled

        if isEnabled {
            await synchronize()
        } else {
            await endAllActivities()
        }
    }

    func synchronize() async {
        guard isEnabled else {
            await endAllActivities()
            return
        }
        guard areActivitiesAvailable else { return }

        let now = dateProvider.now
        let day = calendar.startOfDay(for: now)
        let goal = goalService.dailyGoalInMilliliters

        guard let progress = try? await trackingService.progress(for: now, dailyGoal: goal) else {
            return
        }

        let state = HydrationActivityAttributes.ContentState(
            consumedInMilliliters: progress.consumedAmount,
            goalInMilliliters: progress.dailyGoal,
            usesFluidOunces: usesFluidOunces,
            updatedAt: now
        )
        let content = activityContent(state: state, for: day)
        let activities = Activity<HydrationActivityAttributes>.activities
        let activitiesForToday = activities.filter { calendar.isDate($0.attributes.day, inSameDayAs: day) }

        for outdatedActivity in activities where !calendar.isDate(
            outdatedActivity.attributes.day,
            inSameDayAs: day
        ) {
            await outdatedActivity.end(nil, dismissalPolicy: .immediate)
        }

        if let currentActivity = activitiesForToday.first {
            await currentActivity.update(content)

            for duplicateActivity in activitiesForToday.dropFirst() {
                await duplicateActivity.end(content, dismissalPolicy: .immediate)
            }
        } else {
            _ = try? Activity.request(
                attributes: HydrationActivityAttributes(day: day),
                content: content,
                pushType: nil
            )
        }
    }

    private func endAllActivities() async {
        for activity in Activity<HydrationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func activityContent(
        state: HydrationActivityAttributes.ContentState,
        for day: Date
    ) -> ActivityContent<HydrationActivityAttributes.ContentState> {
        let staleDate = calendar.date(byAdding: .day, value: 1, to: day)
        return ActivityContent(
            state: state,
            staleDate: staleDate,
            relevanceScore: state.progress * 100
        )
    }

    private var usesFluidOunces: Bool {
        AquaSharedStore.userDefaults.string(
            forKey: AquaSharedStore.PreferenceKey.volumeDisplayUnit
        ) == WaterVolumeUnit.fluidOunces.rawValue
    }
}
