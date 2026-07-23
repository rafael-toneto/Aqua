import Foundation

enum HydrationInsightCategory: String, CaseIterable, Codable, Sendable {
    case consistency
    case timing
    case goalProgress
    case planAdherence
    case dayDistribution
    case recentEvolution
}

enum HydrationInsightPriority: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high
}

enum HydrationInsightEvidenceMetric: String, CaseIterable, Codable, Sendable {
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
}

struct HydrationInsight: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let evidence: String
    let evidenceMetric: HydrationInsightEvidenceMetric
    let suggestedAction: String
    let category: HydrationInsightCategory
    let priority: HydrationInsightPriority
}

struct HydrationInsightsReport: Equatable, Sendable {
    let snapshot: HydrationInsightsSnapshot
    let insights: [HydrationInsight]
}

enum HydrationInsightsGenerationError: LocalizedError, Equatable {
    case unavailable
    case invalidResponse
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Intelligence is not available on this device right now."
        case .invalidResponse:
            "The Insights agent could not create a reliable result from the saved data."
        case .generationFailed:
            "The Insights agent could not finish the analysis. Please try again."
        }
    }
}
