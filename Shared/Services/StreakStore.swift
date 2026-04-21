import Foundation
import SwiftUI

/// Orchestrates HealthKit fetch → engine → published state for all UIs (iOS app + watch app).
@MainActor
final class StreakStore: ObservableObject {
    static let shared = StreakStore()

    @Published var streaks: [Streak] = []
    @Published var history: [ActivityDay] = []
    @Published var isLoading: Bool = false
    @Published var lastUpdated: Date? = nil

    var hero: Streak? { streaks.first }
    var badges: [Streak] { Array(streaks.dropFirst()) }

    private init() {}

    /// Fetches fresh history from HealthKit, runs the engine, updates published state + widget snapshot.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fresh = try await HealthKitService.shared.fetchHistory(days: 400)
            self.history = fresh
            try await HealthKitService.shared.refreshCache(days: 400)
            self.streaks = StreakEngine.discover(
                history: fresh,
                hiddenMetrics: StreakSettings.shared.hiddenMetrics,
                vibe: StreakSettings.shared.vibe,
                minStreakLength: StreakSettings.shared.minStreakLength
            )
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
                self.streaks = StreakEngine.discover(
                    history: cached,
                    hiddenMetrics: StreakSettings.shared.hiddenMetrics
                )
            }
        }
    }
}
