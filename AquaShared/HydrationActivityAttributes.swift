import ActivityKit
import Foundation

struct HydrationActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let consumedInMilliliters: Double
        let goalInMilliliters: Double
        let usesFluidOunces: Bool
        let updatedAt: Date

        var progress: Double {
            guard goalInMilliliters.isFinite, goalInMilliliters > 0 else { return 0 }
            return min(max(consumedInMilliliters / goalInMilliliters, 0), 1)
        }

        var percentage: Int {
            Int((progress * 100).rounded())
        }

        var remainingInMilliliters: Double {
            max(goalInMilliliters - consumedInMilliliters, 0)
        }
    }

    let day: Date
}
