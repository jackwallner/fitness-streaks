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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // iPhone sent updated streak data - refresh UI
        DispatchQueue.main.async { [weak self] in
            self?.onDataUpdate?()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let error { log.error("WC activation failed: \(String(describing: error))") }
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
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore

    var body: some View {
        if settings.hasWatchCompletedSetup {
            WatchTodayView()
        } else {
            WatchOnboardingView()
        }
    }
}

struct WatchOnboardingView: View {
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore
    @State private var dataJustReceived = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: dataJustReceived ? "checkmark.circle.fill" : "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(dataJustReceived ? Color.green : Theme.streakHot)
                Text(dataJustReceived ? "Streaks Synced!" : "Streak Finder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(messageText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    settings.hasWatchCompletedSetup = true
                } label: {
                    Text(dataJustReceived ? "Get Started" : "Continue")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .tint(Theme.streakHot)
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding()
        }
        .task {
            // Check if data already available
            if SnapshotStore.load() != nil {
                dataJustReceived = true
            }
            // Listen for sync from iPhone
            #if canImport(WatchConnectivity)
            WatchSyncService.shared.onDataUpdate = {
                dataJustReceived = true
                Task { await store.load() }
            }
            #endif
        }
    }

    private var messageText: String {
        if dataJustReceived {
            return "Your streaks are ready. Tap below to view them."
        }
        return "Open the iPhone app to set up your streaks. They'll sync to your watch automatically."
    }
}
