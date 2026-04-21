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
        flightsClimbed: Double = 0
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
        self.lastUpdated = Date()
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
            flightsClimbed: flightsClimbed
        )
    }
}
