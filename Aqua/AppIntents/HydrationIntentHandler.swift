import Foundation

@MainActor
protocol HydrationIntentHandling {
    func logWater(amount: Measurement<UnitVolume>) async throws -> String
    func hydrationProgress() async throws -> String
    func remainingWater() async throws -> String
}

@MainActor
final class HydrationIntentHandler: HydrationIntentHandling {
    static let maximumSingleEntryInMilliliters = 10_000.0

    private let trackingService: any HydrationTrackingServiceProtocol
    private let goalService: any HydrationGoalServiceProtocol
    private let dateProvider: any DateProviding

    init(
        trackingService: any HydrationTrackingServiceProtocol,
        goalService: any HydrationGoalServiceProtocol,
        dateProvider: any DateProviding
    ) {
        self.trackingService = trackingService
        self.goalService = goalService
        self.dateProvider = dateProvider
    }

    func logWater(amount: Measurement<UnitVolume>) async throws -> String {
        let amountInMilliliters = try Self.convertToMilliliters(amount)
        let date = dateProvider.now

        do {
            try await trackingService.addWater(
                amountInMilliliters: amountInMilliliters,
                date: date,
                source: .appIntent
            )
        } catch {
            throw HydrationIntentError.saveFailed
        }

        let progress = try await currentProgress(for: date)
        let addedAmount = WaterAmountFormatter.spokenString(from: amountInMilliliters)

        if progress.consumedAmount > progress.dailyGoal {
            return "\(addedAmount) added. You have consumed "
                + "\(WaterAmountFormatter.spokenString(from: progress.consumedAmount)) today, "
                + "exceeding your \(WaterAmountFormatter.spokenString(from: progress.dailyGoal)) goal."
        }

        if progress.hasReachedGoal {
            return "\(addedAmount) added. You have reached today’s hydration goal."
        }

        return "\(addedAmount) added. You have consumed "
            + "\(WaterAmountFormatter.spokenString(from: progress.consumedAmount)) of your "
            + "\(WaterAmountFormatter.spokenString(from: progress.dailyGoal)) goal today."
    }

    func hydrationProgress() async throws -> String {
        let progress = try await currentProgress(for: dateProvider.now)

        if progress.consumedAmount == 0 {
            return "You have not logged any water today. Your daily goal is "
                + "\(WaterAmountFormatter.spokenString(from: progress.dailyGoal))."
        }

        if progress.consumedAmount > progress.dailyGoal {
            return "You have consumed \(WaterAmountFormatter.spokenString(from: progress.consumedAmount)) "
                + "today, exceeding your \(WaterAmountFormatter.spokenString(from: progress.dailyGoal)) goal."
        }

        let percentage = Int(progress.completionPercentage.rounded())
        return "You have consumed \(WaterAmountFormatter.spokenString(from: progress.consumedAmount)) "
            + "of your \(WaterAmountFormatter.spokenString(from: progress.dailyGoal)) goal today. "
            + "That is \(percentage) percent."
    }

    func remainingWater() async throws -> String {
        let progress = try await currentProgress(for: dateProvider.now)

        if progress.consumedAmount > progress.dailyGoal {
            let exceededAmount = progress.consumedAmount - progress.dailyGoal
            return "You have already exceeded today’s hydration goal by "
                + "\(WaterAmountFormatter.spokenString(from: exceededAmount))."
        }

        if progress.hasReachedGoal {
            return "You have reached today’s hydration goal."
        }

        return "You have \(WaterAmountFormatter.spokenString(from: progress.remainingAmount)) remaining today."
    }

    static func convertToMilliliters(_ amount: Measurement<UnitVolume>) throws -> Double {
        guard amount.value.isFinite else {
            throw HydrationIntentError.invalidAmount
        }
        guard amount.value > 0 else {
            throw HydrationIntentError.amountMustBePositive
        }

        let convertedAmount = amount.converted(to: .milliliters).value
        guard convertedAmount.isFinite else {
            throw HydrationIntentError.invalidAmount
        }
        guard convertedAmount <= maximumSingleEntryInMilliliters else {
            throw HydrationIntentError.amountTooLarge
        }

        // AquaFlow stores whole milliliters for intent entries. Half values round away from zero.
        let roundedAmount = convertedAmount.rounded(.toNearestOrAwayFromZero)
        guard roundedAmount >= 1 else {
            throw HydrationIntentError.amountTooSmall
        }
        return roundedAmount
    }

    private func currentProgress(for date: Date) async throws -> DailyHydrationProgress {
        do {
            return try await trackingService.progress(
                for: date,
                dailyGoal: goalService.dailyGoalInMilliliters
            )
        } catch {
            throw HydrationIntentError.progressFailed
        }
    }
}
