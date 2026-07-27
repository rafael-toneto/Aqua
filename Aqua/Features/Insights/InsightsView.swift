import SwiftUI

struct InsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    pageHeader
                        .padding(.bottom, 20)

                    stateContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, AquaSpacing.extraLarge)
                .frame(maxWidth: 640, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .background(palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await viewModel.refresh() }
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
        .tint(palette.accent)
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your hydration")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(palette.secondary)

            Text("Insights")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(palette.primary)

            Divider()
                .overlay(palette.divider)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var stateContent: some View {
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

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
                .tint(palette.accent)

            Text("Analyzing your hydration history…")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text("Aqua’s on-device Insights agent is reviewing your saved hydration data.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .insightsCard(palette: palette, cornerRadius: 20)
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 27, weight: .light))
                .foregroundStyle(palette.warning)
                .frame(width: 54, height: 54)
                .background(palette.warning.opacity(0.11), in: Circle())

            Text("Insights Unavailable")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                viewModel.requestRefresh(displaysLoading: true)
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(palette.accent)
            .padding(.horizontal, 20)
            .frame(minHeight: 42)
            .background(palette.accent.opacity(0.1), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(palette.accent.opacity(0.3), lineWidth: 1)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .insightsCard(palette: palette, cornerRadius: 20)
    }

    private func emptyState(_ report: HydrationInsightsReport) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(palette.accent)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [palette.accent.opacity(0.22), palette.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay {
                    Circle()
                        .stroke(palette.accent.opacity(0.24), lineWidth: 1)
                }

            Text("Not Enough History Yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.primary)

            Text(
                "Add at least one hydration entry. Insights use a \(report.snapshot.analyzedDayCount)-day window and never invent missing observations."
            )
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(.center)

            Text("\(report.snapshot.daysWithEntries) recorded days are currently available.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(palette.accent)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(palette.accent.opacity(0.1), in: Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320)
        .insightsCard(palette: palette, cornerRadius: 20)
    }

    private func loadedContent(_ report: HydrationInsightsReport) -> some View {
        LazyVStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Recent Pattern")
                summaryCard(report.snapshot)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    sectionLabel("Recommended Next Steps")

                    Spacer(minLength: 12)

                    Text(insightCountText(report.insights.count))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(palette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(palette.accent.opacity(0.1), in: Capsule())
                }

                ForEach(report.insights) { insight in
                    InsightCardView(insight: insight)
                }
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.secondary)
                    .accessibilityHidden(true)

                Text(
                    "Insights use only your saved goal and hydration history. Processing stays on device and is not medical guidance."
                )
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AquaSpacing.extraSmall)
            .padding(.top, 2)
            .accessibilityElement(children: .combine)
        }
    }

    private func summaryCard(_ snapshot: HydrationInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 11) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(palette.accent)
                    .frame(width: 36, height: 36)
                    .background(palette.accent.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your recent pattern")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(palette.primary)

                    Text("Created only from hydration saved in Aqua")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(palette.secondary)
                }

                Spacer(minLength: 8)

                Text("\(snapshot.analyzedDayCount) DAYS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.65)
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(palette.accent.opacity(0.1), in: Capsule())
            }

            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(
                        WaterAmountFormatter.string(
                            from: snapshot.averageDailyConsumptionMilliliters,
                            unit: waterVolumeUnit
                        )
                    )
                    .font(.system(size: 34, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .contentTransition(.numericText())

                    Text("daily average")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(palette.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                goalDaysRing(snapshot)
                    .frame(width: 102, height: 102)
            }

            HStack(spacing: 8) {
                summaryMetric(
                    title: "Recorded",
                    value: "\(snapshot.daysWithEntries)/\(snapshot.analyzedDayCount)"
                )
                summaryMetric(
                    title: "Entries",
                    value: "\(snapshot.totalEntryCount)"
                )
                summaryMetric(
                    title: "Daily goal",
                    value: WaterAmountFormatter.string(
                        from: snapshot.dailyGoalMilliliters,
                        unit: waterVolumeUnit
                    )
                )
            }

            Divider()
                .overlay(palette.divider)

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: trendIcon(snapshot))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(trendColor(snapshot))
                    .frame(width: 26, height: 26)
                    .background(trendColor(snapshot).opacity(0.11), in: Circle())

                Text(trendText(snapshot))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(trendColor(snapshot))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .insightsCard(palette: palette, cornerRadius: 20)
        .accessibilityElement(children: .contain)
    }

    private func goalDaysRing(_ snapshot: HydrationInsightsSnapshot) -> some View {
        let normalizedProgress = min(max(snapshot.goalAchievementPercentage / 100, 0), 1)

        return ZStack {
            Circle()
                .stroke(palette.meterTrack, lineWidth: 9)

            if normalizedProgress > 0 {
                Circle()
                    .trim(from: 0, to: normalizedProgress)
                    .stroke(
                        AngularGradient(
                            colors: [
                                palette.success.opacity(0.7),
                                palette.success,
                                palette.accent
                            ],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 3) {
                Image(systemName: normalizedProgress >= 1 ? "checkmark" : "target")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(normalizedProgress >= 1 ? palette.success : palette.accent)

                Text("\(Int(snapshot.goalAchievementPercentage.rounded()))%")
                    .font(.system(size: 18, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primary)

                Text("goal days")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(palette.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Days reaching the hydration goal")
        .accessibilityValue("\(Int(snapshot.goalAchievementPercentage.rounded())) percent")
    }

    private func summaryMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(palette.secondary)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(
            palette.background.opacity(colorScheme == .dark ? 0.7 : 0.58),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1.25)
            .foregroundStyle(palette.secondary)
    }

    private func insightCountText(_ count: Int) -> String {
        count == 1 ? "1 insight" : "\(count) insights"
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

    private func trendColor(_ snapshot: HydrationInsightsSnapshot) -> Color {
        if snapshot.recentTrendPercentage > 0 { return palette.success }
        if snapshot.recentTrendPercentage < 0 { return palette.warning }
        return palette.secondary
    }

    private var palette: InsightsPalette {
        InsightsPalette(colorScheme: colorScheme)
    }

    private func refreshAfterNotification() {
        guard isVisible else { return }
        viewModel.requestRefresh(debounce: true)
    }
}

struct InsightsPalette {
    let background: Color
    let controlBackground: Color
    let meterTrack: Color
    let primary: Color
    let secondary: Color
    let divider: Color
    let accent: Color
    let success: Color
    let warning: Color

    init(colorScheme: ColorScheme) {
        if colorScheme == .dark {
            background = Color(red: 0.025, green: 0.075, blue: 0.12)
            controlBackground = Color(red: 0.035, green: 0.12, blue: 0.18)
            meterTrack = Color(red: 0.045, green: 0.12, blue: 0.20)
            primary = Color(red: 0.81, green: 0.91, blue: 0.96)
            secondary = Color(red: 0.30, green: 0.55, blue: 0.68)
            divider = Color(red: 0.10, green: 0.25, blue: 0.34)
            accent = Color(red: 0.05, green: 0.78, blue: 0.94)
            success = Color(red: 0.30, green: 0.82, blue: 0.58)
            warning = Color(red: 0.96, green: 0.66, blue: 0.28)
        } else {
            background = Color(red: 0.95, green: 0.98, blue: 0.99)
            controlBackground = Color.white.opacity(0.82)
            meterTrack = Color(red: 0.86, green: 0.92, blue: 0.95)
            primary = Color(red: 0.05, green: 0.16, blue: 0.22)
            secondary = Color(red: 0.27, green: 0.47, blue: 0.57)
            divider = Color(red: 0.76, green: 0.86, blue: 0.90)
            accent = Color(red: 0.00, green: 0.56, blue: 0.76)
            success = Color(red: 0.08, green: 0.58, blue: 0.36)
            warning = Color(red: 0.76, green: 0.42, blue: 0.06)
        }
    }
}

private struct InsightsCardModifier: ViewModifier {
    let palette: InsightsPalette
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                palette.controlBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.divider.opacity(0.8), lineWidth: 1)
            }
    }
}

extension View {
    func insightsCard(
        palette: InsightsPalette,
        cornerRadius: CGFloat
    ) -> some View {
        modifier(InsightsCardModifier(palette: palette, cornerRadius: cornerRadius))
    }
}
