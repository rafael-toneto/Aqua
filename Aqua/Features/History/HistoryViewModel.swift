import Combine
import Foundation

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var summariesByDay: [Date: HydrationDaySummary] = [:]
    @Published private(set) var isLoading = false
    @Published var selectedDate: Date
    @Published var errorMessage: String?

    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let dateProvider: any DateProviding
    private let calendar: Calendar

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        dateProvider: any DateProviding,
        calendar: Calendar = HistoryCalendar.calendar
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.dateProvider = dateProvider
        self.calendar = calendar
        selectedDate = calendar.startOfDay(for: dateProvider.now)
    }

    var today: Date {
        calendar.startOfDay(for: dateProvider.now)
    }

    var selectedSummary: HydrationDaySummary {
        summary(for: selectedDate)
    }

    var weekDates: [Date] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return [selectedDate]
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
    }

    var visibleMonths: [Date] {
        guard let currentMonth = calendar.dateInterval(of: .month, for: today)?.start,
              let firstMonth = calendar.date(byAdding: .month, value: -11, to: currentMonth),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) else {
            return []
        }

        var months: [Date] = []
        var month = firstMonth
        while month <= nextMonth {
            months.append(month)
            guard let followingMonth = calendar.date(byAdding: .month, value: 1, to: month) else {
                break
            }
            month = followingMonth
        }
        return months
    }

    var currentMonth: Date {
        calendar.dateInterval(of: .month, for: today)?.start ?? today
    }

    var weeklyConsumedAmount: Double {
        weekDates.reduce(0) { $0 + summary(for: $1).progress.consumedAmount }
    }

    var weeklyGoalAmount: Double {
        Double(weekDates.filter { $0 <= today }.count) * goalService.dailyGoalInMilliliters
    }

    var reachedGoalDaysThisWeek: Int {
        weekDates.filter { $0 <= today && summary(for: $0).progress.hasReachedGoal }.count
    }

    func load() async {
        isLoading = summariesByDay.isEmpty
        defer { isLoading = false }

        guard let firstMonth = visibleMonths.first,
              let lastMonth = visibleMonths.last,
              let lastDay = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: lastMonth) else {
            return
        }

        do {
            let summaries = try await trackingService.summaries(
                from: firstMonth,
                through: lastDay,
                dailyGoal: goalService.dailyGoalInMilliliters
            )
            summariesByDay = Dictionary(uniqueKeysWithValues: summaries.map {
                (calendar.startOfDay(for: $0.date), $0)
            })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard day <= today else { return }
        selectedDate = day
    }

    func summary(for date: Date) -> HydrationDaySummary {
        let day = calendar.startOfDay(for: date)
        return summariesByDay[day] ?? HydrationDaySummary(
            date: day,
            entries: [],
            progress: DailyHydrationProgress(
                consumedAmount: 0,
                dailyGoal: goalService.dailyGoalInMilliliters
            )
        )
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: today)
    }

    func isSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
}

enum HistoryCalendar {
    nonisolated static var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2
        return calendar
    }
}
