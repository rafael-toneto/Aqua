import Foundation

enum WaterAmountFormatter {
    static func string(from amountInMilliliters: Double) -> String {
        if amountInMilliliters >= 1_000 {
            let liters = amountInMilliliters / 1_000
            return "\(liters.formatted(.number.precision(.fractionLength(0...1)))) L"
        }

        return "\(amountInMilliliters.formatted(.number.precision(.fractionLength(0)))) ml"
    }
}
