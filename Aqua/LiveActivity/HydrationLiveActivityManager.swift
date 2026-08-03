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
        let goal = goalService.dailyGoalInMilliliters

        guard let progress = try? await trackingService.progress(for: now, dailyGoal: goal) else {
            return
        }

        await HydrationLiveActivityCoordinator.synchronize(
            consumedInMilliliters: progress.consumedAmount,
            goalInMilliliters: progress.dailyGoal,
            usesFluidOunces: usesFluidOunces,
            now: now,
            calendar: calendar
        )
    }

    private func endAllActivities() async {
        for activity in Activity<HydrationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private var usesFluidOunces: Bool {
        AquaSharedStore.userDefaults.string(
            forKey: AquaSharedStore.PreferenceKey.volumeDisplayUnit
        ) == WaterVolumeUnit.fluidOunces.rawValue
    }
}
