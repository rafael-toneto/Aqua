import Foundation

@MainActor
protocol HydrationInsightsGenerating: Sendable {
    func generateInsights(
        from snapshot: HydrationInsightsSnapshot
    ) async throws -> [HydrationInsight]
}

@MainActor
protocol HydrationInsightsProviding: AnyObject {
    func insights(asOf date: Date) async throws -> HydrationInsightsReport
}
