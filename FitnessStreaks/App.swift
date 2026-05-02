import SwiftUI
import SwiftData
import BackgroundTasks
import WidgetKit
import os
#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "App")
private let refreshTaskID = "com.jackwallner.streaks.refresh"

#if canImport(WatchConnectivity)
private final class PhoneSyncService: NSObject, WCSessionDelegate {
    nonisolated(unsafe) static let shared = PhoneSyncService()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Send updated streak snapshot to paired watch immediately
    func syncToWatch() {
        guard WCSession.default.isReachable else { return }
        guard let snapshot = SnapshotStore.load() else { return }
        let dict: [String: Any] = [
            "updated": snapshot.updated.timeIntervalSince1970,
            "hero": snapshot.hero?.metric ?? "none",
            "current": snapshot.hero?.current ?? 0
        ]
        WCSession.default.sendMessage(dict, replyHandler: nil) { error in
            log.error("WC send failed: \(String(describing: error))")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error { log.error("WC activation failed: \(String(describing: error))") }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
#endif

@main
struct FitnessStreaksApp: App {
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var settings = StreakSettings.shared
    @StateObject private var store = StreakStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: DispatchQueue.main) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.handleAppRefresh(task)
        }
        Self.scheduleAppRefresh()
        #if canImport(WatchConnectivity)
        PhoneSyncService.shared.activate()
        // Listen for snapshot updates and push to watch
        NotificationCenter.default.addObserver(
            forName: .streakSnapshotUpdated,
            object: nil,
            queue: .main
        ) { _ in
            PhoneSyncService.shared.syncToWatch()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(settings.appearance.colorScheme)
                .environmentObject(healthKit)
                .environmentObject(settings)
                .environmentObject(store)
                .task {
                    await healthKit.synchronizeAuthorization()
                    // If setup was completed previously but HealthKit was never requested on
                    // this device/install, force onboarding so the user gets a clear path to
                    // trigger the Health permission prompt from an explicit tap.
                    if settings.hasCompletedSetup && !healthKit.hasRequestedAuthorization {
                        log.warning("Resetting onboarding because HealthKit has not been requested (hasCompletedSetup=true, hasRequestedAuthorization=false)")
                        settings.hasCompletedSetup = false
                    }
                    await store.load(allowCachedSnapshot: true)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task(priority: .utility) {
                        await store.refreshIfNeeded()
                    }
                }
        }
        .modelContainer(DataService.sharedModelContainer)
    }

    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        do { try BGTaskScheduler.shared.submit(request) }
        catch { log.error("schedule refresh: \(String(describing: error))") }
    }

    private static func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()
        let work = Task { @MainActor in
            await StreakStore.shared.refreshIfNeeded(force: true)
            return true
        }
        task.expirationHandler = { work.cancel() }
        Task {
            let ok = await work.value
            task.setTaskCompleted(success: ok)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var settings: StreakSettings

    var body: some View {
        Group {
            if settings.hasCompletedSetup {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
    }
}
