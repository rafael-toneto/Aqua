import Foundation
import SwiftData

@MainActor
final class SwiftDataDailyPlanRepository: DailyPlanRepository {
    private let modelContext: ModelContext
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    nonisolated deinit {}

    func plan(for calendarDay: Date) throws -> DailyHydrationPlan? {
        let requestedDay = calendarDay
        let predicate = #Predicate<SwiftDataDailyPlan> { storedPlan in
            storedPlan.calendarDay == requestedDay
        }
        var descriptor = FetchDescriptor(
            predicate: predicate,
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let storedPlan = try modelContext.fetch(descriptor).first else { return nil }
        return try decoder.decode(DailyHydrationPlan.self, from: storedPlan.payload)
    }

    func save(_ plan: DailyHydrationPlan) throws {
        let requestedDay = plan.calendarDay
        let predicate = #Predicate<SwiftDataDailyPlan> { storedPlan in
            storedPlan.calendarDay == requestedDay
        }
        var descriptor = FetchDescriptor(predicate: predicate)
        descriptor.fetchLimit = 1
        let payload = try encoder.encode(plan)

        if let storedPlan = try modelContext.fetch(descriptor).first {
            storedPlan.id = plan.id
            storedPlan.payload = payload
            storedPlan.updatedAt = plan.updatedAt
        } else {
            modelContext.insert(
                SwiftDataDailyPlan(
                    id: plan.id,
                    calendarDay: plan.calendarDay,
                    payload: payload,
                    updatedAt: plan.updatedAt
                )
            )
        }
        try modelContext.save()
    }
}
