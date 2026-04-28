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

        // Sustainable test data: 8 of 10 days at 10k (today included), last 2 at 2k.
        // 80% completion at 10k; current streak = 8.
        let historySust = (0..<10).map { offset -> ActivityDay in
            let steps: Double = offset < 8 ? 10_000 : 2_000
            return activity(DateHelpers.addDays(-offset, to: today), steps: steps)
        }
        let sustainable = StreakEngine.discover(history: historySust, vibe: .sustainable, now: today)
        let sSust = sustainable.first { $0.metric == .steps }
        XCTAssertEqual(sSust?.threshold, 10_000)
        XCTAssertEqual(sSust?.completionRate ?? 0, 0.80, accuracy: 0.001)

        // Life-changing test data: 5 of 10 days at 15k (today included), rest at 1000.
        // 50% completion at 15k; current streak = 5.
        let historyLife = (0..<10).map { offset -> ActivityDay in
            let steps: Double = offset < 5 ? 15_000 : 1_000
            return activity(DateHelpers.addDays(-offset, to: today), steps: steps)
        }
        let lifeChanging = StreakEngine.discover(history: historyLife, vibe: .lifeChanging, now: today)
        let sLife = lifeChanging.first { $0.metric == .steps }
        XCTAssertEqual(sLife?.threshold, 15_000)
        XCTAssertEqual(sLife?.completionRate ?? 0, 0.50, accuracy: 0.001)
    }

    func testEarlyStepsDiscoveredFromHistory() {
        let today = day(2026, 4, 26)
        // 5 of 7 days meet 1000 early steps → 71% completion, within challenging tolerance (55-75%)
        let history = (0..<7).map { offset -> ActivityDay in
            let early: Double = offset < 5 ? 1_500 : 200
            return activity(DateHelpers.addDays(-offset, to: today), steps: 10_000, earlySteps: early)
        }

        let discovered = StreakEngine.discover(history: history, vibe: .challenging, now: today)
        let early = discovered.first { $0.metric == StreakMetric.earlySteps }
        XCTAssertNotNil(early)
        XCTAssertEqual(early?.current ?? 0, 5)
    }

    func testIntensityRatioComputedFromEnergyAndExercise() {
        let today = day(2026, 4, 26)
        // Ratios: 10, 8, 6. Threshold 8 → 2/3 = 67%, within challenging tolerance (55-75%)
        let history = [
            activity(today, exerciseMinutes: 30, activeEnergy: 300),   // 10.0
            activity(DateHelpers.addDays(-1, to: today), exerciseMinutes: 30, activeEnergy: 240), // 8.0
            activity(DateHelpers.addDays(-2, to: today), exerciseMinutes: 30, activeEnergy: 180), // 6.0
        ]

        let discovered = StreakEngine.discover(history: history, vibe: .challenging, now: today)
        let intensity = discovered.first { $0.metric == StreakMetric.intensityRatio }
        XCTAssertNotNil(intensity)
        XCTAssertEqual(intensity?.currentUnitValue ?? 0, 10.0, accuracy: 0.001)
        XCTAssertEqual(intensity?.current ?? 0, 2)
    }

    func testHeartRateMinutesDiscoveredFromHistory() {
        let today = day(2026, 4, 26)
        // 5 of 7 days meet 10 min → 71% completion, within challenging tolerance (55-75%)
        let history = (0..<7).map { offset -> ActivityDay in
            let hr: Double = offset < 5 ? 15 : 2
            return activity(DateHelpers.addDays(-offset, to: today), heartRateMinutes: hr)
        }

        let discovered = StreakEngine.discover(history: history, vibe: .challenging, now: today)
        let hr = discovered.first { $0.metric == StreakMetric.heartRateMinutes }
        XCTAssertNotNil(hr)
        XCTAssertEqual(hr?.current ?? 0, 5)
    }

    func testCircularHourDistanceTreatsMidnightAsAdjacent() {
        XCTAssertEqual(StreakEngine.circularHourDistance(23, 0), 1)
        XCTAssertEqual(StreakEngine.circularHourDistance(22, 1), 3)
    }

    func testDailyStreakDelegatesToValueComputation() {
        let today = day(2026, 4, 26)
        let history = (0..<4).map { offset in
            activity(DateHelpers.addDays(-offset, to: today), steps: offset == 3 ? 1_000 : 4_000)
        }
        let byDay = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0) })
        let byValue = Dictionary(uniqueKeysWithValues: history.map { ($0.date, $0.steps) })

        let activityResult = StreakEngine.computeDailyStreak(
            metric: .steps,
            threshold: 3_000,
            byDay: byDay,
            today: today
        )
        let valueResult = StreakEngine.computeDailyStreakFromValues(
            metric: .steps,
            threshold: 3_000,
            byDayValues: byValue,
            today: today
        )

        XCTAssertEqual(activityResult.current, valueResult.current)
        XCTAssertEqual(activityResult.best, valueResult.best)
        XCTAssertEqual(activityResult.currentUnitCompleted, valueResult.currentUnitCompleted)
        XCTAssertEqual(activityResult.currentUnitValue, valueResult.currentUnitValue)
    }

    func testBestReminderCandidateIncludesSecondaryAtRiskStreaks() {
        let completedHero = streak(
            metric: .steps,
            cadence: .daily,
            threshold: 3_000,
            current: 12,
            currentUnitCompleted: true,
            currentUnitValue: 3_000
        )
        let atRiskBadge = streak(
            metric: .workouts,
            cadence: .daily,
            threshold: 1,
            current: 6,
            currentUnitCompleted: false,
            currentUnitValue: 0
        )

        let reminder = NotificationService.bestReminderCandidate(from: [completedHero, atRiskBadge])

        XCTAssertEqual(reminder?.trackingKey, atRiskBadge.trackingKey)
    }

    func testBestReminderCandidateIgnoresOneDayStreaks() {
        let newStreak = streak(
            metric: .steps,
            cadence: .daily,
            threshold: 3_000,
            current: 1,
            currentUnitCompleted: false,
            currentUnitValue: 1_000
        )

        XCTAssertNil(NotificationService.bestReminderCandidate(from: [newStreak]))
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
        flightsClimbed: Double = 0,
        earlySteps: Double = 0,
        heartRateMinutes: Double = 0
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
            flightsClimbed: flightsClimbed,
            earlySteps: earlySteps,
            heartRateMinutes: heartRateMinutes
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
