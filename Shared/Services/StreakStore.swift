import Foundation
import SwiftUI
import WidgetKit
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
        streaks = Self.visibleStreaks(allCandidates)
        StreakSettings.shared.commitThresholds(for: streaks)
        persistCurrentSnapshot()
    }

    static func applyTrackedFilter(_ streaks: [Streak]) -> [Streak] {
        applyTrackedFilter(streaks, tracked: StreakSettings.shared.trackedStreaks)
    }

    /// The dashboard's streaks: tracked, in manual order, capped for free users.
    static func visibleStreaks(_ all: [Streak]) -> [Streak] {
        let settings = StreakSettings.shared
        return visibleStreaks(
            all,
            tracked: settings.trackedStreaks,
            manualOrder: settings.manualStreakOrder,
            unlimited: StoreKitService.shared.grantsUnlimitedTrackedStreaks
        )
    }

    nonisolated static func visibleStreaks(
        _ all: [Streak],
        tracked: Set<String>?,
        manualOrder: [String],
        unlimited: Bool
    ) -> [Streak] {
        let ordered = applyManualOrder(applyTrackedFilter(all, tracked: tracked), manualOrder: manualOrder)
        return unlimited ? ordered : Array(ordered.prefix(StreakSettings.freeTrackedLimit))
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

    /// Patch any past day where the fresh fetch shows zero activity but the pre-fetch
    /// cache had meaningful activity for that same day. This guards against transient
    /// HealthKit sync gaps — most commonly yesterday's value briefly returning as zero
    /// because the watch hasn't replayed to the phone yet, or during a flaky network
    /// state. Without this, the engine would walk back from today, see yesterday under
    /// threshold, reset the streak to zero, and `handleBreaks` would push a false
    /// "streak broken" notification.
    ///
    /// Today is intentionally NOT patched — today is allowed to still be accumulating.
    /// The wholesale `detectLikelyDataLoss` check still runs first and short-circuits
    /// the entire load when the full 14-day window comes back empty, so this only
    /// fires for narrow per-day gaps.
    nonisolated static func mergeWithCacheForMissingDays(fresh: [ActivityDay], previousCache: [ActivityDay]) -> [ActivityDay] {
        guard !previousCache.isEmpty else { return fresh }
        let today = DateHelpers.startOfDay()
        let cacheByDay: [Date: ActivityDay] = Dictionary(uniqueKeysWithValues: previousCache.map { ($0.date, $0) })
        return fresh.map { day in
            guard day.date < today else { return day }
            guard activitySignal([day]) == 0 else { return day }
            guard let cached = cacheByDay[day.date], activitySignal([cached]) > 0 else { return day }
            return cached
        }
    }

    /// Apply manual ordering: items in manualOrder come first in that order,
    /// remaining items follow sorted by their original engine ranking.
    nonisolated static func applyManualOrder(_ streaks: [Streak], manualOrder: [String]) -> [Streak] {
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
        // Tell WidgetKit to re-read the snapshot; otherwise widgets only refresh
        // on their own daily timeline policy and look stale after each app refresh.
        WidgetCenter.shared.reloadAllTimelines()
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
        #if DEBUG
        // Seeded screenshot data stands in for Apple Health. A load started on
        // launch (the task or the scene going active) would restore the widget
        // snapshot over it, so captures showed an empty or partial state.
        if Self.isSeedingScreenshots { return }
        #endif

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
            let rawFresh = try await HealthKitService.shared.fetchHistory(days: 400)

            // If the fetch came back suspiciously empty (transient cold-launch race
            // or revoked permission — Apple hides read denial), do NOT cache it,
            // run the engine, detect breaks, or overwrite displayed state. Surface
            // the soft banner and keep the last good data intact. Returning here is
            // the single most important guard against falsely killing a real streak.
            if Self.detectLikelyDataLoss(fresh: rawFresh, previousCache: preFetchCached) {
                log.warning("Skipping load — fresh HealthKit fetch is empty but cache had activity (likely transient/revoked)")
                self.dataMaybeRevoked = true
                return
            }
            self.dataMaybeRevoked = false
            // Patch narrow per-day gaps where the fresh fetch shows zero but the cache
            // had real activity — protects streaks from a watch->phone sync lag that
            // would otherwise read as a missed day and break the streak.
            let fresh = Self.mergeWithCacheForMissingDays(fresh: rawFresh, previousCache: preFetchCached)
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
            var filtered = Self.visibleStreaks(all)
            let graceBefore = settings.gracePreservations
            let brokenBefore = settings.recentlyBroken.count
            await handleBreaks(previous: previous, fresh: filtered, hourly: hourly, history: enriched)
            let needsRediscover = settings.gracePreservations != graceBefore
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
            filtered = Self.visibleStreaks(all)
            self.allCandidates = all
            self.streaks = filtered
            settings.commitThresholds(for: filtered)
            #if os(iOS)
            signalPositiveMomentsIfNeeded(previous: previous, newStreaks: filtered)
            #endif
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
            // HealthKit can't be read (most often a locked phone during background
            // refresh). The cache's last day may be a partial value, so rebuilding
            // from it would show live streaks as broken on every widget. Keep the
            // last good streaks and snapshot; only fill in from the cache when
            // nothing is on screen yet.
            let cached = HealthKitService.shared.cachedHistory()
            if self.history.isEmpty { self.history = cached }
            if self.streaks.isEmpty, !cached.isEmpty {
                let settings = StreakSettings.shared
                let effectiveFreezes = StoreKitService.shared.isPro ? settings.plannedFreezes : []
                let all = StreakEngine.discover(
                    history: cached,
                    hiddenMetrics: settings.hiddenMetrics,
                    intensity: settings.intensity,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations,
                    plannedFreezes: effectiveFreezes
                )
                self.allCandidates = all
                self.streaks = Self.visibleStreaks(all)
            }
        }
        #endif
    }

    #if DEBUG
    /// Supplies deterministic local activity for screenshot review. This keeps
    /// simulator captures meaningful without pretending HealthKit contains data.
    static let isSeedingScreenshots = CommandLine.arguments.contains("-UITestSeedStreaks")

    func seedScreenshotDataIfRequested() {
        guard Self.isSeedingScreenshots else { return }

        let today = DateHelpers.startOfDay()
        // Each seeded streak's days agree with its card: the current run up to
        // today (through any day Streaks+ saved), the miss before it, its
        // record run before that, then a mostly consistent history with an
        // occasional miss.
        func level(current: Int, best: Int, seed: Int, offset: Int, saved: Int? = nil) -> Double {
            let gapAfterRecord = current + best + 1
            let occasionalMiss = offset > gapAfterRecord && (offset * 31 + seed) % 7 == 0
            let isSavedDay = saved == offset
            let missed = offset == current || isSavedDay || offset == gapAfterRecord || occasionalMiss
            let jitter = Double((offset * 37 + seed * 11) % 100) / 100
            return missed ? 0.6 + jitter * 0.3 : 1.05 + jitter * 0.35
        }
        history = (0..<90).map { (offset: Int) -> ActivityDay in
            let isToday = offset == 0
            let steps: Double = isToday ? 8_960 : 8_000 * level(current: 12, best: 23, seed: 1, offset: offset, saved: 5)
            let exercise: Double = isToday ? 27 : 20 * level(current: 9, best: 17, seed: 2, offset: offset, saved: 4)
            let stand: Double = isToday ? 10 : (8 * level(current: 7, best: 14, seed: 3, offset: offset)).rounded()
            let sleep: Double = isToday ? 7.3 : 7 * level(current: 6, best: 12, seed: 4, offset: offset)
            let distance: Double = isToday ? 3.4 : 3 * level(current: 5, best: 11, seed: 5, offset: offset)
            let energy: Double = 410 + Double((offset * 17) % 90)
            let workouts: Double = offset % 4 == 0 ? 1 : 0
            let flights: Double = 8 + Double(offset % 5)
            let heartMinutes: Double = 18 + Double(offset % 8)
            return ActivityDay(
                date: DateHelpers.addDays(-offset, to: today),
                steps: steps,
                exerciseMinutes: exercise,
                standHours: stand,
                activeEnergy: energy,
                workoutCount: workouts,
                sleepHours: sleep,
                distanceMiles: distance,
                flightsClimbed: flights,
                heartRateMinutes: heartMinutes
            )
        }

        let seeded: [Streak] = [
            Streak(
                metric: .steps,
                cadence: .daily,
                threshold: 8_000,
                current: 12,
                best: 23,
                startDate: DateHelpers.addDays(-11, to: today),
                lastHitDate: DateHelpers.addDays(-1, to: today),
                currentUnitCompleted: true,
                currentUnitProgress: 1.12,
                currentUnitValue: 8_960,
                completionRate: 0.93,
                lookbackDays: 30
            ),
            Streak(
                metric: .exerciseMinutes,
                cadence: .daily,
                threshold: 20,
                current: 9,
                best: 17,
                startDate: DateHelpers.addDays(-8, to: today),
                lastHitDate: DateHelpers.addDays(-1, to: today),
                currentUnitCompleted: true,
                currentUnitProgress: 1.35,
                currentUnitValue: 27,
                completionRate: 0.90,
                lookbackDays: 30
            ),
            Streak(
                metric: .standHours,
                cadence: .daily,
                threshold: 8,
                current: 7,
                best: 14,
                startDate: DateHelpers.addDays(-6, to: today),
                lastHitDate: DateHelpers.addDays(-1, to: today),
                currentUnitCompleted: true,
                currentUnitProgress: 1.25,
                currentUnitValue: 10,
                completionRate: 0.90,
                lookbackDays: 30
            ),
            Streak(
                metric: .sleepHours,
                cadence: .daily,
                threshold: 7,
                current: 6,
                best: 12,
                startDate: DateHelpers.addDays(-5, to: today),
                lastHitDate: DateHelpers.addDays(-1, to: today),
                currentUnitCompleted: true,
                currentUnitProgress: 1.04,
                currentUnitValue: 7.3,
                completionRate: 0.87,
                lookbackDays: 30
            ),
            Streak(
                metric: .distanceMiles,
                cadence: .daily,
                threshold: 3,
                current: 5,
                best: 11,
                startDate: DateHelpers.addDays(-4, to: today),
                lastHitDate: DateHelpers.addDays(-1, to: today),
                currentUnitCompleted: true,
                currentUnitProgress: 1.13,
                currentUnitValue: 3.4,
                completionRate: 0.90,
                lookbackDays: 30
            )
        ]

        // The two days Streaks+ saved above, and a trip coming up.
        let savedDays: [(Streak, Int, Int)] = [(seeded[0], 5, 6), (seeded[1], 4, 4)]
        let saves = savedDays.map { (entry: (Streak, Int, Int)) -> GracePreservation in
            let (streak, missedOffset, runLength) = entry
            return GracePreservation(
                key: streak.trackingKey,
                missedDate: DateHelpers.addDays(-missedOffset, to: today),
                preservedLength: runLength,
                threshold: streak.threshold,
                metric: streak.metric,
                cadence: streak.cadence,
                hourWindow: nil,
                grantedAt: DateHelpers.addDays(-missedOffset + 1, to: today)
            )
        }
        StreakSettings.shared.gracePreservations = Dictionary(uniqueKeysWithValues: saves.map { ($0.key, $0) })
        StreakSettings.shared.plannedFreezes = [DateHelpers.addDays(9, to: today)]

        StreakSettings.shared.trackedStreaks = nil
        StreakSettings.shared.manualStreakOrder = []
        allCandidates = seeded
        streaks = seeded
        lastUpdated = .now
        persistCurrentSnapshot()
    }
    #endif

    private func restore(_ stored: StreakSnapshot) {
        let snapshot = stored.asOf(.now)
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
        #if os(watchOS)
        // The iPhone already filtered, ordered and capped the snapshot. The Watch's
        // own App Group holds none of the iPhone's settings.
        streaks = restored
        allCandidates = restored
        lastUpdated = snapshot.updated
        #else
        guard !restored.isEmpty else { return }
        streaks = Self.visibleStreaks(restored)
        allCandidates = restored
        lastUpdated = snapshot.updated
        #endif
    }

    struct DetectedBreak: Equatable {
        let key: String
        /// The day that was missed.
        let missedDate: Date
        /// Length of the run that broke.
        let length: Int
        /// Supplies metric, cadence, threshold and window for the save or broken record.
        let streak: Streak
    }

    /// Which tracked streaks broke since the last successful load.
    ///
    /// - Only streaks present in `fresh` are judged: one that vanished because the
    ///   user hid its metric, untracked it or recalibrated it did not break.
    /// - The baseline length is the last successful load's (`lastKnownLengths`),
    ///   not whatever is on screen, which a restored snapshot can make stale.
    /// - A streak at 0 missed yesterday. A shorter run than before also broke when
    ///   its most recent miss came after the last load, at the same goal: the user
    ///   missed a day and then met today's goal before opening the app.
    nonisolated static func detectBreaks(
        previous: [Streak],
        lastKnownLengths: [String: Int],
        lastKnownDate: Date?,
        fresh: [Streak],
        preservations: [String: GracePreservation],
        today: Date
    ) -> [DetectedBreak] {
        let previousByKey = Dictionary(previous.map { ($0.trackingKey, $0) }, uniquingKeysWith: { first, _ in first })
        let yesterday = DateHelpers.addDays(-1, to: today)
        let lastLoadDay = lastKnownDate.map { DateHelpers.startOfDay($0) }
        var out: [DetectedBreak] = []

        for now in fresh {
            let key = now.trackingKey
            let before = previousByKey[key]
            guard let length = lastKnownLengths[key] ?? before?.current, length >= 3 else { continue }

            let missed: Date
            if now.current == 0 {
                missed = yesterday
            } else if now.current < length,
                      let lastMissed = now.lastMissedDate.map({ DateHelpers.startOfDay($0) }),
                      let lastLoadDay, lastMissed >= lastLoadDay, lastMissed < today,
                      before.map({ $0.threshold == now.threshold }) ?? true {
                missed = lastMissed
            } else {
                continue
            }

            if let saved = preservations[key], DateHelpers.startOfDay(saved.missedDate) == missed { continue }
            out.append(DetectedBreak(key: key, missedDate: missed, length: length, streak: before ?? now))
        }
        return out.sorted { $0.key < $1.key }
    }

    private func handleBreaks(
        previous: [Streak],
        fresh: [Streak],
        hourly: [Date: [Int: Double]],
        history: [ActivityDay]
    ) async {
        let settings = StreakSettings.shared
        var newBroken = settings.recentlyBroken
        var preservations = settings.gracePreservations

        let breaks = Self.detectBreaks(
            previous: previous,
            lastKnownLengths: settings.lastKnownStreakLengths,
            lastKnownDate: settings.lastKnownStreakLengthsDate,
            fresh: fresh,
            preservations: preservations,
            today: DateHelpers.startOfDay()
        )

        for detected in breaks {
            let key = detected.key
            let old = detected.streak
            guard !newBroken.contains(where: { $0.key == key }) else { continue }

            if settings.attemptAutoSave(isPro: StoreKitService.shared.isPro) {
                preservations[key] = GracePreservation(
                    key: key,
                    missedDate: detected.missedDate,
                    preservedLength: detected.length,
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
                brokenLength: detected.length,
                brokenAt: .now,
                missedDate: detected.missedDate
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
            // Older records carry no missed day; they were always for the day
            // before the break was noticed.
            missedDate: broken.missedDate ?? DateHelpers.addDays(-1, to: DateHelpers.startOfDay(broken.brokenAt)),
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
        StreakSettings.shared.lastKnownStreakLengthsDate = .now
    }

    #if os(iOS)
    /// Fires when the hero streak grows or today's goal is newly completed — used for review prompts.
    private func signalPositiveMomentsIfNeeded(previous: [Streak], newStreaks: [Streak]) {
        guard let oldHero = previous.first, let newHero = newStreaks.first else { return }
        guard oldHero.trackingKey == newHero.trackingKey else { return }

        let streakGrew = newHero.current > oldHero.current && oldHero.current >= 2
        let goalJustMet = newHero.currentUnitCompleted && !oldHero.currentUnitCompleted && newHero.current >= 2
        guard streakGrew || goalJustMet else { return }

        ReviewPromptTracker.recordPositiveMoment()
        NotificationCenter.default.post(name: .reviewPromptPositiveMoment, object: nil)
    }
    #endif
}

extension Notification.Name {
    static let streakSnapshotUpdated = Notification.Name("streakSnapshotUpdated")
    #if os(iOS)
    static let reviewPromptPositiveMoment = Notification.Name("reviewPromptPositiveMoment")
    #endif
}
