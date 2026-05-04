import Foundation
import SwiftData
import os

/// Plain constant so widgets (non-MainActor) can read it.
let streaksAppGroupID = "group.com.jackwallner.streaks"

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "DataService")

@MainActor
enum DataService {
    static let appGroupID = streaksAppGroupID

    static var sharedModelContainer: ModelContainer = {
        createContainer()
    }()

    private static func createContainer() -> ModelContainer {
        let schema = Schema([DailyActivity.self])
        let url = containerURL

        // First attempt: create container normally
        do {
            let config = ModelConfiguration(
                "FitnessStreaks",
                schema: schema,
                url: url,
                cloudKitDatabase: .none
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch let error as NSError {
            // Check if this is a corruption error we can recover from
            let isCorruptionError = error.domain == "NSCocoaErrorDomain" &&
                (error.code == 259 || error.code == 256 || error.code == 257) // SQLite corruption/missing errors

            if isCorruptionError {
                log.error("DataService: Store appears corrupt (\(error.code)), attempting recovery by deleting and recreating")

                // Only delete files on actual corruption errors
                for suffix in ["", "-wal", "-shm"] {
                    let path = url.path + suffix
                    if FileManager.default.fileExists(atPath: path) {
                        do {
                            try FileManager.default.removeItem(atPath: path)
                            log.info("DataService: Deleted corrupt store file: \(path)")
                        } catch {
                            log.error("DataService: Failed to delete store file \(path): \(error)")
                        }
                    }
                }

                // Retry after deletion
                do {
                    let config = ModelConfiguration(
                        "FitnessStreaks",
                        schema: schema,
                        url: url,
                        cloudKitDatabase: .none
                    )
                    return try ModelContainer(for: schema, configurations: [config])
                } catch {
                    log.error("DataService: Failed to create container after corruption recovery: \(error)")
                }
            } else {
                log.error("DataService: Non-corruption error creating container: \(error)")
            }
        } catch {
            log.error("DataService: Unexpected error creating container: \(error)")
        }

        // Fallback: In-memory container (data loss but app continues)
        log.warning("DataService: Falling back to in-memory container - cached data will be lost")
        let inMemory = ModelConfiguration("FitnessStreaks", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [inMemory])
        } catch {
            log.error("DataService: Failed to create in-memory container: \(error)")
            // Try with different name to avoid any lock issues
            let fallback = ModelConfiguration("FitnessStreaksFallback", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [fallback])
            } catch {
                log.fault("DataService: Critical failure - cannot create any container: \(error)")
                // Absolute last resort
                let minimal = ModelConfiguration("FitnessStreaksMinimal", schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
                return try! ModelContainer(for: schema, configurations: [minimal])
            }
        }
    }

    private static var containerURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("FitnessStreaks.store")
    }
}
