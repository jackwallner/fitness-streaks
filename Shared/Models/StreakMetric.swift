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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .steps: "Steps"
        case .exerciseMinutes: "Exercise"
        case .standHours: "Stand"
        case .activeEnergy: "Active energy"
        case .workouts: "Workouts"
        case .mindfulMinutes: "Mindfulness"
        case .sleepHours: "Sleep"
        case .distanceMiles: "Distance"
        case .flightsClimbed: "Flights climbed"
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
        }
    }

    /// Weekly totals (sum across the week) to evaluate. `nil` = no weekly cadence surfaced.
    var weeklyThresholds: [Double]? {
        switch self {
        case .steps: [35_000, 50_000, 70_000, 100_000]
        case .exerciseMinutes: [75, 100, 150, 200, 300]
        case .standHours: [42, 56, 70]
        case .activeEnergy: [1_500, 2_000, 3_000, 4_000, 5_000]
        case .workouts: [2, 3, 4, 5, 7]
        case .mindfulMinutes: [10, 30, 60]
        case .sleepHours: [42, 49, 56]
        case .distanceMiles: [10, 20, 30, 50]
        case .flightsClimbed: [25, 50, 100]
        }
    }

    var unitLabel: String {
        switch self {
        case .steps: "steps"
        case .exerciseMinutes: "min"
        case .standHours: "hr"
        case .activeEnergy: "kcal"
        case .workouts: "workout"
        case .mindfulMinutes: "min mindful"
        case .sleepHours: "hr sleep"
        case .distanceMiles: "mi"
        case .flightsClimbed: "flights"
        }
    }

    func format(value: Double) -> String {
        switch self {
        case .steps, .activeEnergy:
            let v = Int(value.rounded())
            if v >= 1000 {
                let k = Double(v) / 1000.0
                return String(format: k.truncatingRemainder(dividingBy: 1) == 0 ? "%.0fk" : "%.1fk", k)
            }
            return "\(v)"
        case .exerciseMinutes, .standHours, .flightsClimbed, .mindfulMinutes:
            return "\(Int(value.rounded()))"
        case .workouts:
            return value >= 1 ? "\(Int(value.rounded()))" : "0"
        case .sleepHours:
            return String(format: "%.1f", value)
        case .distanceMiles:
            return String(format: value < 10 ? "%.1f" : "%.0f", value)
        }
    }

    /// Short label used in UI: e.g. "10k steps", "30 min", "8 hr".
    func thresholdLabel(_ threshold: Double, cadence: StreakCadence) -> String {
        switch self {
        case .workouts:
            if cadence == .daily { return "any workout" }
            let n = Int(threshold.rounded())
            return n == 1 ? "1 workout/wk" : "\(n) workouts/wk"
        default:
            let v = format(value: threshold)
            switch cadence {
            case .daily: return "\(v) \(unitLabel)"
            case .weekly: return "\(v) \(unitLabel)/wk"
            }
        }
    }

    /// Human-readable prose for the detail view, e.g. "10,000+ steps every day" or "100+ exercise minutes each week".
    func prose(_ threshold: Double, cadence: StreakCadence) -> String {
        switch (self, cadence) {
        case (.workouts, .daily):
            return "A workout every day"
        case (.workouts, .weekly):
            let n = Int(threshold.rounded())
            return n == 1 ? "A workout every week" : "\(n)+ workouts every week"
        default:
            let formatted = formatWithCommas(threshold)
            switch cadence {
            case .daily: return "\(formatted)+ \(unitLabel) every day"
            case .weekly: return "\(formatted)+ \(unitLabel) every week"
            }
        }
    }

    private func formatWithCommas(_ value: Double) -> String {
        switch self {
        case .sleepHours: return String(format: "%.1f", value)
        default:
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.maximumFractionDigits = 0
            return nf.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
    }
}

enum StreakCadence: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly

    var label: String {
        switch self {
        case .daily: "day"
        case .weekly: "week"
        }
    }

    var pluralLabel: String {
        switch self {
        case .daily: "days"
        case .weekly: "weeks"
        }
    }
}
