import AppIntents
import Foundation

enum HydrationIntentError: Error, Equatable, LocalizedError, CustomLocalizedStringResourceConvertible {
    case amountMustBePositive
    case invalidAmount
    case amountTooSmall
    case amountTooLarge
    case unsupportedUnit
    case saveFailed
    case progressFailed
    case dependencyInitializationFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .amountMustBePositive:
            "The water amount must be greater than zero."
        case .invalidAmount:
            "I could not understand the water amount."
        case .amountTooSmall:
            "That amount is too small to record. Please try a larger value."
        case .amountTooLarge:
            "That amount is too large for a single entry. Please try a smaller value."
        case .unsupportedUnit:
            "Aqua supports water amounts in milliliters, liters, or fluid ounces."
        case .saveFailed:
            "Aqua could not save this water entry. Please try again."
        case .progressFailed:
            "Aqua could not retrieve today’s hydration progress."
        case .dependencyInitializationFailed:
            "Aqua could not access your hydration data. Please try again."
        }
    }

    var errorDescription: String? {
        String(localized: localizedStringResource)
    }
}

@MainActor
enum HydrationIntentDependencyResolver {
    static func handler() throws -> any HydrationIntentHandling {
        switch AppDependencies.shared {
        case .success(let dependencies):
            dependencies.hydrationIntentHandler
        case .failure:
            throw HydrationIntentError.dependencyInitializationFailed
        }
    }
}

nonisolated func hydrationIntentDialog(_ message: String) -> IntentDialog {
    IntentDialog(LocalizedStringResource(stringLiteral: message))
}
