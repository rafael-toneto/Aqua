import Foundation

extension SwiftDataHydrationEntry {
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
