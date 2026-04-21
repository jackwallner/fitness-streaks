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

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: DispatchQueue.main) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.handleAppRefresh(task)
        }
        HealthKitService.shared.enableBackgroundDelivery()
        Self.scheduleAppRefresh()
        #if canImport(WatchConnectivity)
        PhoneSyncService.shared.activate()
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
                    await store.load()
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
            do {
                try await HealthKitService.shared.refreshCache()
                await StreakStore.shared.load()
                return true
            } catch {
                log.error("bg refresh failed: \(String(describing: error))")
                return false
            }
        }
        task.expirationHandler = { work.cancel() }
        Task {
            let ok = await work.value
            task.setTaskCompleted(success: ok)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings

    var body: some View {
        Group {
            if settings.hasCompletedSetup && healthKit.isAuthorized {
                DashboardView()
            } else {
                OnboardingView()
            }
        }
    }
}
