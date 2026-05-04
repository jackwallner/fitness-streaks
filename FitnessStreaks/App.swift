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

private final class BackgroundTaskCompletion: @unchecked Sendable {
    private let task: BGTask
    private let lock = NSLock()
    private var didComplete = false

    init(task: BGTask) {
        self.task = task
    }

    func complete(success: Bool) {
        lock.lock()
        defer { lock.unlock() }
        guard !didComplete else { return }
        didComplete = true
        task.setTaskCompleted(success: success)
    }
}

#if canImport(WatchConnectivity)
private final class PhoneSyncService: NSObject, WCSessionDelegate {
    nonisolated(unsafe) static let shared = PhoneSyncService()

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func currentSnapshotPayload(response: Bool = false) -> [String: Any]? {
        guard let snapshot = SnapshotStore.load(),
              let data = SnapshotStore.encode(snapshot) else {
            log.error("WC sync skipped: no encodable snapshot available")
            return nil
        }
        return [
            SnapshotStore.transferDataKey: data,
            "updated": snapshot.updated.timeIntervalSince1970,
            "hero": snapshot.hero?.metric ?? "none",
            "current": snapshot.hero?.current ?? 0,
            "response": response
        ]
    }

    /// Send updated streak snapshot to paired watch immediately
    func syncToWatch() {
        guard let payload = currentSnapshotPayload() else { return }
        let session = WCSession.default
        do {
            try session.updateApplicationContext(payload)
        } catch {
            log.error("WC application context update failed: \(String(describing: error))")
        }

        _ = session.transferUserInfo(payload)
        if session.remainingComplicationUserInfoTransfers > 0 {
            _ = session.transferCurrentComplicationUserInfo(payload)
        }

        // Try immediate delivery when the watch app is open; queued transfers cover the rest.
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                log.error("WC send failed: \(String(describing: error))")
            }
        }
    }

    /// Respond to watch's data request with current snapshot
    private func respondToWatchRequest() {
        guard let payload = currentSnapshotPayload(response: true) else { return }
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { error in
                log.error("WC response failed: \(String(describing: error))")
            }
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error { log.error("WC activation failed: \(String(describing: error))") }
        if state == .activated {
            syncToWatch()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    /// Watch requested fresh data — respond immediately
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["request"] as? Bool == true {
            respondToWatchRequest()
        }
    }

    /// Watch became reachable — push latest data proactively
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            syncToWatch()
        }
    }
}
#endif

@main
struct FitnessStreaksApp: App {
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var settings = StreakSettings.shared
    @StateObject private var store = StreakStore.shared
    @StateObject private var storeKit = StoreKitService.shared
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
                .environmentObject(storeKit)
                .task {
                    await healthKit.synchronizeAuthorization()
                    await storeKit.refreshState()
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
        let completion = BackgroundTaskCompletion(task: task)
        let work = Task { @MainActor in
            guard !Task.isCancelled else { return false }
            await StreakStore.shared.refreshIfNeeded(force: true)
            return !Task.isCancelled
        }
        task.expirationHandler = {
            work.cancel()
            completion.complete(success: false)
        }
        Task {
            let ok = await work.value
            completion.complete(success: ok)
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
