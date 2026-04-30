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
    let customID: String?
    let metric: StreakMetric
    let cadence: StreakCadence
    let threshold: Double
    /// If non-nil, this streak is about activity within a specific hour of the day.
    /// Nil = whole-day/whole-week streak.
    var window: HourWindow? = nil
    /// When set with `metric == .workouts`, the streak tracks a specific HK workout activity type.
    /// Key matches `WorkoutTypeCatalog.Entry.key`.
    var workoutType: String? = nil
    /// What measure of the workout type we count: sessions, minutes, or miles.
    /// Required when `workoutType` is set.
    var workoutMeasure: WorkoutMeasure? = nil

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
    /// Historical completion rate over the lookback window used to discover this streak.
    let completionRate: Double
    /// Number of days in the lookback window this rate was computed over.
    let lookbackDays: Int

    var id: String {
        if let customID {
            return "custom-\(customID)-\(Int(threshold))"
        }
        if let w = window {
            return "\(metric.rawValue)-\(cadence.rawValue)-h\(w.startHour)-\(Int(threshold))"
        }
        return "\(metric.rawValue)-\(cadence.rawValue)-\(Int(threshold))"
    }

    /// Key used by StreakSettings.trackedStreaks — stable across threshold tier changes.
    var trackingKey: String {
        if let customID {
            return "custom-\(customID)"
        }
        if let w = window {
            return "\(metric.rawValue)-\(cadence.rawValue)-h\(w.startHour)"
        }
        return "\(metric.rawValue)-\(cadence.rawValue)"
    }

    var isActive: Bool { current >= 1 }

    /// Rough "impressiveness" score used to rank across metrics.
    var score: Double {
        let base = Double(current) * metric.weight
        // Lower completion rate = harder threshold = higher score bonus.
        let difficulty = 1.0 + (1.0 - completionRate) * 0.5
        return base * difficulty
    }

    init(
        customID: String? = nil,
        metric: StreakMetric,
        cadence: StreakCadence,
        threshold: Double,
        window: HourWindow? = nil,
        workoutType: String? = nil,
        workoutMeasure: WorkoutMeasure? = nil,
        current: Int,
        best: Int,
        startDate: Date?,
        lastHitDate: Date?,
        currentUnitCompleted: Bool,
        currentUnitProgress: Double,
        currentUnitValue: Double,
        completionRate: Double = 0,
        lookbackDays: Int = 0
    ) {
        self.customID = customID
        self.metric = metric
        self.cadence = cadence
        self.threshold = threshold
        self.window = window
        self.workoutType = workoutType
        self.workoutMeasure = workoutMeasure
        self.current = current
        self.best = best
        self.startDate = startDate
        self.lastHitDate = lastHitDate
        self.currentUnitCompleted = currentUnitCompleted
        self.currentUnitProgress = currentUnitProgress
        self.currentUnitValue = currentUnitValue
        self.completionRate = completionRate
        self.lookbackDays = lookbackDays
    }

    /// Catalog entry for the workout type, when this is a per-type streak.
    var workoutTypeEntry: WorkoutTypeCatalog.Entry? {
        workoutType.flatMap(WorkoutTypeCatalog.entry(forKey:))
    }

    /// Best display name for this streak — uses workout type when set, else metric.
    var displayName: String {
        if let entry = workoutTypeEntry { return entry.displayName }
        return metric.displayName
    }

    /// Best symbol for this streak — uses workout type when set, else metric.
    var displaySymbol: String {
        if let entry = workoutTypeEntry { return entry.symbol }
        return metric.symbol
    }

    /// "20 min cycling" / "10k steps" / "any workout" — short label for cards and pickers.
    var thresholdLabel: String {
        if let entry = workoutTypeEntry, let measure = workoutMeasure {
            return Self.workoutThresholdLabel(threshold, entry: entry, measure: measure)
        }
        return metric.thresholdLabel(threshold, cadence: cadence)
    }

    /// "10,000+ steps every day" — long-form description used in detail headers.
    var prose: String {
        if let entry = workoutTypeEntry, let measure = workoutMeasure {
            return Self.workoutProse(threshold, entry: entry, measure: measure)
        }
        return metric.prose(threshold, cadence: cadence)
    }

    /// Format a raw current-unit value for the hero charge readout.
    /// Truncates (floors) on display so the user never sees "3.8/3.8" or "10k/10k"
    /// while still short — rounding up would imply the goal is met when it isn't.
    func format(currentUnitValue: Double) -> String {
        if let measure = workoutMeasure {
            switch measure {
            case .count: return "\(Int(currentUnitValue))"
            case .minutes: return "\(Int(currentUnitValue))"
            case .miles:
                let truncated = floor(currentUnitValue * 10) / 10
                return String(format: truncated < 10 ? "%.1f" : "%.0f", truncated)
            }
        }
        return metric.formatTruncating(value: currentUnitValue)
    }

    var unitLabel: String {
        if let measure = workoutMeasure { return measure.unit }
        return metric.unitLabel
    }

    static func workoutThresholdLabel(_ threshold: Double, entry: WorkoutTypeCatalog.Entry, measure: WorkoutMeasure) -> String {
        let name = entry.displayName.lowercased()
        switch measure {
        case .count:
            let n = Int(threshold.rounded())
            return n <= 1 ? "1 \(name) session" : "\(n) \(name) sessions"
        case .minutes:
            return "\(Int(threshold.rounded())) min \(name)"
        case .miles:
            let formatted = threshold < 10 ? String(format: "%.1f", threshold) : String(format: "%.0f", threshold)
            return "\(formatted) mi \(name)"
        }
    }

    static func workoutProse(_ threshold: Double, entry: WorkoutTypeCatalog.Entry, measure: WorkoutMeasure) -> String {
        let name = entry.displayName.lowercased()
        switch measure {
        case .count:
            let n = Int(threshold.rounded())
            return n <= 1 ? "A \(name) session every day" : "\(n)+ \(name) sessions every day"
        case .minutes:
            return "\(Int(threshold.rounded()))+ min of \(name) every day"
        case .miles:
            let formatted = threshold < 10 ? String(format: "%.1f", threshold) : String(format: "%.0f", threshold)
            return "\(formatted)+ mi of \(name) every day"
        }
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
    let earlySteps: Double
    let heartRateMinutes: Double
    /// Per-workout-type aggregate for the day (count, minutes, miles).
    /// Keys are `WorkoutTypeCatalog` keys (e.g. "running", "cycling").
    var workoutDetails: [String: WorkoutDailyStat]

    init(
        date: Date,
        steps: Double = 0,
        exerciseMinutes: Double = 0,
        standHours: Double = 0,
        activeEnergy: Double = 0,
        workoutCount: Double = 0,
        mindfulMinutes: Double = 0,
        sleepHours: Double = 0,
        distanceMiles: Double = 0,
        flightsClimbed: Double = 0,
        earlySteps: Double = 0,
        heartRateMinutes: Double = 0,
        workoutDetails: [String: WorkoutDailyStat] = [:]
    ) {
        self.date = date
        self.steps = steps
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.activeEnergy = activeEnergy
        self.workoutCount = workoutCount
        self.mindfulMinutes = mindfulMinutes
        self.sleepHours = sleepHours
        self.distanceMiles = distanceMiles
        self.flightsClimbed = flightsClimbed
        self.earlySteps = earlySteps
        self.heartRateMinutes = heartRateMinutes
        self.workoutDetails = workoutDetails
    }

    func value(for metric: StreakMetric) -> Double {
        switch metric {
        case .steps: return steps
        case .exerciseMinutes: return exerciseMinutes
        case .standHours: return standHours
        case .activeEnergy: return activeEnergy
        case .workouts: return workoutCount
        case .mindfulMinutes: return mindfulMinutes
        case .sleepHours: return sleepHours
        case .distanceMiles: return distanceMiles
        case .flightsClimbed: return flightsClimbed
        case .earlySteps: return earlySteps
        case .intensityRatio:
            return exerciseMinutes > 0 ? activeEnergy / exerciseMinutes : 0
        case .heartRateMinutes: return heartRateMinutes
        case .totalCalories: return totalCalories
        }
    }

    /// Total calories = active energy + basal (resting) energy burned
    var totalCalories: Double {
        // For now, estimate basal as roughly 70% of active for users with Apple Watch
        // or return activeEnergy * 1.4 as a reasonable estimate
        // This will be refined when we fetch actual basal energy from HealthKit
        activeEnergy * 1.4
    }
}
