import Foundation

struct HydrationInsightsValidator: Sendable {
    func validInsights(
        from insights: [HydrationInsight],
        against snapshot: HydrationInsightsSnapshot
    ) -> [HydrationInsight] {
        var seenIDs: Set<String> = []

        return insights.prefix(5).filter { insight in
            seenIDs.insert(insight.id).inserted
                && validate(insight, against: snapshot)
        }
    }

    func validate(
        _ insights: [HydrationInsight],
        against snapshot: HydrationInsightsSnapshot
    ) -> Bool {
        !insights.isEmpty
            && insights.count <= 5
            && validInsights(from: insights, against: snapshot).count == insights.count
    }

    private func validate(
        _ insight: HydrationInsight,
        against snapshot: HydrationInsightsSnapshot
    ) -> Bool {
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
            && numericClaimsAreSupported(in: narrative, by: snapshot)
            && !containsRestrictedClaim(narrative)
    }

    private func numericClaimsAreSupported(
        in narrative: String,
        by snapshot: HydrationInsightsSnapshot
    ) -> Bool {
        let claimedNumbers = numericTokens(in: narrative)
        guard !claimedNumbers.isEmpty else { return true }

        let evidence = HydrationInsightEvidenceMetric.allCases
            .map(snapshot.evidence(for:))
            .joined(separator: "\n")
        let suppliedNumbers = numericTokens(in: snapshot.compactPrompt + "\n" + evidence)

        return claimedNumbers.isSubset(of: suppliedNumbers)
    }

    private func numericTokens(in text: String) -> Set<String> {
        Set(text.matches(of: /\d+(?:\.\d+)?/).map { String($0.output) })
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
