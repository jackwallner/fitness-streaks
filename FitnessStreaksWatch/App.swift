import SwiftUI
import SwiftData
import WatchKit
import WidgetKit
import os
#if canImport(WatchConnectivity)
@preconcurrency import WatchConnectivity
#endif

private let log = Logger(subsystem: "com.jackwallner.streaks.watch", category: "App")

#if canImport(WatchConnectivity)
private final class WatchSyncService: NSObject, WCSessionDelegate, @unchecked Sendable {
    static let shared = WatchSyncService()
    var onDataUpdate: (() -> Void)?

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func requestLatestSnapshot() {
        guard WCSession.isSupported(), WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["request": true], replyHandler: nil) { error in
            log.error("WC snapshot request failed: \(String(describing: error))")
        }
    }

    private func saveSnapshot(from message: [String: Any], source: String) {
        guard let data = message[SnapshotStore.transferDataKey] as? Data else {
            log.debug("WC \(source) ignored: no snapshot data")
            return
        }
        guard SnapshotStore.saveEncodedSnapshot(data) != nil else {
            log.error("WC \(source) ignored: snapshot data could not be decoded")
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.onDataUpdate?()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        saveSnapshot(from: message, source: "message")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        saveSnapshot(from: applicationContext, source: "applicationContext")
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        saveSnapshot(from: userInfo, source: "userInfo")
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error { log.error("WC activation failed: \(String(describing: error))") }
        if state == .activated {
            saveSnapshot(from: session.receivedApplicationContext, source: "activationContext")
            requestLatestSnapshot()
        }
    }
}
#endif

@main
struct FitnessStreaksWatchApp: App {
    @StateObject private var settings = StreakSettings.shared
    @StateObject private var store = StreakStore.shared

    init() {
        #if canImport(WatchConnectivity)
        WatchSyncService.shared.activate()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(settings)
                .environmentObject(store)
                .task {
                    #if canImport(WatchConnectivity)
                    WatchSyncService.shared.onDataUpdate = {
                        Task { await store.load() }
                    }
                    WatchSyncService.shared.requestLatestSnapshot()
                    #endif
                    await store.load()
                    Self.scheduleBackgroundRefresh()
                }
        }
        .modelContainer(DataService.sharedModelContainer)
        .backgroundTask(.appRefresh("streaks.watch.refresh")) {
            await Self.handleBackgroundRefresh()
        }
    }

    @MainActor
    private static func handleBackgroundRefresh() async {
        scheduleBackgroundRefresh()
        let work = Task { @MainActor in
            await StreakStore.shared.load()
            WidgetCenter.shared.reloadAllTimelines()
        }
        Task {
            try? await Task.sleep(for: .seconds(8))
            work.cancel()
        }
        _ = await work.result
    }

    @MainActor
    static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 30 * 60),
            userInfo: nil
        ) { error in
            if let error { log.error("schedule watch refresh: \(String(describing: error))") }
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject var store: StreakStore

    var body: some View {
        if store.streaks.isEmpty {
            WatchOnboardingView()
        } else {
            WatchTodayView()
        }
    }
}

struct WatchOnboardingView: View {
    @EnvironmentObject var store: StreakStore

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.streakHot)
                Text("Streak Finder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Open the iPhone app to set up your streaks. They'll sync to your watch automatically.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
