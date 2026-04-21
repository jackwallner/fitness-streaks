import Foundation
import SwiftData

/// Plain constant so widgets (non-MainActor) can read it.
let streaksAppGroupID = "group.com.jackwallner.streaks"

@MainActor
enum DataService {
    static let appGroupID = streaksAppGroupID

    static var sharedModelContainer: ModelContainer = {
        let schema = Schema([DailyActivity.self])
        let url = containerURL

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // Corrupt store — nuke and retry
        print("DataService: ModelContainer failed, deleting store and retrying")
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            try? FileManager.default.removeItem(atPath: path)
        }

        if let container = makeContainer(schema: schema, url: url) {
            return container
        }

        // In-memory last resort
        let inMemory = ModelConfiguration("FitnessStreaks", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            fatalError("DataService: could not initialize in-memory container: \(error)")
        }
    }()

    private static func makeContainer(schema: Schema, url: URL) -> ModelContainer? {
        let config = ModelConfiguration(
            "FitnessStreaks",
            schema: schema,
            url: url,
            cloudKitDatabase: .none
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }

    private static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FitnessStreaks.store")
    }
}
