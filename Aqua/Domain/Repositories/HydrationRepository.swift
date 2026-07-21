import Foundation

@MainActor
protocol HydrationRepository {
    func add(_ entry: HydrationEntry) async throws
    func deleteEntry(id: UUID) async throws
    func entries(for date: Date, calendar: Calendar) async throws -> [HydrationEntry]
}
