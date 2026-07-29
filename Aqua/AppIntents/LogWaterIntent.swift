import AppIntents
import Foundation

enum WaterLogUnit: String, AppEnum {
    case milliliters
    case liters
    case fluidOunces

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Water Unit"

    static let caseDisplayRepresentations: [WaterLogUnit: DisplayRepresentation] = [
        .milliliters: "Milliliters (mL)",
        .liters: "Liters (L)",
        .fluidOunces: "Fluid Ounces (fl oz)"
    ]

    var foundationUnit: UnitVolume {
        switch self {
        case .milliliters:
            .milliliters
        case .liters:
            .liters
        case .fluidOunces:
            .fluidOunces
        }
    }

    func measurement(value: Double) -> Measurement<UnitVolume> {
        Measurement(value: value, unit: foundationUnit)
    }
}

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Records an amount of water in AquaFlow.")
    static let openAppWhenRun = false
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Amount",
        description: "The numeric amount of water consumed.",
        controlStyle: .field,
        inclusiveRange: (0.001, 10_000)
    )
    var amount: Double?

    @Parameter(
        title: "Unit",
        description: "The unit used for the water amount.",
        supportedValues: [.milliliters, .liters, .fluidOunces]
    )
    var unit: WaterLogUnit?

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) \(\.$unit)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let amount else {
            throw $amount.needsValueError(
                hydrationIntentDialog(
                    "How much water did you drink? Enter the numeric amount."
                )
            )
        }

        guard let unit else {
            throw $unit.needsValueError(
                hydrationIntentDialog(
                    "Which unit should AquaFlow use: milliliters, liters, or fluid ounces?"
                )
            )
        }

        let handler = try await HydrationIntentDependencyResolver.handler()
        let message = try await handler.logWater(amount: unit.measurement(value: amount))
        return .result(dialog: hydrationIntentDialog(message))
    }
}
