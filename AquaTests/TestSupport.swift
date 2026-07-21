import Foundation
@testable import Aqua

@MainActor
final class FakeHydrationRepository: HydrationRepository {
    var storedEntries: [HydrationEntry]

    init(entries: [HydrationEntry] = []) {
        storedEntries = entries
    }

    func add(_ entry: HydrationEntry) async throws {
        storedEntries.append(entry)
    }

    func deleteEntry(id: UUID) async throws {
        storedEntries.removeAll { $0.id == id }
    }

    func entries(for date: Date, calendar: Calendar) async throws -> [HydrationEntry] {
        storedEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    func entries(from startDate: Date, to endDate: Date) async throws -> [HydrationEntry] {
        storedEntries
            .filter { $0.date >= startDate && $0.date < endDate }
            .sorted { $0.date < $1.date }
    }
}

struct FixedDateProvider: DateProviding {
    let now: Date
}

@MainActor
final class InMemoryHydrationPreferencesStore: HydrationPreferencesStoring {
    var dailyGoalInMilliliters: Double

    init() {
        dailyGoalInMilliliters = HydrationDefaults.dailyGoalInMilliliters
    }

    init(dailyGoalInMilliliters: Double) {
        self.dailyGoalInMilliliters = dailyGoalInMilliliters
    }
}

@MainActor
func fixedCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
}
