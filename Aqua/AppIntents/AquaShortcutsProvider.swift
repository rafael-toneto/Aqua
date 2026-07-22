import AppIntents

struct AquaShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogWaterIntent(),
            phrases: [
                "I just drank water with \(.applicationName)",
                "I drank water using \(.applicationName)",
                "Log water with \(.applicationName)",
                "Add water to \(.applicationName)",
                "Record water in \(.applicationName)"
            ],
            shortTitle: "Log Water",
            systemImageName: "drop.fill"
        )

        AppShortcut(
            intent: GetHydrationProgressIntent(),
            phrases: [
                "Ask \(.applicationName) how much water I have drunk today",
                "What is my hydration progress in \(.applicationName)",
                "How am I doing with water in \(.applicationName)",
                "Check my water progress in \(.applicationName)"
            ],
            shortTitle: "Hydration Progress",
            systemImageName: "chart.bar.fill"
        )

        AppShortcut(
            intent: GetRemainingWaterIntent(),
            phrases: [
                "Ask \(.applicationName) how much water I have left today",
                "How much more water do I need in \(.applicationName)",
                "Check my remaining water in \(.applicationName)",
                "What is left of my water goal in \(.applicationName)"
            ],
            shortTitle: "Remaining Water",
            systemImageName: "target"
        )
    }

    static let shortcutTileColor: ShortcutTileColor = .blue
}
