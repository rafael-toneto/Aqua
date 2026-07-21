import Foundation
import SwiftData

@Model
final class SwiftDataHydrationEntry {
    @Attribute(.unique) var id: UUID
    var amountInMilliliters: Double
    var date: Date
    var sourceRawValue: String

    init(
        id: UUID,
        amountInMilliliters: Double,
        date: Date,
        sourceRawValue: String
    ) {
        self.id = id
        self.amountInMilliliters = amountInMilliliters
        self.date = date
        self.sourceRawValue = sourceRawValue
    }

    convenience init(entry: HydrationEntry) {
        self.init(
            id: entry.id,
            amountInMilliliters: entry.amountInMilliliters,
            date: entry.date,
            sourceRawValue: entry.source.rawValue
        )
    }

    var domainModel: HydrationEntry {
        HydrationEntry(
            id: id,
            amountInMilliliters: amountInMilliliters,
            date: date,
            source: HydrationEntrySource(rawValue: sourceRawValue) ?? .manual
        )
    }
}
