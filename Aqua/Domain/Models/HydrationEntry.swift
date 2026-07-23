import Foundation

struct HydrationEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let amountInMilliliters: Double
    let date: Date
    let source: HydrationEntrySource
    let planMomentID: UUID?
    let planRevision: Int?

    init(
        id: UUID = UUID(),
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource,
        planMomentID: UUID? = nil,
        planRevision: Int? = nil
    ) {
        self.id = id
        self.amountInMilliliters = amountInMilliliters
        self.date = date
        self.source = source
        self.planMomentID = planMomentID
        self.planRevision = planRevision
    }
}
