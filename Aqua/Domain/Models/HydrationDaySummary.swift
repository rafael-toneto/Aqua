import Foundation

struct HydrationDaySummary: Equatable, Sendable {
    let date: Date
    let entries: [HydrationEntry]
    let progress: DailyHydrationProgress
}
