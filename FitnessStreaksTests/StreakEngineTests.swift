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

    func testWeeklyStreakContinuesThroughIncompleteCurrentWeek() {
        let now = day(2026, 4, 26)
        let thisWeek = DateHelpers.startOfWeek(now)
        let lastWeek = DateHelpers.addWeeks(-1, to: thisWeek)
        let twoWeeksAgo = DateHelpers.addWeeks(-2, to: thisWeek)
        let history = [
            activity(twoWeeksAgo, steps: 36_000),
            activity(lastWeek, steps: 40_000),
            activity(thisWeek, steps: 10_000),
        ]
        let totals = StreakEngine.weeklyTotals(for: .steps, byDay: Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) }))

        let streak = StreakEngine.computeWeeklyStreak(
            metric: .steps,
            threshold: 35_000,
            weekTotals: totals,
            thisWeek: thisWeek
        )

        XCTAssertEqual(streak.current, 2)
        XCTAssertFalse(streak.currentUnitCompleted)
        XCTAssertEqual(streak.currentUnitValue, 10_000)
    }

    func testTrackedFilteringAndSnapshotUseFilteredStreaks() {
        let steps = streak(metric: .steps, cadence: .daily, threshold: 3_000, current: 5)
        let workouts = streak(metric: .workouts, cadence: .weekly, threshold: 3, current: 4)

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
