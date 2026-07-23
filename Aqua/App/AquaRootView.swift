import SwiftUI

struct AquaRootView: View {
    @AppStorage(WaterVolumeUnit.preferenceKey) private var waterVolumeUnitRawValue = WaterVolumeUnit.metric.rawValue

    let trackingService: any HydrationTrackingServiceProtocol
    let goalService: any HydrationGoalServiceProtocol
    let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    let dateProvider: any DateProviding
    let adaptivePlanService: AdaptivePlanService
    let insightsService: any HydrationInsightsProviding

    var body: some View {
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
                quickAddAmountsService: quickAddAmountsService
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
        .environment(\.waterVolumeUnit, waterVolumeUnit)
    }

    private var waterVolumeUnit: WaterVolumeUnit {
        WaterVolumeUnit(rawValue: waterVolumeUnitRawValue) ?? .metric
    }
}
