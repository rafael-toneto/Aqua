import Foundation
import FoundationModels

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
    @Guide(description: "One category value explicitly allowed by the prompt.")
    var category: String

    @Guide(description: "A short title without digits.")
    var title: String

    @Guide(description: "A concise explanation without digits or unsupported facts.")
    var description: String

    @Guide(description: "One evidence metric key explicitly allowed by the prompt.")
    var evidenceMetric: String

    @Guide(description: "A practical action without digits that preserves the saved daily goal.")
    var action: String

    @Guide(description: "One priority value explicitly allowed by the prompt.")
    var priority: String
}

struct FoundationModelsInsightsGenerator: HydrationInsightsGenerating {
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
            Put no digits in titles, descriptions, or actions. The app will attach the exact
            validated numeric evidence identified by evidenceMetric.
            If the facts are insufficient, do not infer a pattern.
            Return only the requested structured result.
            """)

        let response = try await session.respond(
            to: prompt(snapshot),
            generating: FoundationGeneratedInsightsResponse.self,
            options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 1_400)
        )

        return try response.content.insights.map { generated in
            guard let category = HydrationInsightCategory(rawValue: generated.category),
                  let evidenceMetric = HydrationInsightEvidenceMetric(
                      rawValue: generated.evidenceMetric
                  ),
                  let priority = HydrationInsightPriority(rawValue: generated.priority) else {
                throw HydrationInsightsGenerationError.invalidResponse
            }
            return HydrationInsight(
                id: "\(category.rawValue).\(evidenceMetric.rawValue)",
                title: generated.title,
                description: generated.description,
                evidence: snapshot.evidence(for: evidenceMetric),
                evidenceMetric: evidenceMetric,
                suggestedAction: generated.action,
                category: category,
                priority: priority
            )
        }
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
