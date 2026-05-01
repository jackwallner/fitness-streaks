import SwiftUI
import SwiftData
import WatchKit
import WidgetKit
import os

private let log = Logger(subsystem: "com.jackwallner.streaks.watch", category: "App")

@main
struct FitnessStreaksWatchApp: App {
    @StateObject private var healthKit = HealthKitService.shared
    @StateObject private var settings = StreakSettings.shared
    @StateObject private var store = StreakStore.shared

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(healthKit)
                .environmentObject(settings)
                .environmentObject(store)
                .task {
                    await healthKit.synchronizeAuthorization()
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
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings

    var body: some View {
        if healthKit.hasRequestedAuthorization && settings.hasCompletedSetup {
            WatchTodayView()
        } else {
            WatchOnboardingView()
        }
    }
}

struct WatchOnboardingView: View {
    @EnvironmentObject var healthKit: HealthKitService
    @EnvironmentObject var settings: StreakSettings
    @EnvironmentObject var store: StreakStore
    @State private var requesting = false
    @State private var showHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.streakGradient)
                Text("Streak Finder")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Allow Health access to see your streaks.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    Task { await connect() }
                } label: {
                    Text(requesting ? "…" : "Connect")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .tint(Theme.streakHot)
                .buttonStyle(.borderedProminent)
                .disabled(requesting)
                .padding(.top, 4)

                if showHelp {
                    helpBlock
                }
            }
            .padding()
        }
    }

    private var helpBlock: some View {
        VStack(spacing: 6) {
            Text("Didn't see a prompt?")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Open the Health app on your iPhone → Sharing → Apps → Streak Finder, then enable the categories you want to track.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Continue Anyway") {
                settings.hasCompletedSetup = true
                Task { await store.load() }
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .buttonStyle(.bordered)
            .tint(Theme.streakHot)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private func connect() async {
        requesting = true
        showHelp = false
        defer { requesting = false }

        do {
            try await healthKit.requestAuthorization()
        } catch {
            log.error("watch authorization failed: \(String(describing: error))")
            showHelp = true
            return
        }

        // We can't detect read-permission denial directly (Apple privacy). But if the
        // post-request status is still `.shouldRequest`, it means the system suppressed
        // the prompt entirely — almost always because the user already denied at some
        // earlier point. Surface phone-side recovery instructions instead of silently
        // dropping into a data-less dashboard.
        let post = await healthKit.authorizationRequestStatus()
        if post == .shouldRequest {
            log.warning("watch auth: postStatus=.shouldRequest after request — prompt suppressed")
            showHelp = true
            return
        }

        settings.hasCompletedSetup = true
        await store.load()
    }
}
