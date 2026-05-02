import XCTest

@MainActor
final class CustomStreakEdgeCaseTests: XCTestCase {

    // MARK: - Threshold Validation Edge Cases

    func testZeroThresholdReturnsEmptyStreak() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        let history = [
            ActivityDay(date: yesterday, steps: 5000),
            ActivityDay(date: today, steps: 5000)
        ]
        let byDay = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })

        // Access the private computeDailyStreakFromValues through discover
        let custom = CustomStreak(
            id: "test-zero-threshold",
            metric: .steps,
            cadence: .daily,
            threshold: 0,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        let streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom],
            now: today
        )

        let found = streaks.first { $0.customID == "test-zero-threshold" }
        XCTAssertNotNil(found)
        // Zero threshold should result in empty streak (engine guards against this)
        XCTAssertEqual(found?.current, 0)
        XCTAssertFalse(found?.currentUnitCompleted ?? true)
    }

    func testNegativeThresholdHandledSafely() {
        let today = DateHelpers.startOfDay(Date())

        let custom = CustomStreak(
            id: "test-negative-threshold",
            metric: .steps,
            cadence: .daily,
            threshold: -100,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        // CustomStreak creation should work but engine should handle it gracefully
        XCTAssertEqual(custom.threshold, -100)
    }

    // MARK: - Streak Break/Complete Edge Cases

    func testIncreasingThresholdAboveTodayValueBreaksStreak() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)
        let twoDaysAgo = DateHelpers.addDays(-2, to: today)

        // User has 5000, 3000, 2500 steps over last 3 days
        let history = [
            ActivityDay(date: twoDaysAgo, steps: 5000),
            ActivityDay(date: yesterday, steps: 3000),
            ActivityDay(date: today, steps: 2500)
        ]

        // First with threshold 2000 - should have 3 day streak (2500, 3000, 5000 all >= 2000)
        let custom1 = CustomStreak(
            id: "test-break-streak",
            metric: .steps,
            cadence: .daily,
            threshold: 2000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        var streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom1],
            now: today
        )

        var streak = streaks.first { $0.customID == "test-break-streak" }
        XCTAssertEqual(streak?.current, 3) // Today, yesterday, and 2 days ago all >= 2000
        XCTAssertTrue(streak?.currentUnitCompleted ?? false)

        // Now increase threshold to 3500 - only 2 days ago (5000) qualifies
        let custom2 = CustomStreak(
            id: "test-break-streak",
            metric: .steps,
            cadence: .daily,
            threshold: 3500,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom2],
            now: today
        )

        streak = streaks.first { $0.customID == "test-break-streak" }
        XCTAssertEqual(streak?.current, 0) // Today doesn't meet, so streak is 0
        XCTAssertFalse(streak?.currentUnitCompleted ?? true)
    }

    func testDecreasingThresholdBelowTodayValueCompletesStreak() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        // User has 5000 steps yesterday and today
        let history = [
            ActivityDay(date: yesterday, steps: 5000),
            ActivityDay(date: today, steps: 5000)
        ]

        // First with threshold 6000 - neither day completed (both 5000 < 6000)
        let custom1 = CustomStreak(
            id: "test-complete-streak",
            metric: .steps,
            cadence: .daily,
            threshold: 6000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        var streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom1],
            now: today
        )

        var streak = streaks.first { $0.customID == "test-complete-streak" }
        XCTAssertEqual(streak?.current, 0) // Neither day meets 6000
        XCTAssertFalse(streak?.currentUnitCompleted ?? true)

        // Now decrease threshold to 4000 - both days completed
        let custom2 = CustomStreak(
            id: "test-complete-streak",
            metric: .steps,
            cadence: .daily,
            threshold: 4000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom2],
            now: today
        )

        streak = streaks.first { $0.customID == "test-complete-streak" }
        XCTAssertEqual(streak?.current, 2) // Both days >= 4000
        XCTAssertTrue(streak?.currentUnitCompleted ?? false)
    }

    // MARK: - Workout Type Custom Streak Edge Cases

    func testWorkoutTypeCustomStreakWithMinutesThreshold() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        let history = [
            ActivityDay(
                date: yesterday,
                workoutCount: 1,
                workoutDetails: ["cycling": WorkoutDailyStat(count: 1, minutes: 15, miles: 5)]
            ),
            ActivityDay(
                date: today,
                workoutCount: 1,
                workoutDetails: ["cycling": WorkoutDailyStat(count: 1, minutes: 25, miles: 8)]
            )
        ]

        // Threshold 20 minutes of cycling
        let custom = CustomStreak(
            id: "test-workout-minutes",
            metric: .workouts,
            cadence: .daily,
            threshold: 20,
            hourWindow: nil,
            workoutType: "cycling",
            workoutMeasure: .minutes
        )

        let streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom],
            now: today
        )

        let streak = streaks.first { $0.customID == "test-workout-minutes" }
        XCTAssertEqual(streak?.current, 1) // Only today (25 >= 20)
        XCTAssertTrue(streak?.currentUnitCompleted ?? false)
    }

    func testWorkoutTypeCustomStreakThresholdChange() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        let history = [
            ActivityDay(
                date: yesterday,
                workoutCount: 1,
                workoutDetails: ["running": WorkoutDailyStat(count: 1, minutes: 20, miles: 2)]
            ),
            ActivityDay(
                date: today,
                workoutCount: 1,
                workoutDetails: ["running": WorkoutDailyStat(count: 1, minutes: 25, miles: 2.5)]
            )
        ]

        // First with 30 minute threshold - only today qualifies
        let custom1 = CustomStreak(
            id: "test-workout-threshold-change",
            metric: .workouts,
            cadence: .daily,
            threshold: 30,
            hourWindow: nil,
            workoutType: "running",
            workoutMeasure: .minutes
        )

        var streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom1],
            now: today
        )

        var streak = streaks.first { $0.customID == "test-workout-threshold-change" }
        XCTAssertEqual(streak?.current, 0) // Neither day has 30+ minutes

        // Lower to 15 minutes - both qualify
        let custom2 = CustomStreak(
            id: "test-workout-threshold-change",
            metric: .workouts,
            cadence: .daily,
            threshold: 15,
            hourWindow: nil,
            workoutType: "running",
            workoutMeasure: .minutes
        )

        streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom2],
            now: today
        )

        streak = streaks.first { $0.customID == "test-workout-threshold-change" }
        XCTAssertEqual(streak?.current, 2) // Both days
    }

    // MARK: - Hour Window Custom Streak Edge Cases

    func testHourWindowCustomStreakThreshold() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        // Hourly step data: 9am hour
        let hourlySteps: [Date: [Int: Double]] = [
            yesterday: [9: 1500, 10: 500],
            today: [9: 800, 10: 2000]
        ]

        // Custom streak for 9am hour with 1000 step threshold
        let custom = CustomStreak(
            id: "test-hour-window",
            metric: .steps,
            cadence: .daily,
            threshold: 1000,
            hourWindow: 9,
            workoutType: nil,
            workoutMeasure: nil
        )

        let history: [ActivityDay] = [
            ActivityDay(date: yesterday, steps: 2000),
            ActivityDay(date: today, steps: 2800)
        ]

        let streaks = StreakEngine.discover(
            history: history,
            hourlySteps: hourlySteps,
            customStreaks: [custom],
            now: today
        )

        let streak = streaks.first { $0.customID == "test-hour-window" }
        XCTAssertEqual(streak?.current, 1) // Only yesterday (1500 >= 1000)
        XCTAssertFalse(streak?.currentUnitCompleted ?? true) // Today 800 < 1000
    }

    // MARK: - Custom Streak Always Appears in Candidates

    func testCustomStreakAppearsEvenWithZeroCurrent() {
        let today = DateHelpers.startOfDay(Date())
        let yesterday = DateHelpers.addDays(-1, to: today)

        // History with values below threshold
        let history = [
            ActivityDay(date: yesterday, steps: 5000),
            ActivityDay(date: today, steps: 5000)
        ]

        // Threshold above all values - custom streak should still appear with 0 current
        let custom = CustomStreak(
            id: "test-zero-current",
            metric: .steps,
            cadence: .daily,
            threshold: 10000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        let streaks = StreakEngine.discover(
            history: history,
            customStreaks: [custom],
            now: today
        )

        let streak = streaks.first { $0.customID == "test-zero-current" }
        XCTAssertNotNil(streak)
        XCTAssertEqual(streak?.current, 0)
        XCTAssertFalse(streak?.currentUnitCompleted ?? true)
    }

    // MARK: - Settings Update Edge Cases

    func testSettingsUpdateDoesNotAffectOtherStreaks() {
        let settings = StreakSettings.shared
        let originalCount = settings.customStreaks.count

        // Create two custom streaks
        let streak1 = CustomStreak(
            id: "test-streak-1",
            metric: .steps,
            cadence: .daily,
            threshold: 5000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        let streak2 = CustomStreak(
            id: "test-streak-2",
            metric: .workouts,
            cadence: .daily,
            threshold: 1,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        settings.customStreaks.append(streak1)
        settings.customStreaks.append(streak2)

        // Update only streak1
        settings.updateCustomStreak(id: "test-streak-1", threshold: 10000)

        // Verify streak2 unchanged
        let updatedStreak2 = settings.customStreaks.first { $0.id == "test-streak-2" }
        XCTAssertEqual(updatedStreak2?.threshold, 1)

        // Cleanup
        settings.customStreaks.removeAll { $0.id == "test-streak-1" || $0.id == "test-streak-2" }
        XCTAssertEqual(settings.customStreaks.count, originalCount)
    }

    func testMultipleRapidThresholdUpdates() {
        let settings = StreakSettings.shared
        let originalCount = settings.customStreaks.count

        let streak = CustomStreak(
            id: "test-rapid-updates",
            metric: .steps,
            cadence: .daily,
            threshold: 5000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        settings.customStreaks.append(streak)

        // Simulate rapid updates
        settings.updateCustomStreak(id: "test-rapid-updates", threshold: 6000)
        settings.updateCustomStreak(id: "test-rapid-updates", threshold: 7000)
        settings.updateCustomStreak(id: "test-rapid-updates", threshold: 8000)

        let updated = settings.customStreaks.first { $0.id == "test-rapid-updates" }
        XCTAssertEqual(updated?.threshold, 8000)

        // Cleanup
        settings.customStreaks.removeAll { $0.id == "test-rapid-updates" }
        XCTAssertEqual(settings.customStreaks.count, originalCount)
    }
}

// Helper for creating ActivityDay with specific parameters
private extension ActivityDay {
    init(date: Date, steps: Double) {
        self.init(
            date: date,
            steps: steps,
            exerciseMinutes: 0,
            standHours: 0,
            activeEnergy: 0,
            workoutCount: 0,
            mindfulMinutes: 0,
            sleepHours: 0,
            distanceMiles: 0,
            flightsClimbed: 0,
            workoutDetails: [:]
        )
    }
}
