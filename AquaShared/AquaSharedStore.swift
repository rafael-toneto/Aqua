import Foundation
import SwiftData

enum AquaSharedStore {
    static let appGroupIdentifier = "group.rafaeltoneto.AquaFlow"
    static let widgetKind = "AquaFlowHydrationWidget"

    enum PreferenceKey {
        static let dailyGoalInMilliliters = "hydration.dailyGoalInMilliliters"
        static let quickAddAmountsInMilliliters = "hydration.quickAddAmountsInMilliliters"
        static let volumeDisplayUnit = "hydration.volumeDisplayUnit"
        static let liveActivitiesEnabled = "hydration.liveActivitiesEnabled"
        fileprivate static let didMigrateLegacyPreferences = "shared.didMigrateLegacyPreferences"
    }

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static var liveActivitiesEnabled: Bool {
        get {
            guard userDefaults.object(forKey: PreferenceKey.liveActivitiesEnabled) != nil else {
                return true
            }
            return userDefaults.bool(forKey: PreferenceKey.liveActivitiesEnabled)
        }
        set {
            userDefaults.set(newValue, forKey: PreferenceKey.liveActivitiesEnabled)
        }
    }

    static func makeModelContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if isStoredInMemoryOnly {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                groupContainer: .identifier(appGroupIdentifier),
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(
            for: SwiftDataHydrationEntry.self, SwiftDataDailyPlan.self,
            configurations: configuration
        )
    }

    /// Moves the pre-widget SwiftData store into the App Group on the first updated launch.
    /// A shared store is never overwritten, including when a widget has already created it.
    static func migrateLegacyModelStoreIfNeeded(fileManager: FileManager = .default) throws {
        let legacyConfiguration = ModelConfiguration(
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        let sharedConfiguration = ModelConfiguration(
            groupContainer: .identifier(appGroupIdentifier),
            cloudKitDatabase: .none
        )
        let legacyStoreURL = legacyConfiguration.url
        let sharedStoreURL = sharedConfiguration.url

        guard legacyStoreURL != sharedStoreURL,
              fileManager.fileExists(atPath: legacyStoreURL.path),
              !fileManager.fileExists(atPath: sharedStoreURL.path) else {
            return
        }

        try fileManager.createDirectory(
            at: sharedStoreURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let suffixes = ["", "-wal", "-shm"]
        var copiedURLs: [URL] = []

        do {
            for suffix in suffixes {
                let sourceURL = URL(fileURLWithPath: legacyStoreURL.path + suffix)
                guard fileManager.fileExists(atPath: sourceURL.path) else { continue }

                let destinationURL = URL(fileURLWithPath: sharedStoreURL.path + suffix)
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                copiedURLs.append(destinationURL)
            }
        } catch {
            for copiedURL in copiedURLs {
                try? fileManager.removeItem(at: copiedURL)
            }
            throw error
        }
    }

    /// Copies preferences written by versions released before the widget used an App Group.
    /// The migration is intentionally idempotent and leaves the legacy values untouched.
    static func migrateLegacyPreferencesIfNeeded(from legacyDefaults: UserDefaults = .standard) {
        guard !userDefaults.bool(forKey: PreferenceKey.didMigrateLegacyPreferences) else { return }

        let keys = [
            PreferenceKey.dailyGoalInMilliliters,
            PreferenceKey.quickAddAmountsInMilliliters,
            PreferenceKey.volumeDisplayUnit,
            PreferenceKey.liveActivitiesEnabled
        ]

        for key in keys where userDefaults.object(forKey: key) == nil {
            guard let value = legacyDefaults.object(forKey: key) else { continue }
            userDefaults.set(value, forKey: key)
        }

        userDefaults.set(true, forKey: PreferenceKey.didMigrateLegacyPreferences)
    }
}
