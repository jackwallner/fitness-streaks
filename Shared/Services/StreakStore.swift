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
            // 90 days is enough to detect a real time-of-day rhythm without blowing up query cost.
            let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
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
                        heartRateMinutes: day.heartRateMinutes
                    )
                }
            }
            self.history = enriched
            try HealthKitService.shared.cache(enriched)
            let settings = StreakSettings.shared
            settings.pruneBroken()
            var all = StreakEngine.discover(
                history: enriched,
                hourlySteps: hourly,
                hiddenMetrics: settings.hiddenMetrics,
                vibe: settings.vibe,
                lookbackDays: settings.lookbackDays,
                committedThresholds: settings.committedThresholds,
                customStreaks: settings.customStreaks,
                gracePreservations: settings.gracePreservations
            )
            var filtered = Self.applyTrackedFilter(all)
            await handleBreaks(previous: previous, fresh: filtered, hourly: hourly, history: enriched)
            if settings.gracePreservations.isEmpty == false || settings.recentlyBroken.isEmpty == false {
                all = StreakEngine.discover(
                    history: enriched,
                    hourlySteps: hourly,
                    hiddenMetrics: settings.hiddenMetrics,
                    vibe: settings.vibe,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations
                )
            }
            filtered = Self.applyTrackedFilter(all)
            filtered = Self.applyManualOrder(filtered, manualOrder: settings.manualStreakOrder)
            self.allCandidates = all
            self.streaks = filtered
            settings.commitThresholds(for: filtered)
            settings.awardGraceDays(from: filtered)
            persistCurrentSnapshot()
            self.lastUpdated = .now

            await NotificationService.scheduleDailyReminder(for: self.streaks)
        } catch {
            print("StreakStore load error: \(error)")
            // Fall back to cached snapshot values if HK read failed
            let cached = HealthKitService.shared.cachedHistory()
            if !cached.isEmpty {
                let settings = StreakSettings.shared
                self.history = cached
                let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
                let all = StreakEngine.discover(
                    history: cached,
                    hourlySteps: hourly,
                    hiddenMetrics: settings.hiddenMetrics,
                    vibe: settings.vibe,
                    lookbackDays: settings.lookbackDays,
                    committedThresholds: settings.committedThresholds,
                    customStreaks: settings.customStreaks,
                    gracePreservations: settings.gracePreservations
                )
                self.allCandidates = all
                var filtered = Self.applyTrackedFilter(all)
                filtered = Self.applyManualOrder(filtered, manualOrder: settings.manualStreakOrder)
                self.streaks = filtered
                persistCurrentSnapshot()
            }
        }
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
