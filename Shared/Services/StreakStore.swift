import Foundation
import SwiftUI

/// Orchestrates HealthKit fetch → engine → published state for all UIs (iOS app + watch app).
@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    @Published var streaks: [Streak] = []
    /// Every streak the engine surfaced — unfiltered by the user's tracked-set.
    /// Used by the streak-selection picker so the user can opt streaks in/out.
    @Published var allCandidates: [Streak] = []
    @Published var history: [ActivityDay] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil

    var hero: Streak? { streaks.first }
    var badges: [Streak] { Array(streaks.dropFirst()) }

    /// Re-apply the tracked-streaks filter without refetching — used after the user
    /// edits their selections in Settings or during onboarding.
    func refilter() {
        streaks = Self.applyTrackedFilter(allCandidates)
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

    private init() {}

    func persistCurrentSnapshot() {
        var snapshot = StreakEngine.snapshot(from: streaks)
        snapshot.recentlyBroken = StreakSettings.shared.recentlyBroken
        SnapshotStore.save(snapshot)
    }

    /// Fetches fresh history from HealthKit, runs the engine, updates published state + widget snapshot.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let previous = self.streaks
            let fresh = try await HealthKitService.shared.fetchHistory(days: 400)
            self.history = fresh
            try HealthKitService.shared.cache(fresh)
            // 90 days is enough to detect a real time-of-day rhythm without blowing up query cost.
            let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
            let settings = StreakSettings.shared
            settings.pruneBroken()
            var all = StreakEngine.discover(
                history: fresh,
                hourlySteps: hourly,
                hiddenMetrics: settings.hiddenMetrics,
                vibe: settings.vibe,
                lookbackDays: settings.lookbackDays,
                committedThresholds: settings.committedThresholds,
                customStreaks: settings.customStreaks,
                gracePreservations: settings.gracePreservations
            )
            var filtered = Self.applyTrackedFilter(all)
            await handleBreaks(previous: previous, fresh: filtered, all: all, hourly: hourly, history: fresh)
            all = StreakEngine.discover(
                history: fresh,
                hourlySteps: hourly,
                hiddenMetrics: settings.hiddenMetrics,
                vibe: settings.vibe,
                lookbackDays: settings.lookbackDays,
                committedThresholds: settings.committedThresholds,
                customStreaks: settings.customStreaks,
                gracePreservations: settings.gracePreservations
            )
            filtered = Self.applyTrackedFilter(all)
            self.allCandidates = all
            self.streaks = filtered
            settings.commitThresholds(for: filtered)
            settings.awardGraceDays(from: filtered)
            persistCurrentSnapshot()
            self.lastUpdated = .now

            if let hero = self.hero {
                await NotificationService.scheduleDailyReminder(for: hero)
            } else {
                NotificationService.cancelAll()
            }
        } catch {
            print("StreakStore load error: \(error)")
            // Fall back to cached snapshot values if HK read failed
            let cached = HealthKitService.shared.cachedHistory()
            if !cached.isEmpty {
                let settings = StreakSettings.shared
                self.history = cached
                let all = StreakEngine.discover(
                    history: cached,
                    hiddenMetrics: settings.hiddenMetrics,
                    vibe: settings.vibe,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations
                )
                self.allCandidates = all
                self.streaks = Self.applyTrackedFilter(all)
                persistCurrentSnapshot()
            }
        }
    }

    private func handleBreaks(
        previous: [Streak],
        fresh: [Streak],
        all: [Streak],
        hourly: [Date: [Int: Double]],
        history: [ActivityDay]
    ) async {
        let settings = StreakSettings.shared
        let freshByKey = Dictionary(uniqueKeysWithValues: fresh.map { ($0.trackingKey, $0) })
        let today = DateHelpers.startOfDay()
        var newBroken = settings.recentlyBroken
        var preservations = settings.gracePreservations

        for old in previous where old.current >= 3 {
            let newCurrent = freshByKey[old.trackingKey]?.current ?? 0
            guard newCurrent == 0 else { continue }
            guard !newBroken.contains(where: { $0.key == old.trackingKey }) else { continue }

            if settings.consumeGraceDay() {
                preservations[old.trackingKey] = GracePreservation(
                    key: old.trackingKey,
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
                key: old.trackingKey,
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
}
