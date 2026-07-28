import AppIntents

struct GetHydrationProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Hydration Progress"
    static let description = IntentDescription("Checks today’s hydration progress in AquaFlow.")
    static let openAppWhenRun = false
    static let supportedModes: IntentModes = .background

    static var parameterSummary: some ParameterSummary {
        Summary("Check today’s hydration progress")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let handler = try await HydrationIntentDependencyResolver.handler()
        let message = try await handler.hydrationProgress()
        return .result(dialog: hydrationIntentDialog(message))
    }
}
