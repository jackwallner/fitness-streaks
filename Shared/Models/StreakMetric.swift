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

    /// Lowercase form for use inside a sentence ("Your steps run ended..."). A
    /// separate key, so no language has to lowercase translated text.
    var lowerName: String {
        switch self {
        case .steps: String(localized: "steps")
        case .exerciseMinutes: String(localized: "exercise")
        case .standHours: String(localized: "stand")
        case .activeEnergy: String(localized: "active energy")
        case .workouts: String(localized: "workouts")
        case .mindfulMinutes: String(localized: "mindfulness")
        case .sleepHours: String(localized: "sleep")
        case .distanceMiles: String(localized: "distance")
        case .flightsClimbed: String(localized: "flights climbed")
        case .earlySteps: String(localized: "early steps")
        case .intensityRatio: String(localized: "intensity")
        case .heartRateMinutes: String(localized: "cardio minutes")
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
        case .flightsClimbed: "stairs" // l10n-ignore: SF Symbol name
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
        case .steps: String(localized: "steps")
        case .exerciseMinutes: String(localized: "min")
        case .standHours: String(localized: "hr")
        case .activeEnergy: String(localized: "kcal")
        case .workouts: String(localized: "workout")
        case .mindfulMinutes: String(localized: "min mindful")
        case .sleepHours: String(localized: "hr sleep")
        case .distanceMiles: String(localized: "mi")
        case .flightsClimbed: String(localized: "flights")
        case .earlySteps: String(localized: "early steps")
        case .intensityRatio: String(localized: "kcal/min")
        case .heartRateMinutes: String(localized: "min cardio")
        }
    }

    /// Truncating (floor) variant. Used for live "current value" displays so users
    /// never see "10k/10k" while still under the threshold. Round-up rendering of
    /// progress is misleading.
    func formatTruncating(value: Double) -> String {
        switch self {
        case .steps, .activeEnergy, .earlySteps:
            return Int(floor(value)).plain
        case .exerciseMinutes, .standHours, .flightsClimbed, .mindfulMinutes, .heartRateMinutes:
            return Int(floor(value)).plain
        case .workouts:
            return value >= 1 ? Int(floor(value)).plain : 0.plain
        case .sleepHours:
            let truncated = floor(value * 10) / 10
            return truncated.plain(fractionDigits: 1)
        case .distanceMiles:
            let truncated = floor(value * 10) / 10
            return truncated.plain(fractionDigits: truncated < 10 ? 1 : 0)
        case .intensityRatio:
            let truncated = floor(value * 10) / 10
            return truncated.plain(fractionDigits: 1)
        }
    }

    func format(value: Double) -> String {
        switch self {
        case .steps, .activeEnergy:
            return Int(value.rounded()).plain
        case .exerciseMinutes, .standHours, .flightsClimbed, .mindfulMinutes:
            return Int(value.rounded()).plain
        case .workouts:
            return value >= 1 ? Int(value.rounded()).plain : 0.plain
        case .sleepHours:
            return value.plain(fractionDigits: 1)
        case .distanceMiles:
            return value.plain(fractionDigits: value < 10 ? 1 : 0)
        case .earlySteps:
            return Int(value.rounded()).plain
        case .intensityRatio:
            return value.plain(fractionDigits: 1)
        case .heartRateMinutes:
            return Int(value.rounded()).plain
        }
    }

    /// A formatted number with this metric's unit, e.g. "10000 steps", "30 min".
    func amount(_ number: String) -> String {
        switch self {
        case .steps: String(localized: "\(number) steps")
        case .exerciseMinutes: String(localized: "\(number) min")
        case .standHours: String(localized: "\(number) hr")
        case .activeEnergy: String(localized: "\(number) kcal")
        case .workouts: String(localized: "\(number) workout")
        case .mindfulMinutes: String(localized: "\(number) min mindful")
        case .sleepHours: String(localized: "\(number) hr sleep")
        case .distanceMiles: String(localized: "\(number) mi")
        case .flightsClimbed: String(localized: "\(number) flights")
        case .earlySteps: String(localized: "\(number) early steps")
        case .intensityRatio: String(localized: "\(number) kcal/min")
        case .heartRateMinutes: String(localized: "\(number) min cardio")
        }
    }

    /// Short label used in UI: e.g. "10k steps", "30 min", "8 hr".
    func thresholdLabel(_ threshold: Double, cadence: StreakCadence) -> String {
        switch self {
        case .workouts:
            return String(localized: "any workout")
        default:
            return amount(format(value: threshold))
        }
    }

    /// Human-readable prose for the detail view, e.g. "10,000+ steps every day".
    func prose(_ threshold: Double, cadence: StreakCadence) -> String {
        let number = formatWithCommas(threshold)
        switch self {
        case .steps: return String(localized: "\(number)+ steps every day")
        case .exerciseMinutes: return String(localized: "\(number)+ min every day")
        case .standHours: return String(localized: "\(number)+ hr every day")
        case .activeEnergy: return String(localized: "\(number)+ kcal every day")
        case .workouts: return String(localized: "A workout every day")
        case .mindfulMinutes: return String(localized: "\(number)+ min mindful every day")
        case .sleepHours: return String(localized: "\(number)+ hr sleep every day")
        case .distanceMiles: return String(localized: "\(number)+ mi every day")
        case .flightsClimbed: return String(localized: "\(number)+ flights every day")
        case .earlySteps: return String(localized: "\(number)+ early steps every day")
        case .intensityRatio: return String(localized: "\(number)+ kcal/min every day")
        case .heartRateMinutes: return String(localized: "\(number)+ min cardio every day")
        }
    }

    /// Prose for a streak confined to one hour of the day, e.g.
    /// "1,000+ steps every day between 5p-6p". Hour windows only apply to
    /// whole-day metrics, but every metric gets a sentence so none falls back
    /// to spliced fragments.
    func proseInWindow(_ threshold: Double, window: String) -> String {
        let number = formatWithCommas(threshold)
        switch self {
        case .steps: return String(localized: "\(number)+ steps every day between \(window)")
        case .exerciseMinutes: return String(localized: "\(number)+ min every day between \(window)")
        case .standHours: return String(localized: "\(number)+ hr every day between \(window)")
        case .activeEnergy: return String(localized: "\(number)+ kcal every day between \(window)")
        case .workouts: return String(localized: "A workout every day between \(window)")
        case .mindfulMinutes: return String(localized: "\(number)+ min mindful every day between \(window)")
        case .sleepHours: return String(localized: "\(number)+ hr sleep every day between \(window)")
        case .distanceMiles: return String(localized: "\(number)+ mi every day between \(window)")
        case .flightsClimbed: return String(localized: "\(number)+ flights every day between \(window)")
        case .earlySteps: return String(localized: "\(number)+ early steps every day between \(window)")
        case .intensityRatio: return String(localized: "\(number)+ kcal/min every day between \(window)")
        case .heartRateMinutes: return String(localized: "\(number)+ min cardio every day between \(window)")
        }
    }

    private func formatWithCommas(_ value: Double) -> String {
        switch self {
        case .sleepHours: return value.plain(fractionDigits: 1)
        default:
            return value.formatted(.number.precision(.fractionLength(0)))
        }
    }
}

enum StreakCadence: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly

    var label: String {
        switch self {
        case .daily: String(localized: "day")
        case .weekly: String(localized: "week")
        }
    }

    var pluralLabel: String {
        switch self {
        case .daily: String(localized: "days")
        case .weekly: String(localized: "weeks")
        }
    }

    /// "5 days" / "3 weeks", with a real singular and each language's plural forms.
    func count(_ n: Int) -> String {
        switch self {
        case .daily: String(localized: "\(n) days")
        case .weekly: String(localized: "\(n) weeks")
        }
    }
}

// MARK: - Number formatting

extension BinaryInteger {
    /// Locale-aware digits with no grouping separator, the old `"\(n)"`.
    var plain: String { Int(self).formatted(.number.grouping(.never)) }
}

extension Double {
    /// Locale-aware decimal with a fixed number of fraction digits and no
    /// grouping separator, the old `String(format: "%.1f", x)`.
    func plain(fractionDigits: Int) -> String {
        formatted(.number.grouping(.never).precision(.fractionLength(fractionDigits)))
    }
}
