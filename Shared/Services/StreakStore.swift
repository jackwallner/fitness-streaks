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
    }

    static func applyTrackedFilter(_ streaks: [Streak]) -> [Streak] {
        guard let tracked = StreakSettings.shared.trackedStreaks else { return streaks }
        if tracked.isEmpty { return [] }
        return streaks.filter { tracked.contains(StreakSettings.streakKey(metric: $0.metric, cadence: $0.cadence)) }
    }

    private init() {}

    /// Fetches fresh history from HealthKit, runs the engine, updates published state + widget snapshot.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await HealthKitService.shared.fetchHistory(days: 400)
            self.history = fresh
            try await HealthKitService.shared.refreshCache(days: 400)
            let all = StreakEngine.discover(
                history: fresh,
                hiddenMetrics: StreakSettings.shared.hiddenMetrics,
                vibe: StreakSettings.shared.vibe,
                minStreakLength: StreakSettings.shared.minStreakLength
            )
            self.allCandidates = all
            self.streaks = Self.applyTrackedFilter(all)
            self.lastUpdated = .now

            // Schedule at-risk reminder using hero
            if let hero = self.hero {
                let label = hero.metric.thresholdLabel(hero.threshold, cadence: hero.cadence)
                await NotificationService.scheduleDailyReminder(heroLabel: label, currentLength: hero.current)
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
                    minStreakLength: StreakSettings.shared.minStreakLength
                )
                self.allCandidates = all
                self.streaks = Self.applyTrackedFilter(all)
            }
        }
    }
}
