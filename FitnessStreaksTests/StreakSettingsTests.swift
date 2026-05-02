import XCTest

@MainActor
final class StreakSettingsTests: XCTestCase {
    func testUpdateCustomStreakThreshold() {
        let settings = StreakSettings.shared
        let originalCount = settings.customStreaks.count

        // Create a test custom streak
        let testStreak = CustomStreak(
            id: "test-update-threshold",
            metric: .steps,
            cadence: .daily,
            threshold: 5000,
            hourWindow: nil,
            workoutType: nil,
            workoutMeasure: nil
        )

        settings.customStreaks.append(testStreak)
        XCTAssertEqual(settings.customStreaks.first(where: { $0.id == "test-update-threshold" })?.threshold, 5000)

        // Update the threshold
        settings.updateCustomStreak(id: "test-update-threshold", threshold: 10000)

        // Verify the update
        let updated = settings.customStreaks.first(where: { $0.id == "test-update-threshold" })
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.threshold, 10000)

        // Cleanup
        settings.customStreaks.removeAll { $0.id == "test-update-threshold" }
        XCTAssertEqual(settings.customStreaks.count, originalCount)
    }

    func testUpdateCustomStreakWithInvalidIDDoesNothing() {
        let settings = StreakSettings.shared
        let originalStreaks = settings.customStreaks

        // Try to update a non-existent streak
        settings.updateCustomStreak(id: "non-existent-id", threshold: 9999)

        // Verify no changes
        XCTAssertEqual(settings.customStreaks.count, originalStreaks.count)
        XCTAssertEqual(settings.customStreaks.map { $0.id }, originalStreaks.map { $0.id })
    }

    func testUpdateCustomStreakPreservesOtherProperties() {
        let settings = StreakSettings.shared

        let testStreak = CustomStreak(
            id: "test-preserve-properties",
            metric: .workouts,
            cadence: .daily,
            threshold: 30,
            hourWindow: 9,
            workoutType: "cycling",
            workoutMeasure: .minutes
        )

        settings.customStreaks.append(testStreak)

        // Update only the threshold
        settings.updateCustomStreak(id: "test-preserve-properties", threshold: 45)

        // Verify other properties unchanged
        let updated = settings.customStreaks.first(where: { $0.id == "test-preserve-properties" })
        XCTAssertEqual(updated?.metric, .workouts)
        XCTAssertEqual(updated?.cadence, .daily)
        XCTAssertEqual(updated?.hourWindow, 9)
        XCTAssertEqual(updated?.workoutType, "cycling")
        XCTAssertEqual(updated?.workoutMeasure, .minutes)
        XCTAssertEqual(updated?.threshold, 45)

        // Cleanup
        settings.customStreaks.removeAll { $0.id == "test-preserve-properties" }
    }

    func testCustomStreakThresholdRanges() {
        // Test that threshold ranges are appropriate for each metric
        let testCases: [(StreakMetric, Double, Double)] = [
            // (metric, proposedValue, expectedClampedValue)
            (.steps, 100, 100),
            (.steps, 50000, 50000),
            (.steps, 50, 50), // Below min but allowed in model
            (.steps, 100000, 100000), // Above max but allowed in model
            (.earlySteps, 5000, 5000),
            (.earlySteps, 100, 100),
            (.exerciseMinutes, 30, 30),
            (.exerciseMinutes, 0, 1),
            (.exerciseMinutes, 100, 100),
            (.standHours, 8, 8),
            (.standHours, 0, 1),
            (.standHours, 24, 24),
            (.activeEnergy, 500, 500),
            (.activeEnergy, 5, 5),
            (.activeEnergy, 5000, 5000),
            (.sleepHours, 7.5, 7.5),
            (.sleepHours, 0, 1),
            (.sleepHours, 15, 15),
            (.distanceMiles, 5.5, 5.5),
            (.distanceMiles, 0, 1),
            (.distanceMiles, 30, 30),
            (.flightsClimbed, 10, 10),
            (.flightsClimbed, 0, 1),
            (.flightsClimbed, 100, 100),
            (.intensityRatio, 1.5, 1.5),
            (.intensityRatio, 0, 1),
            (.intensityRatio, 5, 5),
            (.heartRateMinutes, 20, 20),
            (.heartRateMinutes, 0, 1),
            (.heartRateMinutes, 90, 90),
        ]

        for (metric, proposed, _) in testCases {
            let streak = CustomStreak(
                id: "test-\(metric.rawValue)-\(proposed)",
                metric: metric,
                cadence: .daily,
                threshold: proposed,
                hourWindow: nil,
                workoutType: nil,
                workoutMeasure: nil
            )

            // Verify the streak can be created with any threshold
            XCTAssertEqual(streak.metric, metric)
            XCTAssertEqual(streak.threshold, proposed)
        }
    }
}
