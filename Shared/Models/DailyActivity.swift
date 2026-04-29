import Foundation
import SwiftData

/// SwiftData cache of one day of HealthKit samples. Written by the app/watch, read by widgets.
@Model
final class DailyActivity {
    @Attribute(.unique) var dateString: String
    var date: Date
    var steps: Double
    var exerciseMinutes: Double
    var standHours: Double
    var activeEnergy: Double
    var workoutCount: Double
    var mindfulMinutes: Double
    var sleepHours: Double
    var distanceMiles: Double
    var flightsClimbed: Double
    var earlySteps: Double
    var heartRateMinutes: Double
    /// JSON blob of `[String: WorkoutDailyStat]` keyed by workout-type catalog key.
    /// Optional + JSON-encoded so adding/removing fields does not require a SwiftData migration.
    var workoutDetailsJSON: String?
    var lastUpdated: Date

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
        let normalized = DateHelpers.startOfDay(date)
        self.dateString = DateHelpers.dayKey(normalized)
        self.date = normalized
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
        self.workoutDetailsJSON = Self.encodeDetails(workoutDetails)
        self.lastUpdated = Date()
    }

    var workoutDetails: [String: WorkoutDailyStat] {
        get { Self.decodeDetails(workoutDetailsJSON) }
        set { workoutDetailsJSON = Self.encodeDetails(newValue) }
    }

    func asActivityDay() -> ActivityDay {
        ActivityDay(
            date: date,
            steps: steps,
            exerciseMinutes: exerciseMinutes,
            standHours: standHours,
            activeEnergy: activeEnergy,
            workoutCount: workoutCount,
            mindfulMinutes: mindfulMinutes,
            sleepHours: sleepHours,
            distanceMiles: distanceMiles,
            flightsClimbed: flightsClimbed,
            earlySteps: earlySteps,
            heartRateMinutes: heartRateMinutes,
            workoutDetails: workoutDetails
        )
    }

    private static func encodeDetails(_ details: [String: WorkoutDailyStat]) -> String? {
        guard !details.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(details) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeDetails(_ json: String?) -> [String: WorkoutDailyStat] {
        guard let json, let data = json.data(using: .utf8) else { return [:] }
        return (try? JSONDecoder().decode([String: WorkoutDailyStat].self, from: data)) ?? [:]
    }
}
