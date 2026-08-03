import Foundation
import SwiftData

@MainActor
final class SwiftDataHydrationRepository: HydrationRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func add(_ entry: HydrationEntry) async throws {
        guard entry.amountInMilliliters.isFinite, entry.amountInMilliliters > 0 else {
            throw HydrationError.invalidAmount
        }
        guard entry.amountInMilliliters <= HydrationLimits.maximumSingleEntryInMilliliters else {
            throw HydrationError.amountExceedsSingleEntryLimit
        }

        modelContext.insert(SwiftDataHydrationEntry(entry: entry))
        try modelContext.save()
    }

    func deleteEntry(id: UUID) async throws {
        let requestedID = id
        let predicate = #Predicate<SwiftDataHydrationEntry> { entry in
            entry.id == requestedID
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1

        guard let storedEntry = try modelContext.fetch(descriptor).first else {
            return
        }

        modelContext.delete(storedEntry)
        try modelContext.save()
    }

    func entries(for date: Date, calendar: Calendar) async throws -> [HydrationEntry] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let startOfNextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return try await entries(from: startOfDay, to: startOfNextDay)
    }

    func entries(from startDate: Date, to endDate: Date) async throws -> [HydrationEntry] {
        guard startDate < endDate else { return [] }

        let predicate = #Predicate<SwiftDataHydrationEntry> { entry in
            entry.date >= startDate && entry.date < endDate
        }
        let descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )

        return try modelContext.fetch(descriptor).map(\.domainModel)
    }
}
