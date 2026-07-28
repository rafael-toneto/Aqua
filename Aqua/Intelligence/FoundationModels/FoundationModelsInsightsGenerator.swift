import Foundation
import FoundationModels
import OSLog

@Generable(description: "A short set of hydration behavior insights based only on supplied aggregate metrics.")
private struct FoundationGeneratedInsightsResponse {
    @Guide(
        description: "Three to five distinct, practical insights.",
        .maximumCount(5)
    )
    var insights: [FoundationGeneratedInsight]
}

@Generable(description: "One non-medical hydration behavior insight.")
private struct FoundationGeneratedInsight {
    @Guide(description: "The category for this insight.")
    var category: FoundationGeneratedInsightCategory

    @Guide(description: "A short title at most sixty characters.")
    var title: String

    @Guide(description: "A concise explanation using only facts from the supplied snapshot.")
    var description: String

    @Guide(description: "The aggregate metric that directly supports this insight.")
    var evidenceMetric: FoundationGeneratedEvidenceMetric

    @Guide(description: "A practical action that preserves the saved daily goal.")
    var action: String

    @Guide(description: "The priority for this insight.")
    var priority: FoundationGeneratedInsightPriority
}

@Generable(description: "A supported hydration insight category.")
private enum FoundationGeneratedInsightCategory {
    case consistency
    case timing
    case goalProgress
    case planAdherence
    case dayDistribution
    case recentEvolution

    var domainValue: HydrationInsightCategory {
        switch self {
        case .consistency: .consistency
        case .timing: .timing
        case .goalProgress: .goalProgress
        case .planAdherence: .planAdherence
        case .dayDistribution: .dayDistribution
        case .recentEvolution: .recentEvolution
        }
    }
}

@Generable(description: "An aggregate metric calculated and validated by the app.")
private enum FoundationGeneratedEvidenceMetric {
    case goalAchievement
    case averageDailyConsumption
    case averageEntries
    case firstEntryTime
    case lastEntryTime
    case dayDistribution
    case averageInterval
    case lateDayConcentration
    case planAdherence
    case daysWithoutEntries
    case recentTrend

    var domainValue: HydrationInsightEvidenceMetric {
        switch self {
        case .goalAchievement: .goalAchievement
        case .averageDailyConsumption: .averageDailyConsumption
        case .averageEntries: .averageEntries
        case .firstEntryTime: .firstEntryTime
        case .lastEntryTime: .lastEntryTime
        case .dayDistribution: .dayDistribution
        case .averageInterval: .averageInterval
        case .lateDayConcentration: .lateDayConcentration
        case .planAdherence: .planAdherence
        case .daysWithoutEntries: .daysWithoutEntries
        case .recentTrend: .recentTrend
        }
    }
}

@Generable(description: "The relative importance of an insight.")
private enum FoundationGeneratedInsightPriority {
    case low
    case medium
    case high

    var domainValue: HydrationInsightPriority {
        switch self {
        case .low: .low
        case .medium: .medium
        case .high: .high
        }
    }
}

struct FoundationModelsInsightsGenerator: HydrationInsightsGenerating {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "AquaFlow",
        category: "HydrationInsights"
    )

    func generateInsights(
        from snapshot: HydrationInsightsSnapshot
    ) async throws -> [HydrationInsight] {
        // Insights has its own role-specific agent and context, separate from the agent that
        // creates adaptive plans.
        let model = SystemLanguageModel.default
        guard case .available = model.availability else {
            throw HydrationInsightsGenerationError.unavailable
        }

        let session = LanguageModelSession(model: model, instructions: """
            Create hydration behavior insights using only aggregate facts supplied by the app.
            Never invent habits, events, causes, routines, or personal details.
            Never diagnose, prescribe, make a medical claim, use clinical language, or imply a
            health condition. Never change the saved daily goal, recommend exceeding it, or call
            any pattern healthy, unhealthy, optimal, or medically recommended.
            Produce three to five short, clear, non-repeating insights.
            Use only the allowed category, evidence metric, and priority values.
            If you mention a number, copy its exact value from the supplied snapshot. Never
            calculate, round, estimate, or invent a number. The app will also attach the exact
            validated evidence identified by evidenceMetric.
            For a snapshot with only one recorded day, describe only observations from that day.
            Never call a single-day observation a trend, history, habit, or recurring pattern.
            Return only the requested structured result.
            """)

        do {
            let response = try await session.respond(
                to: prompt(snapshot),
                generating: FoundationGeneratedInsightsResponse.self,
                options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 1_200)
            )

            return response.content.insights.enumerated().map { index, generated in
                let category = generated.category.domainValue
                let evidenceMetric = generated.evidenceMetric.domainValue
                let priority = generated.priority.domainValue

                return HydrationInsight(
                    id: "\(index).\(category.rawValue).\(evidenceMetric.rawValue)",
                    title: normalized(generated.title, maximumLength: 60),
                    description: normalized(generated.description, maximumLength: 260),
                    evidence: snapshot.evidence(for: evidenceMetric),
                    evidenceMetric: evidenceMetric,
                    suggestedAction: normalized(generated.action, maximumLength: 180),
                    category: category,
                    priority: priority
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as LanguageModelSession.GenerationError {
            Self.logger.error(
                "Foundation Models generation failed: \(String(describing: error), privacy: .public)"
            )
            throw HydrationInsightsGenerationError.generationFailed
        } catch {
            Self.logger.error(
                "Unexpected Insights generation failure: \(String(describing: error), privacy: .public)"
            )
            throw HydrationInsightsGenerationError.generationFailed
        }
    }

    private func normalized(_ text: String, maximumLength: Int) -> String {
        String(
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(maximumLength)
        )
    }

    private func prompt(_ snapshot: HydrationInsightsSnapshot) -> String {
        let categories = HydrationInsightCategory.allCases
            .map(\.rawValue)
            .joined(separator: ", ")
        let evidenceMetrics = HydrationInsightEvidenceMetric.allCases
            .map(\.rawValue)
            .joined(separator: ", ")
        let priorities = HydrationInsightPriority.allCases
            .map(\.rawValue)
            .joined(separator: ", ")

        return """
            Analyze this compact, validated snapshot. It contains the complete set of facts you
            may use and no individual hydration entries:
            \(snapshot.compactPrompt)

            Allowed categories: \(categories)
            Allowed evidenceMetric values: \(evidenceMetrics)
            Allowed priorities: \(priorities)

            Select evidenceMetric values that directly support each explanation. Keep the action
            practical and within the existing goal. Do not repeat a category unless the evidence
            supports a clearly different action.
            """
    }
}
