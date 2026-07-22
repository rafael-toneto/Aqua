import AppIntents

struct GetRemainingWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Remaining Water"
    static let description = IntentDescription("Checks how much water remains in today’s Aqua goal.")
    static let openAppWhenRun = false
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Check today’s remaining water")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let handler = try await HydrationIntentDependencyResolver.handler()
        let message = try await handler.remainingWater()
        return .result(dialog: hydrationIntentDialog(message))
    }
}
