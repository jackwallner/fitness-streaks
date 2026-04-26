import XCTest

final class StreakEngineTests: XCTestCase {
    func testDailyStreakContinuesThroughIncompleteCurrentDay() {
        let today = day(2026, 4, 26)
        let yesterday = DateHelpers.addDays(-1, to: today)
        let twoDaysAgo = DateHelpers.addDays(-2, to: today)
        let byDay = Dictionary(uniqueKeysWithValues: [
            activity(twoDaysAgo, steps: 4_000),
            activity(yesterday, steps: 3_500),
            activity(today, steps: 2_000),
        ].map { ($0.date, $0) })

        let streak = StreakEngine.computeDailyStreak(
            metric: .steps,
            threshold: 3_000,
            byDay: byDay,
            today: today
        )

        XCTAssertEqual(streak.current, 2)
        XCTAssertFalse(streak.currentUnitCompleted)
        XCTAssertEqual(streak.currentUnitValue, 2_000)
    }

    func testTrackedFilteringAndSnapshotUseFilteredStreaks() {
        let steps = streak(metric: .steps, cadence: .daily, threshold: 3_000, current: 5)
        let workouts = streak(metric: .workouts, cadence: .daily, threshold: 1, current: 4)

        let filtered = StreakStore.applyTrackedFilter([steps, workouts], tracked: [workouts.trackingKey])
        let snapshot = StreakEngine.snapshot(from: filtered)

        XCTAssertEqual(filtered, [workouts])
        XCTAssertEqual(snapshot.hero?.metric, StreakMetric.workouts.rawValue)
        XCTAssertTrue(snapshot.badges.isEmpty)
    }

    func testHiddenMetricsAreExcludedFromDiscovery() {
        let today = day(2026, 4, 26)
        let history = (0..<7).map { offset in
            activity(DateHelpers.addDays(-offset, to: today), steps: 10_000)
        }

        let discovered = StreakEngine.discover(
            history: history,
            hiddenMetrics: [.steps],
            vibe: .challenging,
            now: today
        )

        XCTAssertFalse(discovered.contains { $0.metric == .steps })
    }

    func testHourWindowVibeScoreUsesHourlyThresholdTiers() {
        let low = streak(metric: .steps, cadence: .daily, threshold: 250, current: 6, window: HourWindow(startHour: 10))
        let high = streak(metric: .steps, cadence: .daily, threshold: 3_000, current: 6, window: HourWindow(startHour: 11))

        XCTAssertGreaterThan(
            StreakEngine.vibeScore(high, vibe: .lifeChanging),
            StreakEngine.vibeScore(low, vibe: .lifeChanging)
        )
    }

    func testCompletionRatePicksThresholdMatchingVibe() {
        let today = day(2026, 4, 26)
        // 10 days: first 5 at 15k, next 3 at 10k, last 2 at 2k
        let history = (0..<10).map { offset -> ActivityDay in
            let steps: Double
            if offset < 5 { steps = 15_000 }
            else if offset < 8 { steps = 10_000 }
            else { steps = 2_000 }
            return activity(DateHelpers.addDays(-offset, to: today), steps: steps)
        }

        // Sustainable (80% target) → 10k hit on 8/10 days = 80%
        let sustainable = StreakEngine.discover(history: history, vibe: .sustainable, now: today)
        let sSust = sustainable.first { $0.metric == .steps }
        XCTAssertEqual(sSust?.threshold, 10_000)

        // Life-changing (50% target) → 15k hit on 5/10 days = 50%
        let lifeChanging = StreakEngine.discover(history: history, vibe: .lifeChanging, now: today)
        let sLife = lifeChanging.first { $0.metric == .steps }
        XCTAssertEqual(sLife?.threshold, 15_000)
    }

    func testCircularHourDistanceTreatsMidnightAsAdjacent() {
        XCTAssertEqual(StreakEngine.circularHourDistance(23, 0), 1)
        XCTAssertEqual(StreakEngine.circularHourDistance(22, 1), 3)
    }

    func testSleepHoursMergeOverlappingIntervals() {
        let sleepDay = day(2026, 4, 26)
        let previousNight = DateHelpers.addDays(-1, to: sleepDay)
        let start = DateHelpers.gregorian.date(bySettingHour: 22, minute: 0, second: 0, of: previousNight)!
        let overlapStart = DateHelpers.gregorian.date(bySettingHour: 23, minute: 0, second: 0, of: previousNight)!
        let overlapEnd = DateHelpers.gregorian.date(bySettingHour: 5, minute: 0, second: 0, of: sleepDay)!
        let end = DateHelpers.gregorian.date(bySettingHour: 6, minute: 0, second: 0, of: sleepDay)!

        let totals = HealthKitService.mergedHoursByDay(
            intervals: [(start, end), (overlapStart, overlapEnd)],
            start: previousNight,
            end: DateHelpers.addDays(1, to: sleepDay)
        )

        XCTAssertEqual(totals[sleepDay] ?? 0, 8, accuracy: 0.001)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        DateHelpers.gregorian.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func activity(
        _ date: Date,
        steps: Double = 0,
        exerciseMinutes: Double = 0,
        standHours: Double = 0,
        activeEnergy: Double = 0,
        workoutCount: Double = 0,
        mindfulMinutes: Double = 0,
        sleepHours: Double = 0,
        distanceMiles: Double = 0,
        flightsClimbed: Double = 0
    ) -> ActivityDay {
        ActivityDay(
            date: DateHelpers.startOfDay(date),
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

    private func streak(
        metric: StreakMetric,
        cadence: StreakCadence,
        threshold: Double,
        current: Int,
        window: HourWindow? = nil,
        currentUnitCompleted: Bool = false,
        currentUnitValue: Double = 0
    ) -> Streak {
        Streak(
            metric: metric,
            cadence: cadence,
            threshold: threshold,
            window: window,
            current: current,
            best: current,
            startDate: nil,
            lastHitDate: nil,
            currentUnitCompleted: currentUnitCompleted,
            currentUnitProgress: threshold > 0 ? min(currentUnitValue / threshold, 10) : 0,
            currentUnitValue: currentUnitValue
        )
    }
}
