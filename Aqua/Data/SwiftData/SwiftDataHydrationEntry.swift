import Foundation
import SwiftData

@Model
final class SwiftDataHydrationEntry {
    @Attribute(.unique) var id: UUID
    var amountInMilliliters: Double
    var date: Date
    var sourceRawValue: String
    var planMomentID: UUID?
    var planRevision: Int?

    init(
        id: UUID,
        amountInMilliliters: Double,
        date: Date,
        sourceRawValue: String,
        planMomentID: UUID? = nil,
        planRevision: Int? = nil
    ) {
        self.id = id
        self.amountInMilliliters = amountInMilliliters
        self.date = date
        self.sourceRawValue = sourceRawValue
        self.planMomentID = planMomentID
        self.planRevision = planRevision
    }

    convenience init(entry: HydrationEntry) {
        self.init(
            id: entry.id,
            amountInMilliliters: entry.amountInMilliliters,
            date: entry.date,
            sourceRawValue: entry.source.rawValue,
            planMomentID: entry.planMomentID,
            planRevision: entry.planRevision
        )
    }

    var domainModel: HydrationEntry {
        HydrationEntry(
            id: id,
            amountInMilliliters: amountInMilliliters,
            date: date,
            source: HydrationEntrySource(rawValue: sourceRawValue) ?? .manual,
            planMomentID: planMomentID,
            planRevision: planRevision
        )
    }
}
