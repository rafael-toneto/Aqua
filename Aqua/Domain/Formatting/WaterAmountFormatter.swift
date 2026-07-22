import Foundation

enum WaterVolumeUnit: String, CaseIterable, Identifiable {
    case metric
    case fluidOunces

    static let preferenceKey = "hydration.volumeDisplayUnit"

    var id: Self { self }

    var title: String {
        switch self {
        case .metric:
            "Liters / Milliliters"
        case .fluidOunces:
            "Fluid Ounces"
        }
    }

    var symbol: String {
        switch self {
        case .metric:
            "ml"
        case .fluidOunces:
            "fl oz"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .metric:
            "liters and milliliters"
        case .fluidOunces:
            "fluid ounces"
        }
    }
}

enum WaterAmountFormatter {
    private static let millilitersPerFluidOunce = 29.5735295625

    static func string(
        from amountInMilliliters: Double,
        unit: WaterVolumeUnit = .metric
    ) -> String {
        switch unit {
        case .metric:
            if amountInMilliliters >= 1_000 {
                let liters = amountInMilliliters / 1_000
                return "\(formattedNumber(liters, maximumFractionDigits: 1)) L"
            }

            return "\(formattedNumber(amountInMilliliters, maximumFractionDigits: 0)) ml"

        case .fluidOunces:
            let fluidOunces = amountInMilliliters / millilitersPerFluidOunce
            return "\(formattedNumber(fluidOunces, maximumFractionDigits: 1)) fl oz"
        }
    }

    static func editorText(
        from amountInMilliliters: Double,
        unit: WaterVolumeUnit
    ) -> String {
        switch unit {
        case .metric:
            return formattedNumber(amountInMilliliters, maximumFractionDigits: 0)
        case .fluidOunces:
            return formattedNumber(
                amountInMilliliters / millilitersPerFluidOunce,
                maximumFractionDigits: 1
            )
        }
    }

    static func spokenString(from amountInMilliliters: Double) -> String {
        if amountInMilliliters >= 1_000 {
            let liters = amountInMilliliters / 1_000
            let number = formattedNumber(liters, maximumFractionDigits: 1)
            let unit = liters == 1 ? "liter" : "liters"
            return "\(number) \(unit)"
        }

        let number = formattedNumber(amountInMilliliters, maximumFractionDigits: 0)
        let unit = amountInMilliliters == 1 ? "milliliter" : "milliliters"
        return "\(number) \(unit)"
    }

    static func milliliters(
        fromDisplayedText text: String,
        unit: WaterVolumeUnit
    ) -> Double? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedText = trimmedText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Double(normalizedText), amount.isFinite, amount > 0 else {
            return nil
        }

        switch unit {
        case .metric:
            return amount
        case .fluidOunces:
            return amount * millilitersPerFluidOunce
        }
    }

    private static func formattedNumber(_ value: Double, maximumFractionDigits: Int) -> String {
        value.formatted(
            .number
                .grouping(.never)
                .precision(.fractionLength(0...maximumFractionDigits))
        )
    }
}
