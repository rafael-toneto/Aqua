import ActivityKit
import Foundation

@MainActor
enum HydrationLiveActivityCoordinator {
    static func synchronize(
        consumedInMilliliters: Double,
        goalInMilliliters: Double,
        usesFluidOunces: Bool,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) async {
        guard AquaSharedStore.liveActivitiesEnabled,
              ActivityAuthorizationInfo().areActivitiesEnabled,
              goalInMilliliters.isFinite,
              goalInMilliliters > 0 else {
            return
        }

        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 1, to: tomorrow) else {
            return
        }

        let safeConsumed = consumedInMilliliters.isFinite
            ? max(consumedInMilliliters, 0)
            : 0
        let reachedGoal = safeConsumed >= goalInMilliliters

        if reachedGoal {
            // Reaching the goal is terminal for the current day. Remember it so
            // deleting an entry or raising the goal cannot reopen the activity.
            AquaSharedStore.suppressLiveActivity(for: today, calendar: calendar)
        }

        let activities = Activity<HydrationActivityAttributes>.activities
        let activitiesForToday = activities.filter {
            calendar.isDate($0.attributes.day, inSameDayAs: today)
        }
        let activitiesForTomorrow = activities.filter {
            calendar.isDate($0.attributes.day, inSameDayAs: tomorrow)
        }

        for activity in activities where
            !calendar.isDate(activity.attributes.day, inSameDayAs: today)
            && !calendar.isDate(activity.attributes.day, inSameDayAs: tomorrow) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        let todayState = makeState(
            consumedInMilliliters: safeConsumed,
            goalInMilliliters: goalInMilliliters,
            usesFluidOunces: usesFluidOunces,
            updatedAt: now
        )
        let todayContent = ActivityContent(
            state: todayState,
            staleDate: tomorrow,
            relevanceScore: todayState.progress * 100
        )
        let isTodaySuppressed = reachedGoal || AquaSharedStore.isLiveActivitySuppressed(
            for: today,
            calendar: calendar
        )

        if isTodaySuppressed {
            for activity in activitiesForToday {
                await activity.end(todayContent, dismissalPolicy: .immediate)
            }
        } else if let currentActivity = activitiesForToday.first {
            await currentActivity.update(todayContent)

            for duplicateActivity in activitiesForToday.dropFirst() {
                await duplicateActivity.end(todayContent, dismissalPolicy: .immediate)
            }
        } else {
            _ = try? Activity.request(
                attributes: HydrationActivityAttributes(day: today),
                content: todayContent,
                pushType: nil
            )
        }

        let tomorrowState = makeState(
            consumedInMilliliters: 0,
            goalInMilliliters: goalInMilliliters,
            usesFluidOunces: usesFluidOunces,
            updatedAt: tomorrow
        )
        let tomorrowContent = ActivityContent(
            state: tomorrowState,
            staleDate: dayAfterTomorrow,
            // Make the freshly started day the activity the system prioritizes
            // over yesterday's content at the day boundary.
            relevanceScore: 100
        )

        if let scheduledActivity = activitiesForTomorrow.first {
            await scheduledActivity.update(tomorrowContent)

            for duplicateActivity in activitiesForTomorrow.dropFirst() {
                await duplicateActivity.end(tomorrowContent, dismissalPolicy: .immediate)
            }
        } else {
            // iOS starts scheduled activities even when the app isn't running.
            _ = try? Activity.request(
                attributes: HydrationActivityAttributes(day: tomorrow),
                content: tomorrowContent,
                pushType: nil,
                style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: "A new hydration day has started",
                    body: "Your daily water progress is ready to track.",
                    sound: .default
                ),
                start: tomorrow
            )
        }
    }

    private static func makeState(
        consumedInMilliliters: Double,
        goalInMilliliters: Double,
        usesFluidOunces: Bool,
        updatedAt: Date
    ) -> HydrationActivityAttributes.ContentState {
        HydrationActivityAttributes.ContentState(
            consumedInMilliliters: consumedInMilliliters,
            goalInMilliliters: goalInMilliliters,
            usesFluidOunces: usesFluidOunces,
            updatedAt: updatedAt
        )
    }
}
