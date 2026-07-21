import SwiftUI

struct AquaRootView: View {
    let trackingService: any HydrationTrackingServiceProtocol
    let goalService: any HydrationGoalServiceProtocol
    let quickAddAmountsService: any QuickAddAmountsServiceProtocol
    let dateProvider: any DateProviding

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

            SettingsView(
                goalService: goalService,
                quickAddAmountsService: quickAddAmountsService
            )
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
