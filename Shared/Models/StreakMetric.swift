import Foundation
import SwiftUI

/// The activity dimensions we mine Apple Health for.
enum StreakMetric: String, CaseIterable, Codable, Sendable, Identifiable {
    case steps
    case exerciseMinutes
    case standHours
    case activeEnergy
    case workouts           // binary "any workout on this day"
    case mindfulMinutes
    case sleepHours
    case distanceMiles
    case flightsClimbed
    case earlySteps
    case intensityRatio
    case heartRateMinutes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: String(localized: "Steps")
        case .exerciseMinutes: String(localized: "Exercise")
        case .standHours: String(localized: "Stand")
        case .activeEnergy: String(localized: "Active energy")
        case .workouts: String(localized: "Workouts")
        case .mindfulMinutes: String(localized: "Mindfulness")
        case .sleepHours: String(localized: "Sleep")
        case .distanceMiles: String(localized: "Distance")
        case .flightsClimbed: String(localized: "Flights climbed")
        case .earlySteps: String(localized: "Early Steps")
        case .intensityRatio: String(localized: "Intensity")
        case .heartRateMinutes: String(localized: "Cardio Minutes")
        }
    }

    /// The name as it reads inside a sentence ("your steps run", "deine
    /// Schritte-Serie", "seria kroków"): lowercase in English, the noun form
    /// each language needs after "streak of" / "N minutes of".
    var inlineName: String {
        switch self {
        case .steps: String(localized: "inline.steps", defaultValue: "steps")
        case .exerciseMinutes: String(localized: "inline.exercise", defaultValue: "exercise")
        case .standHours: String(localized: "inline.stand", defaultValue: "stand")
        case .activeEnergy: String(localized: "inline.activeEnergy", defaultValue: "active energy")
        case .workouts: String(localized: "inline.workouts", defaultValue: "workouts")
        case .mindfulMinutes: String(localized: "inline.mindfulness", defaultValue: "mindfulness")
        case .sleepHours: String(localized: "inline.sleep", defaultValue: "sleep")
        case .distanceMiles: String(localized: "inline.distance", defaultValue: "distance")
        case .flightsClimbed: String(localized: "inline.flightsClimbed", defaultValue: "flights climbed")
        case .earlySteps: String(localized: "inline.earlySteps", defaultValue: "early steps")
        case .intensityRatio: String(localized: "inline.intensity", defaultValue: "intensity")
        case .heartRateMinutes: String(localized: "inline.cardioMinutes", defaultValue: "cardio minutes")
        }
    }

    var symbol: String {
        switch self {
        case .steps: "figure.walk"
        case .exerciseMinutes: "figure.run"
        case .standHours: "figure.stand"
        case .activeEnergy: "flame.fill"
        case .workouts: "dumbbell.fill"
        case .mindfulMinutes: "brain.head.profile"
        case .sleepHours: "bed.double.fill"
        case .distanceMiles: "location.fill"
        case .flightsClimbed: "stairs"
        case .earlySteps: "sunrise.fill"
        case .intensityRatio: "bolt.heart.fill"
        case .heartRateMinutes: "heart.fill"
        }
    }

    var accent: Color {
        switch self {
        case .steps: Theme.accentSteps
        case .exerciseMinutes: Theme.accentExercise
        case .standHours: Theme.accentStand
        case .activeEnergy: Theme.accentEnergy
        case .workouts: Theme.accentWorkout
        case .mindfulMinutes: Theme.accentMindful
        case .sleepHours: Theme.accentSleep
        case .distanceMiles: Theme.accentDistance
        case .flightsClimbed: Theme.accentFlights
        case .earlySteps: Theme.accentEarly
        case .intensityRatio: Theme.accentIntensity
        case .heartRateMinutes: Theme.accentHeartRate
        }
    }

    /// Weight for ranking across metrics. Higher = more "flagship" streak.
    var weight: Double {
        switch self {
        case .steps: 1.2
        case .exerciseMinutes: 1.3
        case .standHours: 0.9
        case .activeEnergy: 1.1
        case .workouts: 1.25
        case .distanceMiles: 1.0
        case .flightsClimbed: 0.85
        case .mindfulMinutes: 0.85
        case .sleepHours: 0.9
        case .earlySteps: 1.0
        case .intensityRatio: 1.1
        case .heartRateMinutes: 1.15
        }
    }

    /// Daily thresholds to evaluate, ordered ascending. A user qualifies for the highest threshold their value meets.
    var dailyThresholds: [Double] {
        switch self {
        case .steps: [3_000, 5_000, 7_500, 10_000, 12_500, 15_000]
        case .exerciseMinutes: [10, 20, 30, 45, 60]
        case .standHours: [6, 8, 10, 12]
        case .activeEnergy: [200, 300, 400, 500, 700, 1_000]
        case .workouts: [1]
        case .mindfulMinutes: [1, 5, 10]
        case .sleepHours: [6, 7, 8]
        case .distanceMiles: [1, 3, 5, 8]
        case .flightsClimbed: [5, 10, 20]
        case .earlySteps: [500, 1_000, 2_000, 3_000, 5_000]
        case .intensityRatio: [5, 8, 10, 12, 15, 20]
        case .heartRateMinutes: [3, 5, 10, 15, 20, 30]
        }
    }

    var unitLabel: String {
        switch self {
        case .steps: String(localized: "unit.steps", defaultValue: "steps")
        case .exerciseMinutes: String(localized: "unit.min", defaultValue: "min")
        case .standHours: String(localized: "unit.hr", defaultValue: "hr")
        case .activeEnergy: String(localized: "unit.kcal", defaultValue: "kcal")
        case .workouts: String(localized: "unit.workout", defaultValue: "workout")
        case .mindfulMinutes: String(localized: "unit.minMindful", defaultValue: "min mindful")
        case .sleepHours: String(localized: "unit.hrSleep", defaultValue: "hr sleep")
        case .distanceMiles: String(localized: "unit.mi", defaultValue: "mi")
        case .flightsClimbed: String(localized: "unit.flights", defaultValue: "flights")
        case .earlySteps: String(localized: "unit.earlySteps", defaultValue: "early steps")
        case .intensityRatio: String(localized: "unit.kcalPerMin", defaultValue: "kcal/min")
        case .heartRateMinutes: String(localized: "unit.minCardio", defaultValue: "min cardio")
        }
    }

    /// Truncating (floor) variant — used for live "current value" displays so users
    /// never see "10k/10k" while still under the threshold. Round-up rendering of
    /// progress is misleading.
    func formatTruncating(value: Double) -> String {
        switch self {
        case .steps, .activeEnergy, .earlySteps:
            return "\(Int(floor(value)))"
        case .exerciseMinutes, .standHours, .flightsClimbed, .mindfulMinutes, .heartRateMinutes:
            return "\(Int(floor(value)))"
        case .workouts:
            return value >= 1 ? "\(Int(floor(value)))" : "0"
        case .sleepHours:
            return LocalizedNumber.fixed(floor(value * 10) / 10, digits: 1)
        case .distanceMiles:
            return LocalizedNumber.oneDecimalUnderTen(floor(value * 10) / 10)
        case .intensityRatio:
            return LocalizedNumber.fixed(floor(value * 10) / 10, digits: 1)
        }
    }

    func format(value: Double) -> String {
        switch self {
        case .steps, .activeEnergy:
            let v = Int(value.rounded())
            return "\(v)"
        case .exerciseMinutes, .standHours, .flightsClimbed, .mindfulMinutes:
            return "\(Int(value.rounded()))"
        case .workouts:
            return value >= 1 ? "\(Int(value.rounded()))" : "0"
        case .sleepHours:
            return LocalizedNumber.fixed(value, digits: 1)
        case .distanceMiles:
            return LocalizedNumber.oneDecimalUnderTen(value)
        case .earlySteps:
            let v = Int(value.rounded())
            return "\(v)"
        case .intensityRatio:
            return LocalizedNumber.fixed(value, digits: 1)
        case .heartRateMinutes:
            return "\(Int(value.rounded()))"
        }
    }

    /// Short label used in UI: e.g. "10000 steps", "30 min", "8 hr".
    func thresholdLabel(_ threshold: Double, cadence: StreakCadence) -> String {
        Self.valueLabel(self, format(value: threshold))
    }

    /// Value plus unit as one phrase, so each language orders and inflects it.
    static func valueLabel(_ metric: StreakMetric, _ v: String) -> String {
        switch metric {
        case .steps: String(localized: "\(v) steps")
        case .exerciseMinutes: String(localized: "\(v) min")
        case .standHours: String(localized: "\(v) hr")
        case .activeEnergy: String(localized: "\(v) kcal")
        case .workouts: String(localized: "any workout")
        case .mindfulMinutes: String(localized: "\(v) min mindful")
        case .sleepHours: String(localized: "\(v) hr sleep")
        case .distanceMiles: String(localized: "\(v) mi")
        case .flightsClimbed: String(localized: "\(v) flights")
        case .earlySteps: String(localized: "\(v) early steps")
        case .intensityRatio: String(localized: "\(v) kcal/min")
        case .heartRateMinutes: String(localized: "\(v) min cardio")
        }
    }

    /// Human-readable prose for the detail view, e.g. "10,000+ steps every day".
    func prose(_ threshold: Double, cadence: StreakCadence) -> String {
        let v = self == .sleepHours ? LocalizedNumber.fixed(threshold, digits: 1) : LocalizedNumber.grouped(threshold)
        switch self {
        case .steps: return String(localized: "\(v)+ steps every day")
        case .exerciseMinutes: return String(localized: "\(v)+ min every day")
        case .standHours: return String(localized: "\(v)+ hr every day")
        case .activeEnergy: return String(localized: "\(v)+ kcal every day")
        case .workouts: return String(localized: "A workout every day")
        case .mindfulMinutes: return String(localized: "\(v)+ min mindful every day")
        case .sleepHours: return String(localized: "\(v)+ hr sleep every day")
        case .distanceMiles: return String(localized: "\(v)+ mi every day")
        case .flightsClimbed: return String(localized: "\(v)+ flights every day")
        case .earlySteps: return String(localized: "\(v)+ early steps every day")
        case .intensityRatio: return String(localized: "\(v)+ kcal/min every day")
        case .heartRateMinutes: return String(localized: "\(v)+ min cardio every day")
        }
    }
}

