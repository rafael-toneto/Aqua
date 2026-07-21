import Foundation

struct HydrationEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let amountInMilliliters: Double
    let date: Date
    let source: HydrationEntrySource

    init(
        id: UUID = UUID(),
        amountInMilliliters: Double,
        date: Date,
        source: HydrationEntrySource
    ) {
        self.id = id
        self.amountInMilliliters = amountInMilliliters
        self.date = date
        self.source = source
    }
}
