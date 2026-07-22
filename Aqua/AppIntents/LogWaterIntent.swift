import AppIntents
import Foundation

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Water"
    static let description = IntentDescription("Records an amount of water in Aqua.")
    static let openAppWhenRun = false
    static let supportedModes: IntentModes = .background

    @Parameter(
        title: "Amount",
        description: "The volume consumed in milliliters, liters, or fluid ounces.",
        defaultUnit: .milliliters,
        defaultUnitAdjustForLocale: false,
        supportsNegativeNumbers: false
    )
    var amount: Measurement<UnitVolume>?

    init() {}

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let amount else {
            throw $amount.needsValueError(
                hydrationIntentDialog(
                    "How much water did you drink? You can answer in milliliters, liters, or fluid ounces."
                )
            )
        }

        let handler = try await HydrationIntentDependencyResolver.handler()
        let message = try await handler.logWater(amount: amount)
        return .result(dialog: hydrationIntentDialog(message))
    }
}