enum StreakCadence: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly

    /// "12 days" / "3 weeks", pluralized per language.
    func count(_ n: Int) -> String {
        switch self {
        case .daily: String(localized: "\(n) days")
        case .weekly: String(localized: "\(n) weeks")
        }
    }

    /// The unit word drawn beside a separately rendered number ("12" over
    /// "DAYS"). It can't be a plural key (Xcode rejects plural variants that
    /// omit the number), so it picks one whole key per CLDR category.
    func unitWord(_ n: Int) -> String {
        switch (self, PluralLabel.category(n)) {
        case (.daily, .one): String(localized: "day")
        case (.daily, .few): String(localized: "days (few)", defaultValue: "days")
        case (.daily, .many): String(localized: "days (many)", defaultValue: "days")
        case (.daily, .other): String(localized: "days")
        case (.weekly, .one): String(localized: "week")
        case (.weekly, .few): String(localized: "weeks (few)", defaultValue: "weeks")
        case (.weekly, .many): String(localized: "weeks (many)", defaultValue: "weeks")
        case (.weekly, .other): String(localized: "weeks")
        }
    }
}

/// CLDR plural category of a count in the current language, read from the
/// catalog's `"%lld plural category"` key (its variants are "one %lld",
/// "few %lld", ...), so Polish 2-4 picks "few" without hardcoding rules.
enum PluralLabel {
    enum Category { case one, few, many, other }

    static func category(_ n: Int) -> Category {
        let raw = String(localized: "\(n) plural category")
        switch raw.split(separator: " ").first {
        case "one": return .one
        case "few": return .few
        case "many": return .many
        default: return .other
        }
    }
}
