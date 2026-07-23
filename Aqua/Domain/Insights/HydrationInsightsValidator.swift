import Foundation

struct HydrationInsightsValidator: Sendable {
    func validate(
        _ insights: [HydrationInsight],
        against snapshot: HydrationInsightsSnapshot
    ) -> Bool {
        guard (3...5).contains(insights.count),
              Set(insights.map(\.id)).count == insights.count else {
            return false
        }

        return insights.allSatisfy { insight in
            let title = insight.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = insight.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let action = insight.suggestedAction.trimmingCharacters(in: .whitespacesAndNewlines)
            let evidence = insight.evidence.trimmingCharacters(in: .whitespacesAndNewlines)
            let narrative = [title, description, action].joined(separator: " ")

            return !title.isEmpty
                && !description.isEmpty
                && !action.isEmpty
                && !evidence.isEmpty
                && title.count <= 60
                && description.count <= 260
                && action.count <= 180
                && evidence.count <= 180
                && insight.evidence == snapshot.evidence(for: insight.evidenceMetric)
                && !narrative.contains(where: \.isNumber)
                && !containsRestrictedClaim(narrative)
        }
    }

    private func containsRestrictedClaim(_ text: String) -> Bool {
        let lowered = text.lowercased()
        return [
            "diagnos", "disease", "disorder", "medical", "prescription", "treatment",
            "clinical", "symptom", "therapeutic", "doctor", "healthy", "unhealthy",
            "health condition", "kidney", "heart", "blood", "illness", "prevent",
            "cure", "dehydration", "headache", "digestion", "energy level"
        ].contains(where: lowered.contains)
    }
}
