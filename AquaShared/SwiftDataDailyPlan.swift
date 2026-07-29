import Foundation
import SwiftData

@Model
final class SwiftDataDailyPlan {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var calendarDay: Date
    var payload: Data
    var updatedAt: Date

    init(id: UUID, calendarDay: Date, payload: Data, updatedAt: Date) {
        self.id = id
        self.calendarDay = calendarDay
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
