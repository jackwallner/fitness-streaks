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
        SnapshotStore.save(StreakEngine.snapshot(from: streaks))
    }

    /// Fetches fresh history from HealthKit, runs the engine, updates published state + widget snapshot.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await HealthKitService.shared.fetchHistory(days: 400)
            self.history = fresh
            try HealthKitService.shared.cache(fresh)
            // 90 days is enough to detect a real time-of-day rhythm without blowing up query cost.
            let hourly = (try? await HealthKitService.shared.fetchHourlySteps(days: 90)) ?? [:]
            let all = StreakEngine.discover(
                history: fresh,
                hourlySteps: hourly,
                hiddenMetrics: StreakSettings.shared.hiddenMetrics,
                vibe: StreakSettings.shared.vibe,
                lookbackDays: StreakSettings.shared.lookbackDays
            )
            self.allCandidates = all
            self.streaks = Self.applyTrackedFilter(all)
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
                self.history = cached
                let all = StreakEngine.discover(
                    history: cached,
                    hiddenMetrics: StreakSettings.shared.hiddenMetrics,
                    vibe: StreakSettings.shared.vibe,
                    lookbackDays: StreakSettings.shared.lookbackDays
                )
                self.allCandidates = all
                self.streaks = Self.applyTrackedFilter(all)
                persistCurrentSnapshot()
            }
        }
    }
}
