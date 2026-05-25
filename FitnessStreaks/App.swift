import SwiftUI
import SwiftData
import BackgroundTasks
import WidgetKit
import os
#if REVENUECAT
import RevenueCat
#endif
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

    // Store observer token for cleanup
    @State private var snapshotObserver: NSObjectProtocol?

    init() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: DispatchQueue.main) { task in
            guard let task = task as? BGAppRefreshTask else { return }
            Self.handleAppRefresh(task)
        }
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
                .environmentObject(storeKit)
                .task {
                    await healthKit.synchronizeAuthorization()
                    #if DEBUG
                    if CommandLine.arguments.contains("-UITestSetPro") {
                        storeKit.debugSetPro(true)
                    } else {
                        await storeKit.refreshState()
                    }
                    #else
                    await storeKit.refreshState()
                    #endif
                    // If setup was completed previously but this device has never actually
                    // fetched HealthKit data (cache is empty), force onboarding so the user
                    // gets a clear path to trigger the Health permission prompt.
                    // We check for actual data rather than authorization status because
                    // authorizationStatus(for:) always returns .notDetermined for read-only
                    // types, making status-based checks unreliable on cold launch.
                    if settings.hasCompletedSetup,
                       !CommandLine.arguments.contains("-UITestSkipHealthKit") {
                        let cached = HealthKitService.shared.cachedHistory(days: 30)
                        if cached.isEmpty {
                            log.warning("Resetting onboarding — hasCompletedSetup=true but HealthKit cache is empty (never authorized)")
                            settings.hasCompletedSetup = false
                        }
                    }
                    await store.load(allowCachedSnapshot: true)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task(priority: .utility) {
                        await storeKit.refreshEntitlement()
                        await store.refreshIfNeeded()
                    }
                }
                .onAppear {
                    #if canImport(WatchConnectivity)
                    // Register observer for snapshot updates to push to watch
                    snapshotObserver = NotificationCenter.default.addObserver(
                        forName: .streakSnapshotUpdated,
                        object: nil,
                        queue: .main
                    ) { _ in
                        PhoneSyncService.shared.syncToWatch()
                    }
                    #endif
                }
                .onDisappear {
                    #if canImport(WatchConnectivity)
                    if let observer = snapshotObserver {
                        NotificationCenter.default.removeObserver(observer)
                        snapshotObserver = nil
                    }
                    #endif
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
            await StoreKitService.shared.refreshEntitlement()
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
    @EnvironmentObject var storeKit: StoreKitService
    @EnvironmentObject var store: StreakStore

    @State private var showTrialOffer = false
    @State private var showTrialPaywall = false
    @State private var trialPurchaseInFlight = false
    @State private var trialPurchaseError: String?
    /// Set when the user opts into the full paywall from inside the trial sheet.
    /// `.sheet(onDismiss:)` reads this and presents the full paywall *after* the
    /// trial sheet finishes dismissing — presenting both bindings in the same tick
    /// is racy in SwiftUI and frequently drops the second sheet.
    @State private var pendingPaywallAfterTrialDismiss = false
    #if REVENUECAT
    @State private var trialOfferPackage: Package?
    #endif

    /// Free-tier cap used for the "Keep all N streaks" pitch. Mirrors
    /// `OnboardingView.freeTrackedLimit` — kept in sync manually since that
    /// constant is fileprivate to OnboardingView.
    private static let freeTrackedLimit = 3

    var body: some View {
        Group {
            if settings.hasCompletedSetup {
                RootTabView()
            } else {
                OnboardingView()
            }
        }
        #if REVENUECAT
        .task {
            // Re-evaluate once products have a chance to load on this session.
            if storeKit.offerings == nil { await storeKit.loadProducts() }
            evaluateTrialOffer()
        }
        .onChange(of: settings.hasCompletedSetup) { _, done in
            if done { evaluateTrialOffer() }
        }
        .onChange(of: storeKit.offerings != nil) { _, _ in
            evaluateTrialOffer()
        }
        .onChange(of: storeKit.isPro) { _, isPro in
            if isPro { showTrialOffer = false }
        }
        .sheet(isPresented: $showTrialOffer, onDismiss: {
            settings.hasSeenTrialOffer = true
            trialPurchaseInFlight = false
            trialPurchaseError = nil
            trialOfferPackage = nil
            if pendingPaywallAfterTrialDismiss {
                pendingPaywallAfterTrialDismiss = false
                showTrialPaywall = true
            }
        }) {
            TrialOfferSheet(
                offerLabel: trialOfferPackage?.streaksIntroOfferLabel
                    ?? storeKit.products.compactMap(\.streaksIntroOfferLabel).first,
                priceLabel: trialOfferPackage?.streaksRecurringPriceLabel,
                directPurchase: trialOfferPackage != nil,
                isPurchasing: trialPurchaseInFlight,
                errorMessage: trialPurchaseError,
                pickedCount: settings.lastOnboardingPickedCount,
                freeCap: Self.freeTrackedLimit,
                longestStreak: longestStreakInfo(),
                onStartTrial: {
                    if trialOfferPackage != nil {
                        startDirectTrialPurchase()
                    } else {
                        pendingPaywallAfterTrialDismiss = true
                        showTrialOffer = false
                    }
                },
                onSeeAllPlans: {
                    pendingPaywallAfterTrialDismiss = true
                    showTrialOffer = false
                },
                onDismiss: { showTrialOffer = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(trialPurchaseInFlight)
        }
        .sheet(isPresented: $showTrialPaywall) {
            PaywallView(paywallImpressionId: "streaks_trial_sheet")
        }
        #endif
    }

    /// Longest currently-tracked streak, used to personalize TrialOfferSheet copy.
    /// Returns nil when the dashboard is empty (cold start, no data yet).
    private func longestStreakInfo() -> TrialOfferSheet.LongestStreakInfo? {
        let pool = store.streaks.isEmpty ? store.allCandidates : store.streaks
        guard let top = pool.max(by: { $0.current < $1.current }), top.current > 0 else {
            return nil
        }
        return .init(
            displayName: top.displayName,
            current: top.current,
            cadenceLabel: top.cadence.label
        )
    }

    #if REVENUECAT
    /// Yearly trial-bearing package, else any trial-bearing package. Yearly is
    /// preferred because the longer commitment maximizes trial conversion value.
    private var directTrialPackage: Package? {
        let trialPackages = storeKit.products.filter { $0.streaksIntroOfferLabel != nil }
        return trialPackages.first(where: { $0.packageType == .annual }) ?? trialPackages.first
    }

    /// One-time post-onboarding free-trial nudge. Gates:
    /// - onboarding done (so we don't double-prompt on the onboarding paywall)
    /// - not already Pro
    /// - haven't seen the trial offer before
    /// - at least one trial-bearing product loaded
    private func evaluateTrialOffer() {
        guard settings.hasCompletedSetup,
              !storeKit.isPro,
              !settings.hasSeenTrialOffer,
              storeKit.products.contains(where: { $0.streaksIntroOfferLabel != nil })
        else { return }
        Task { @MainActor in
            // Defer ~4s so the user sees their dashboard hydrate (rings, hero
            // streak, badges) before the pitch. A cold pitch at first paint
            // converts worse and collides with the dashboard's onAppear coachmark.
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !showTrialOffer, !showTrialPaywall,
                  !settings.hasSeenTrialOffer, !storeKit.isPro,
                  storeKit.products.contains(where: { $0.streaksIntroOfferLabel != nil })
            else { return }
            trialOfferPackage = directTrialPackage
            showTrialOffer = true
        }
    }

    private func startDirectTrialPurchase() {
        guard let package = trialOfferPackage ?? directTrialPackage else {
            pendingPaywallAfterTrialDismiss = true
            showTrialOffer = false
            return
        }
        trialPurchaseError = nil
        trialPurchaseInFlight = true
        Task { @MainActor in
            defer { trialPurchaseInFlight = false }
            switch await storeKit.purchase(package: package) {
            case .purchased, .pending:
                settings.hasSeenTrialOffer = true
                showTrialOffer = false
            case .cancelled:
                trialPurchaseError = "Trial wasn't started. Tap again, or pick a different plan."
            case .failed:
                trialPurchaseError = storeKit.lastError ?? "Couldn't start your trial. Please try again."
            }
        }
    }
    #endif
}
