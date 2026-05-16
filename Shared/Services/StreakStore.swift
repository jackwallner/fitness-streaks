import Foundation
import SwiftUI
import os

private let log = Logger(subsystem: "com.jackwallner.streaks", category: "StreakStore")

/// Orchestrates HealthKit fetch → engine → published state for all UIs (iOS app + watch app).
@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    enum LoadStage: Equatable {
        case idle
        case readingHistory
        case analyzingPatterns
        case discoveringStreaks
        case finalizing

        var label: String {
            switch self {
            case .idle: ""
            case .readingHistory: "READING ACTIVITY HISTORY"
            case .analyzingPatterns: "ANALYZING TIME-OF-DAY PATTERNS"
            case .discoveringStreaks: "DISCOVERING STREAKS"
            case .finalizing: "FINALIZING"
            }
        }
    }

    @Published var streaks: [Streak] = []
    /// Every streak the engine surfaced — unfiltered by the user's tracked-set.
    /// Used by the streak-selection picker so the user can opt streaks in/out.
    @Published var allCandidates: [Streak] = []
    @Published var history: [ActivityDay] = []
    @Published var hourlySteps: [Date: [Int: Double]] = [:]
    @Published var isLoading: Bool = false
    @Published var loadProgress: Double = 0
    @Published var loadStage: LoadStage = .idle
    @Published var lastUpdated: Date? = nil
    @Published var isRefreshing: Bool = false

    /// Heuristic flag: a fresh HealthKit fetch returned zero step data across the
    /// recent window even though the cache previously held non-trivial data. The
    /// most likely cause is the user revoked Apple Health access in iOS Settings,
    /// but this can't be confirmed (Apple's privacy contract hides read denial),
    /// so the UI presents this as a soft "may need attention" banner — never a
    /// destructive action.
    @Published var dataMaybeRevoked: Bool = false

    var hero: Streak? { streaks.first }
    var badges: [Streak] { Array(streaks.dropFirst()) }

    /// Re-apply the tracked-streaks filter without refetching — used after the user
    /// edits their selections in Settings or during onboarding.
    func refilter() {
        var filtered = Self.applyTrackedFilter(allCandidates)
        filtered = Self.applyManualOrder(filtered, manualOrder: StreakSettings.shared.manualStreakOrder)
        streaks = filtered
        StreakSettings.shared.commitThresholds(for: streaks)
        persistCurrentSnapshot()
    }

    static func applyTrackedFilter(_ streaks: [Streak]) -> [Streak] {
        applyTrackedFilter(streaks, tracked: StreakSettings.shared.trackedStreaks)
    }

    nonisolated static func applyTrackedFilter(_ streaks: [Streak], tracked: Set<String>?) -> [Streak] {
        guard let tracked else { return streaks }
        if tracked.isEmpty { return [] }
        return streaks.filter { tracked.contains($0.trackingKey) }
    }

    /// Composite cross-metric activity signal for a window. Steps dominate for most
    /// users, but the weighted terms keep the signal meaningful for people who don't
    /// track steps at all (wheelchair users, cyclists, swimmers) so data-loss
    /// detection isn't steps-only.
    nonisolated static func activitySignal(_ days: [ActivityDay]) -> Double {
        days.reduce(0.0) { sum, d in
            sum + d.steps
                + d.exerciseMinutes * 100
                + d.activeEnergy
                + d.distanceMiles * 1_000
                + d.flightsClimbed * 100
                + d.workoutCount * 1_000
                + d.standHours * 100
        }
    }

    /// Heuristic: does this fetch look like a transient empty read or a revoked
    /// permission — i.e. NOT a real lull? True iff the fresh fetch shows *zero*
    /// recorded activity of any kind across the last 14 days while the pre-fetch
    /// cache had a meaningful total over the same window.
    ///
    /// When true the caller must NOT run break detection or overwrite state: Apple's
    /// privacy contract hides read denial, and a cold-launch race can momentarily
    /// return all-zero data — declaring streaks broken (and pushing a discouraging
    /// notification) off that is the worst possible false positive.
    nonisolated static func detectLikelyDataLoss(fresh: [ActivityDay], previousCache: [ActivityDay]) -> Bool {
        guard !previousCache.isEmpty else { return false }
        let windowStart = DateHelpers.daysAgo(13)
        let recentFresh = fresh.filter { $0.date >= windowStart }
        let recentCache = previousCache.filter { $0.date >= windowStart }
        guard !recentFresh.isEmpty, !recentCache.isEmpty else { return false }
        return activitySignal(recentFresh) == 0 && activitySignal(recentCache) >= 3_000
    }

    /// Apply manual ordering: items in manualOrder come first in that order,
    /// remaining items follow sorted by their original engine ranking.
    static func applyManualOrder(_ streaks: [Streak], manualOrder: [String]) -> [Streak] {
        guard !manualOrder.isEmpty else { return streaks }
        let orderIndex = Dictionary(uniqueKeysWithValues: manualOrder.enumerated().map { ($0.element, $0.offset) })
        return streaks.sorted {
            let idx0 = orderIndex[$0.trackingKey] ?? Int.max
            let idx1 = orderIndex[$1.trackingKey] ?? Int.max
            return idx0 < idx1
        }
    }

    private init() {
        // Hydrate from the last persisted snapshot so the dashboard shows
        // cached streaks immediately on cold launch — same pattern as HealthKit's
        // cachedHistory. Fresh data flows in once `load()` completes.
        if let snapshot = SnapshotStore.load() {
            restore(snapshot)
        }
    }

    func persistCurrentSnapshot() {
        var snapshot = StreakEngine.snapshot(from: streaks)
        snapshot.recentlyBroken = StreakSettings.shared.recentlyBroken
        SnapshotStore.save(snapshot)
        // Notify iOS app to sync to watch (iOS-only, watch ignores this)
        NotificationCenter.default.post(name: .streakSnapshotUpdated, object: nil)
    }

    func refreshIfNeeded(force: Bool = false) async {
        if isLoading || isRefreshing { return }
        let stale = lastUpdated.map { Date().timeIntervalSince($0) > 60 } ?? true
        guard force || stale else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await load(allowCachedSnapshot: !streaks.isEmpty)
    }

    /// Fetches fresh history from HealthKit, runs the engine, updates published state + widget snapshot.
    /// On watchOS, skips HealthKit and reads only from the snapshot written by the iPhone app.
    func load(allowCachedSnapshot: Bool = false) async {
        if isLoading { return }

        #if os(watchOS)
        // Watch app: no HealthKit access needed; just display data synced from iPhone
        if let snapshot = SnapshotStore.load() {
            restore(snapshot)
        }
        return
        #else

        if allowCachedSnapshot, streaks.isEmpty, let snapshot = SnapshotStore.load() {
            restore(snapshot)
        }
        StreakSettings.shared.pruneOldFreezes()
        isLoading = true
        withAnimation(.linear(duration: 0.2)) {
            loadStage = .readingHistory
            loadProgress = 0.05
        }
        defer {
            isLoading = false
            withAnimation(.linear(duration: 0.2)) {
                loadStage = .idle
                loadProgress = 0
            }
        }
        do {
            let previous = self.streaks
            // Snapshot pre-fetch cache for the data-loss heuristic below — once we
            // call HealthKitService.cache() with the fresh result, this comparison
            // would be against itself.
            let preFetchCached = HealthKitService.shared.cachedHistory(days: 30)
            let fresh = try await HealthKitService.shared.fetchHistory(days: 400)

            // If the fetch came back suspiciously empty (transient cold-launch race
            // or revoked permission — Apple hides read denial), do NOT cache it,
            // run the engine, detect breaks, or overwrite displayed state. Surface
            // the soft banner and keep the last good data intact. Returning here is
            // the single most important guard against falsely killing a real streak.
            if Self.detectLikelyDataLoss(fresh: fresh, previousCache: preFetchCached) {
                log.warning("Skipping load — fresh HealthKit fetch is empty but cache had activity (likely transient/revoked)")
                self.dataMaybeRevoked = true
                return
            }
            self.dataMaybeRevoked = false
            withAnimation(.linear(duration: 0.25)) {
                loadProgress = 0.5
                loadStage = .analyzingPatterns
            }
            // 90 days is enough to detect a real time-of-day rhythm without blowing up query cost.
            let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
            withAnimation(.linear(duration: 0.25)) {
                loadProgress = 0.78
                loadStage = .discoveringStreaks
            }
            // Compute early steps (0–8am) from hourly data so the engine can evaluate .earlySteps streaks.
            var enriched = fresh
            if !hourly.isEmpty {
                enriched = fresh.map { day in
                    let hours = hourly[day.date] ?? [:]
                    let early = (0..<8).reduce(0.0) { sum, h in sum + (hours[h] ?? 0) }
                    return ActivityDay(
                        date: day.date,
                        steps: day.steps,
                        exerciseMinutes: day.exerciseMinutes,
                        standHours: day.standHours,
                        activeEnergy: day.activeEnergy,
                        workoutCount: day.workoutCount,
                        mindfulMinutes: day.mindfulMinutes,
                        sleepHours: day.sleepHours,
                        distanceMiles: day.distanceMiles,
                        flightsClimbed: day.flightsClimbed,
                        earlySteps: early,
                        heartRateMinutes: day.heartRateMinutes,
                        workoutDetails: day.workoutDetails
                    )
                }
            }
            self.history = enriched
            self.hourlySteps = hourly
            try HealthKitService.shared.cache(enriched)
            let settings = StreakSettings.shared
            settings.pruneBroken()
            // Planned freezes are a Pro-only benefit. Keep the data in settings (so a
            // re-subscribe restores it) but don't let the engine honor it when the
            // entitlement has lapsed — otherwise freezes silently keep working while
            // the UI to manage them is locked. gracePreservations are intentionally
            // NOT gated: the free one-shot auto-save writes one and it must be honored.
            let effectiveFreezes = StoreKitService.shared.isPro ? settings.plannedFreezes : []
            var all = StreakEngine.discover(
                history: enriched,
                hourlySteps: hourly,
                hiddenMetrics: settings.hiddenMetrics,
                intensity: settings.intensity,
                lookbackDays: settings.lookbackDays,
                committedThresholds: settings.committedThresholds,
                customStreaks: settings.customStreaks,
                gracePreservations: settings.gracePreservations,
                plannedFreezes: effectiveFreezes
            )
            var filtered = Self.applyTrackedFilter(all)
            let graceBefore = settings.gracePreservations.count
            let brokenBefore = settings.recentlyBroken.count
            await handleBreaks(previous: previous, fresh: filtered, hourly: hourly, history: enriched)
            let needsRediscover = settings.gracePreservations.count > graceBefore
                               || settings.recentlyBroken.count > brokenBefore
            if needsRediscover {
                all = StreakEngine.discover(
                    history: enriched,
                    hourlySteps: hourly,
                    hiddenMetrics: settings.hiddenMetrics,
                    intensity: settings.intensity,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations,
                    plannedFreezes: effectiveFreezes
                )
            }
            filtered = Self.applyTrackedFilter(all)
            filtered = Self.applyManualOrder(filtered, manualOrder: settings.manualStreakOrder)
            self.allCandidates = all
            self.streaks = filtered
            settings.commitThresholds(for: filtered)
            persistCurrentSnapshot()
            recordLastKnownLengths()
            self.lastUpdated = .now
            withAnimation(.linear(duration: 0.25)) {
                loadProgress = 0.95
                loadStage = .finalizing
            }

            await NotificationService.scheduleDailyReminder(for: self.streaks)
            withAnimation(.linear(duration: 0.2)) {
                loadProgress = 1.0
            }
        } catch {
            log.error("StreakStore load error: \(String(describing: error))")
            // Fall back to cached snapshot values if HK read failed
            let cached = HealthKitService.shared.cachedHistory()
            if !cached.isEmpty {
                let settings = StreakSettings.shared
                self.history = cached
                let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
                self.hourlySteps = hourly
                let effectiveFreezes = StoreKitService.shared.isPro ? settings.plannedFreezes : []
                let all = StreakEngine.discover(
                    history: cached,
                    hourlySteps: hourly,
                    hiddenMetrics: settings.hiddenMetrics,
                    intensity: settings.intensity,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations,
                    plannedFreezes: effectiveFreezes
                )
                self.allCandidates = all
                var filtered = Self.applyTrackedFilter(all)
                filtered = Self.applyManualOrder(filtered, manualOrder: settings.manualStreakOrder)
                self.streaks = filtered
                persistCurrentSnapshot()
            }
        }
        #endif
    }

    private func restore(_ snapshot: StreakSnapshot) {
        let restored = ([snapshot.hero].compactMap { $0 } + snapshot.badges).compactMap { item -> Streak? in
            guard let metric = item.streakMetric else { return nil }
            let workoutMeasure = item.workoutMeasureValue
            return Streak(
                customID: item.customID,
                metric: metric,
                cadence: item.streakCadence,
                threshold: item.threshold,
                window: item.hourWindow.map { HourWindow(startHour: $0) },
                workoutType: item.workoutType,
                workoutMeasure: workoutMeasure,
                current: item.current,
                best: item.best,
                startDate: nil,
                lastHitDate: nil,
                currentUnitCompleted: item.currentUnitCompleted,
                currentUnitProgress: item.currentUnitProgress,
                currentUnitValue: item.currentUnitValue
            )
        }
        guard !restored.isEmpty else { return }
        // Re-apply tracked filter and manual order to ensure consistency with iPhone
        let settings = StreakSettings.shared
        var filtered = Self.applyTrackedFilter(restored, tracked: settings.trackedStreaks)
        filtered = Self.applyManualOrder(filtered, manualOrder: settings.manualStreakOrder)
        streaks = filtered
        allCandidates = restored
        lastUpdated = snapshot.updated
    }

    private func handleBreaks(
        previous: [Streak],
        fresh: [Streak],
        hourly: [Date: [Int: Double]],
        history: [ActivityDay]
    ) async {
        let settings = StreakSettings.shared
        let freshByKey = Dictionary(uniqueKeysWithValues: fresh.map { ($0.trackingKey, $0) })
        let today = DateHelpers.startOfDay()
        var newBroken = settings.recentlyBroken
        var preservations = settings.gracePreservations

        // Build a baseline of "what we last saw before this load." Use in-memory `previous`
        // when present; otherwise fall back to persisted last-known lengths so we still detect
        // breaks after a cold start (force-quit, reboot, post-midnight launch).
        var baseline: [String: Streak] = Dictionary(uniqueKeysWithValues: previous.map { ($0.trackingKey, $0) })
        for (key, length) in settings.lastKnownStreakLengths where baseline[key] == nil {
            // Reconstruct just enough of a Streak to drive break detection.
            // Threshold/metric come from fresh (post-break) when available; otherwise default to
            // values we can't recover (the user will still see the broken banner with `?` cadence).
            if let f = freshByKey[key] {
                baseline[key] = Streak(
                    customID: f.customID,
                    metric: f.metric,
                    cadence: f.cadence,
                    threshold: f.threshold,
                    window: f.window,
                    workoutType: f.workoutType,
                    workoutMeasure: f.workoutMeasure,
                    current: length,
                    best: max(length, f.best),
                    startDate: nil,
                    lastHitDate: nil,
                    currentUnitCompleted: false,
                    currentUnitProgress: 0,
                    currentUnitValue: 0
                )
            }
        }

        for (key, old) in baseline where old.current >= 3 {
            let newCurrent = freshByKey[key]?.current ?? 0
            guard newCurrent == 0 else { continue }
            guard !newBroken.contains(where: { $0.key == key }) else { continue }

            if settings.attemptAutoSave(isPro: StoreKitService.shared.isPro) {
                preservations[key] = GracePreservation(
                    key: key,
                    missedDate: DateHelpers.addDays(-1, to: today),
                    preservedLength: old.current,
                    threshold: old.threshold,
                    metric: old.metric,
                    cadence: old.cadence,
                    hourWindow: old.window?.startHour,
                    grantedAt: .now
                )
                continue
            }

            let broken = BrokenStreak(
                key: key,
                metric: old.metric,
                cadence: old.cadence,
                threshold: old.threshold,
                hourWindow: old.window?.startHour,
                brokenLength: old.current,
                brokenAt: .now
            )
            newBroken.append(broken)
            await NotificationService.notifyStreakBroken(broken)
        }

        settings.gracePreservations = preservations
        settings.recentlyBroken = newBroken
    }

    /// Convert a recently-broken streak into a grace preservation so the engine
    /// bridges the missed day on the next load. Called when the user upgrades to
    /// Pro from the BrokenStreakSheet — the trial *is* the revival.
    ///
    /// The engine only bridges yesterday's miss (see `applyPreservation` in
    /// StreakEngine), so callers should gate this on `canRevive`.
    func reviveBrokenStreak(_ broken: BrokenStreak) async {
        let settings = StreakSettings.shared
        var preservations = settings.gracePreservations
        preservations[broken.key] = GracePreservation(
            key: broken.key,
            missedDate: DateHelpers.startOfDay(broken.brokenAt),
            preservedLength: broken.brokenLength,
            threshold: broken.threshold,
            metric: broken.metric,
            cadence: broken.cadence,
            hourWindow: broken.hourWindow,
            grantedAt: .now
        )
        settings.gracePreservations = preservations
        settings.recentlyBroken.removeAll { $0.id == broken.id }
        await load()
    }

    /// Snapshot the current tracked streak lengths so the next launch can detect breaks
    /// that happened while the app was killed.
    fileprivate func recordLastKnownLengths() {
        let map = Dictionary(uniqueKeysWithValues: streaks.map { ($0.trackingKey, $0.current) })
        StreakSettings.shared.lastKnownStreakLengths = map
    }
}

extension Notification.Name {
    static let streakSnapshotUpdated = Notification.Name("streakSnapshotUpdated")
}
