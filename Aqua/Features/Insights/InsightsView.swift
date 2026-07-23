import SwiftUI

struct InsightsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.waterVolumeUnit) private var waterVolumeUnit
    @StateObject private var viewModel: InsightsViewModel
    @State private var isVisible = false

    init(
        insightsService: any HydrationInsightsProviding,
        dateProvider: any DateProviding
    ) {
        _viewModel = StateObject(
            wrappedValue: InsightsViewModel(
                service: insightsService,
                dateProvider: dateProvider
            )
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .loading:
                    loadingState
                case .failed(let message):
                    failedState(message)
                case .empty(let report):
                    emptyState(report)
                case .loaded(let report):
                    loadedContent(report)
                }
            }
            .navigationTitle("Insights")
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear { isVisible = true }
            .onDisappear {
                isVisible = false
                viewModel.cancel()
            }
            .task {
                await viewModel.refresh(
                    displaysLoading: viewModel.state.report == nil
                )
            }
            .onChange(of: scenePhase) { _, phase in
                guard isVisible, phase == .active else { return }
                viewModel.requestRefresh()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationEntriesDidChange)) { _ in
                refreshAfterNotification()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationGoalDidChange)) { _ in
                refreshAfterNotification()
            }
            .onReceive(NotificationCenter.default.publisher(for: .hydrationPlanDidChange)) { _ in
                refreshAfterNotification()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: AquaSpacing.medium) {
            ProgressView()
                .controlSize(.large)
            Text("Analyzing your hydration history…")
                .font(.headline)
            Text("Aqua’s on-device Insights agent is reviewing your saved hydration data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(AquaSpacing.extraLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Insights Unavailable", systemImage: "exclamationmark.triangle.fill")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                viewModel.requestRefresh(displaysLoading: true)
            }
        }
    }

    private func emptyState(_ report: HydrationInsightsReport) -> some View {
        ScrollView {
            ContentUnavailableView {
                Label("Not Enough History Yet", systemImage: "sparkles")
            } description: {
                Text(
                    "Add hydration entries on a few more days. Insights use a \(report.snapshot.analyzedDayCount)-day window and never invent missing patterns."
                )
                Text("\(report.snapshot.daysWithEntries) recorded days are currently available.")
            }
            .padding(.top, AquaSpacing.extraLarge)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func loadedContent(_ report: HydrationInsightsReport) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AquaSpacing.large) {
                VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                    Text("Your Recent Pattern")
                        .font(.title.bold())
                    Text(
                        "Insights created from the last \(report.snapshot.analyzedDayCount) days of data saved in Aqua."
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                summaryCard(report.snapshot)

                agentCard

                VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                    Text("Recommended next steps")
                        .font(.headline)

                    ForEach(report.insights) { insight in
                        InsightCardView(insight: insight)
                    }
                }

                Label {
                    Text(
                        "Insights use only your saved goal and hydration history. Processing stays on device and is not medical guidance."
                    )
                    .font(.footnote)
                } icon: {
                    Image(systemName: "lock.shield.fill")
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, AquaSpacing.extraSmall)
            }
            .padding(.horizontal, AquaSpacing.medium)
            .padding(.bottom, AquaSpacing.extraLarge)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func summaryCard(_ snapshot: HydrationInsightsSnapshot) -> some View {
        AquaCard {
            VStack(alignment: .leading, spacing: AquaSpacing.medium) {
                Label(
                    "\(snapshot.analyzedDayCount)-day summary",
                    systemImage: "calendar.badge.clock"
                )
                    .font(.headline)
                    .foregroundStyle(.blue)

                HStack(spacing: 0) {
                    summaryMetric(
                        title: "Days",
                        value: "\(snapshot.analyzedDayCount)"
                    )
                    Divider().frame(height: 48)
                    summaryMetric(
                        title: "Goal days",
                        value: "\(Int(snapshot.goalAchievementPercentage.rounded()))%"
                    )
                    Divider().frame(height: 48)
                    summaryMetric(
                        title: "Daily average",
                        value: WaterAmountFormatter.string(
                            from: snapshot.averageDailyConsumptionMilliliters,
                            unit: waterVolumeUnit
                        )
                    )
                }

                Divider()

                Label(trendText(snapshot), systemImage: trendIcon(snapshot))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(snapshot.recentTrendPercentage >= 0 ? .green : .orange)
            }
        }
    }

    private var agentCard: some View {
        AquaCard {
            Label {
                VStack(alignment: .leading, spacing: AquaSpacing.extraSmall) {
                    Text("Foundation Models Insights agent")
                        .font(.headline)
                    Text(
                        "This is a dedicated on-device agent, separate from the one that creates your adaptive plan."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.indigo)
            }
        }
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(spacing: AquaSpacing.extraSmall) {
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func trendText(_ snapshot: HydrationInsightsSnapshot) -> String {
        let value = Int(abs(snapshot.recentTrendPercentage).rounded())
        if snapshot.recentTrendPercentage > 0 {
            return "Recent average is up by \(value)% of your daily goal"
        }
        if snapshot.recentTrendPercentage < 0 {
            return "Recent average is down by \(value)% of your daily goal"
        }
        return "Recent average is steady"
    }

    private func trendIcon(_ snapshot: HydrationInsightsSnapshot) -> String {
        if snapshot.recentTrendPercentage > 0 { return "arrow.up.right" }
        if snapshot.recentTrendPercentage < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private func refreshAfterNotification() {
        guard isVisible else { return }
        viewModel.requestRefresh(debounce: true)
    }
}
