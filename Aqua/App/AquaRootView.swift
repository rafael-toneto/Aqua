import SwiftUI

struct AquaRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(
        WaterVolumeUnit.preferenceKey,
        store: AquaSharedStore.userDefaults
    ) private var waterVolumeUnitRawValue = WaterVolumeUnit.metric.rawValue
    @AppStorage(OnboardingPreferences.completionKey) private var hasCompletedOnboarding = false

    let trackingService: any HydrationTrackingServiceProtocol
    let goalService: any HydrationGoalServiceProtocol
    let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    let dateProvider: any DateProviding
    let adaptivePlanService: AdaptivePlanService
    let insightsService: any HydrationInsightsProviding
    let planningPreferencesStore: any PlanningPreferencesStoring
    let liveActivityController: any HydrationLiveActivityControlling

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                mainTabView
                    .transition(.opacity)
            } else {
                OnboardingView(
                    goalService: goalService,
                    planningPreferencesStore: planningPreferencesStore,
                    volumeUnit: waterVolumeUnit,
                    onComplete: completeOnboarding
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasCompletedOnboarding)
        .environment(\.waterVolumeUnit, waterVolumeUnit)
        .task(id: hasCompletedOnboarding) {
            guard hasCompletedOnboarding else { return }
            await liveActivityController.synchronize()
        }
        .onChange(of: scenePhase) { _, phase in
            guard hasCompletedOnboarding, phase == .active else { return }
            Task { await liveActivityController.synchronize() }
        }
        .onChange(of: waterVolumeUnitRawValue) {
            guard hasCompletedOnboarding else { return }
            Task { await liveActivityController.synchronize() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hydrationEntriesDidChange)) { _ in
            guard hasCompletedOnboarding else { return }
            Task { await liveActivityController.synchronize() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hydrationGoalDidChange)) { _ in
            guard hasCompletedOnboarding else { return }
            Task { await liveActivityController.synchronize() }
        }
    }

    private var mainTabView: some View {
        TabView {
            TodayView(
                trackingService: trackingService,
                goalService: goalService,
                quickAddAmountsService: quickAddAmountsService,
                dateProvider: dateProvider
            )
            .tabItem {
                Label("Today", systemImage: "drop.fill")
            }

            HistoryView(
                trackingService: trackingService,
                goalService: goalService,
                dateProvider: dateProvider
            )
            .tabItem {
                Label("History", systemImage: "chart.bar.fill")
            }

            InsightsView(
                insightsService: insightsService,
                dateProvider: dateProvider
            )
            .tabItem {
                Label("Insights", systemImage: "sparkles")
            }

            PlanView(
                adaptivePlanService: adaptivePlanService,
                goalService: goalService,
                trackingService: trackingService,
                dateProvider: dateProvider
            )
            .tabItem {
                Label("Plan", systemImage: "list.bullet.clipboard")
            }

            SettingsView(
                goalService: goalService,
                quickAddAmountsService: quickAddAmountsService,
                liveActivityController: liveActivityController
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AquaPalette(colorScheme: colorScheme).accent)
    }

    private var waterVolumeUnit: WaterVolumeUnit {
        WaterVolumeUnit(rawValue: waterVolumeUnitRawValue) ?? .metric
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
