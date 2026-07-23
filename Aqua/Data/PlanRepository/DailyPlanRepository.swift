import Foundation

@MainActor
protocol DailyPlanRepository: AnyObject {
    func plan(for calendarDay: Date) throws -> DailyHydrationPlan?
    func save(_ plan: DailyHydrationPlan) throws
}

