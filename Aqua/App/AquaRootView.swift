import SwiftUI

struct AquaRootView: View {
    let trackingService: any HydrationTrackingServiceProtocol
    let goalService: any HydrationGoalServiceProtocol
    let dateProvider: any DateProviding

    var body: some View {
        TabView {
            TodayView(
                trackingService: trackingService,
                goalService: goalService,
                dateProvider: dateProvider
            )
            .tabItem {
                Label("Today", systemImage: "drop.fill")
            }

            SettingsView(goalService: goalService)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(.blue)
    }
}
