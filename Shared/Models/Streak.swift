import Foundation

/// A single-hour slice of the day (e.g. 17 → "5–6pm").
/// When present on a Streak, we're tracking activity WITHIN that hour every day,
/// not the whole-day total. This is how Streak Finder surfaces hidden rhythms.
struct HourWindow: Hashable, Sendable, Codable {
    let startHour: Int   // 0...23

    var label: String {
        let s = Self.format(hour: startHour)
        let e = Self.format(hour: (startHour + 1) % 24)
        return "\(s)–\(e)"
    }

    static func format(hour: Int) -> String {
        switch hour {
        case 0: return "12a"
        case 12: return "12p"
        case 1..<12: return "\(hour)a"
        default: return "\(hour - 12)p"
        }
    }
}

/// A single discovered streak: user has hit `threshold` for `current` consecutive units ending now.
struct Streak: Identifiable, Hashable, Sendable {
    let metric: StreakMetric
    let cadence: StreakCadence
    let threshold: Double
    /// If non-nil, this streak is about activity within a specific hour of the day.
    /// Nil = whole-day/whole-week streak.
    var window: HourWindow? = nil

    /// Consecutive units meeting threshold, including the current unit if it already met it.
    let current: Int
    /// Longest-ever streak in the history window.
    let best: Int
    /// The unit (day-start / week-start) one step earlier than the live window; used to show "started on".
    let startDate: Date?
    /// The unit that closed most recently (yesterday for daily, last-week-end for weekly); used to show "last hit".
    let lastHitDate: Date?
    /// Whether the current unit (today / this week) has already hit the threshold.
    let currentUnitCompleted: Bool
    /// Progress of the current unit toward threshold, in [0, 1+]. >1 means exceeded.
    let currentUnitProgress: Double
    /// Current unit's raw value (steps so far today, workouts this week, etc.).
    let currentUnitValue: Double

    var id: String {
        if let w = window {
            return "\(metric.rawValue)-\(cadence.rawValue)-h\(w.startHour)-\(Int(threshold))"
        }
        return "\(metric.rawValue)-\(cadence.rawValue)-\(Int(threshold))"
    }

    /// Key used by StreakSettings.trackedStreaks — stable across threshold tier changes.
    var trackingKey: String {
        if let w = window {
            return "\(metric.rawValue)-\(cadence.rawValue)-h\(w.startHour)"
        }
        return "\(metric.rawValue)-\(cadence.rawValue)"
    }

    var isActive: Bool { current >= 1 }

    /// Rough "impressiveness" score used to rank across metrics.
    var score: Double {
        let base = Double(current) * metric.weight
        // Boost for higher-threshold tiers
        let thresholds = cadence == .daily ? metric.dailyThresholds : (metric.weeklyThresholds ?? metric.dailyThresholds)
        if let idx = thresholds.firstIndex(of: threshold) {
            let tierBonus = 1.0 + Double(idx) * 0.12
            return base * tierBonus
        }
        return base
    }
}

/// Daily sample in the cached activity history used by all screens + widgets.
struct ActivityDay: Hashable, Sendable {
    let date: Date          // start-of-day
    let steps: Double
    let exerciseMinutes: Double
    let standHours: Double
    let activeEnergy: Double
    let workoutCount: Double
    let mindfulMinutes: Double
    let sleepHours: Double
    let distanceMiles: Double
    let flightsClimbed: Double

    func value(for metric: StreakMetric) -> Double {
        switch metric {
        case .steps: steps
        case .exerciseMinutes: exerciseMinutes
        case .standHours: standHours
        case .activeEnergy: activeEnergy
        case .workouts: workoutCount
        case .mindfulMinutes: mindfulMinutes
        case .sleepHours: sleepHours
        case .distanceMiles: distanceMiles
        case .flightsClimbed: flightsClimbed
        }
    }
}
