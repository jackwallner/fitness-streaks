import XCTest

/// Regression tests for the 2026-10-30 bug hunt (FS-01 to FS-11).
@MainActor
final class BugHuntRegressionTests: XCTestCase {

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DateHelpers.gregorian.date(from: DateComponents(year: y, month: m, day: d))!
    }

    private func at(_ date: Date, _ hour: Int, _ minute: Int) -> Date {
        DateHelpers.gregorian.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
    }

    private func streak(
        _ metric: StreakMetric = .steps,
        threshold: Double = 8_000,
        current: Int,
        completed: Bool = false,
        lastMissed: Date? = nil,
        customID: String? = nil,
        workoutType: String? = nil,
        workoutMeasure: WorkoutMeasure? = nil
    ) -> Streak {
        Streak(
            customID: customID,
            metric: metric,
            cadence: .daily,
            threshold: threshold,
            workoutType: workoutType,
            workoutMeasure: workoutMeasure,
            current: current,
            best: current,
            startDate: nil,
            lastHitDate: nil,
            lastMissedDate: lastMissed,
            currentUnitCompleted: completed,
            currentUnitProgress: completed ? 1.1 : 0.5,
            currentUnitValue: completed ? threshold * 1.1 : threshold / 2
        )
    }

    // MARK: - FS-01 Watch root

    func testWatchShowsStreaksOnceASnapshotHasArrived() {
        // The iPhone's setup flag never reaches the Watch's App Group.
        XCTAssertEqual(WatchRootScreen.resolve(hasCompletedSetup: false, hasSnapshot: true), .streaks)
        XCTAssertEqual(WatchRootScreen.resolve(hasCompletedSetup: false, hasSnapshot: false), .setup)
    }

    // MARK: - FS-02 Save for a met day

    func testSaveForADayThatWasMetDoesNotInflateTheStreak() {
        let today = DateHelpers.startOfDay()
        let yesterday = DateHelpers.addDays(-1, to: today)
        let history = (0..<30).reversed().map { offset in
            ActivityDay(date: DateHelpers.addDays(-offset, to: today), steps: 12_000)
        }
        let key = StreakSettings.streakKey(metric: .steps, cadence: .daily)
        let save = GracePreservation(
            key: key, missedDate: yesterday, preservedLength: 29, threshold: 10_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: .now
        )
        let streaks = StreakEngine.discover(
            history: history,
            committedThresholds: [key: 10_000],
            gracePreservations: [key: save]
        )
        XCTAssertEqual(streaks.first { $0.trackingKey == key }?.current, 30)
    }

    func testSaveForAMissedDayStillBridges() {
        let today = DateHelpers.startOfDay()
        let yesterday = DateHelpers.addDays(-1, to: today)
        let history = (0..<30).reversed().map { offset in
            ActivityDay(date: DateHelpers.addDays(-offset, to: today), steps: offset == 1 ? 4_000 : 12_000)
        }
        let key = StreakSettings.streakKey(metric: .steps, cadence: .daily)
        let save = GracePreservation(
            key: key, missedDate: yesterday, preservedLength: 28, threshold: 10_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: .now
        )
        let streaks = StreakEngine.discover(
            history: history,
            committedThresholds: [key: 10_000],
            gracePreservations: [key: save]
        )
        XCTAssertEqual(streaks.first { $0.trackingKey == key }?.current, 29)
    }

    // MARK: - FS-03 / FS-04 / FS-07 Break detection

    func testStreakMissingFromFreshResultsIsNotABreak() {
        let today = DateHelpers.startOfDay()
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 25)],
            lastKnownLengths: ["steps-daily": 25],
            lastKnownDate: DateHelpers.addDays(-1, to: today),
            fresh: [],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks, [], "hiding, untracking or recalibrating is not a broken streak")
    }

    func testStreakAtZeroIsABreakForYesterday() {
        let today = DateHelpers.startOfDay()
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 25)],
            lastKnownLengths: ["steps-daily": 25],
            lastKnownDate: DateHelpers.addDays(-1, to: today),
            fresh: [streak(current: 0)],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks.map(\.key), ["steps-daily"])
        XCTAssertEqual(breaks.first?.missedDate, DateHelpers.addDays(-1, to: today))
        XCTAssertEqual(breaks.first?.length, 25)
    }

    func testMissFollowedByAMetDayIsStillABreak() {
        let today = DateHelpers.startOfDay()
        let yesterday = DateHelpers.addDays(-1, to: today)
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 20)],
            lastKnownLengths: ["steps-daily": 20],
            lastKnownDate: at(DateHelpers.addDays(-1, to: yesterday), 21, 0),
            fresh: [streak(current: 1, completed: true, lastMissed: yesterday)],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks.map(\.key), ["steps-daily"])
        XCTAssertEqual(breaks.first?.missedDate, yesterday, "the save is dated the day actually missed")
        XCTAssertEqual(breaks.first?.length, 20)
    }

    func testNewGoalWithAShorterRunIsNotABreak() {
        let today = DateHelpers.startOfDay()
        let yesterday = DateHelpers.addDays(-1, to: today)
        let breaks = StreakStore.detectBreaks(
            previous: [streak(threshold: 8_000, current: 20)],
            lastKnownLengths: ["steps-daily": 20],
            lastKnownDate: at(yesterday, 9, 0),
            fresh: [streak(threshold: 12_000, current: 1, completed: true, lastMissed: yesterday)],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks, [])
    }

    func testMissBeforeTheLastLoadIsNotReportedAgain() {
        let today = DateHelpers.startOfDay()
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 20)],
            lastKnownLengths: ["steps-daily": 20],
            lastKnownDate: at(today, 8, 0),
            fresh: [streak(current: 5, lastMissed: DateHelpers.addDays(-6, to: today))],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks, [])
    }

    func testAlreadySavedMissIsNotSavedAgain() {
        let today = DateHelpers.startOfDay()
        let yesterday = DateHelpers.addDays(-1, to: today)
        let save = GracePreservation(
            key: "steps-daily", missedDate: yesterday, preservedLength: 20, threshold: 8_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: .now
        )
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 20)],
            lastKnownLengths: ["steps-daily": 20],
            lastKnownDate: at(DateHelpers.addDays(-1, to: yesterday), 21, 0),
            fresh: [streak(current: 1, completed: true, lastMissed: yesterday)],
            preservations: ["steps-daily": save],
            today: today
        )
        XCTAssertEqual(breaks, [])
    }

    func testBaselineComesFromTheLastSuccessfulLoad() {
        // An earlier failed read left 0 on screen; the last good load saw 40.
        let today = DateHelpers.startOfDay()
        let breaks = StreakStore.detectBreaks(
            previous: [streak(current: 0)],
            lastKnownLengths: ["steps-daily": 40],
            lastKnownDate: at(DateHelpers.addDays(-1, to: today), 17, 0),
            fresh: [streak(current: 0)],
            preservations: [:],
            today: today
        )
        XCTAssertEqual(breaks.map(\.length), [40])
    }

    func testFailedHealthReadKeepsTheLastGoodStreak() async throws {
        let store = StreakStore.shared
        let settings = StreakSettings.shared
        let key = StreakSettings.streakKey(metric: .steps, cadence: .daily)
        let today = DateHelpers.startOfDay()

        let saved = (
            settings.committedThresholds, settings.trackedStreaks, settings.manualStreakOrder,
            settings.customStreaks, settings.gracePreservations, settings.hiddenMetrics
        )
        defer {
            settings.committedThresholds = saved.0
            settings.trackedStreaks = saved.1
            settings.manualStreakOrder = saved.2
            settings.customStreaks = saved.3
            settings.gracePreservations = saved.4
            settings.hiddenMetrics = saved.5
        }

        // 40 met days, then yesterday at 6,000 because the walk to 9,000 came later.
        let cached: [ActivityDay] = (1...41).reversed().map { offset in
            ActivityDay(date: DateHelpers.addDays(-offset, to: today), steps: offset == 1 ? 6_000 : 9_000)
        }
        try HealthKitService.shared.cache(cached)
        settings.committedThresholds = [key: 8_000]
        settings.trackedStreaks = [key]
        settings.manualStreakOrder = [key]
        settings.customStreaks = []
        settings.gracePreservations = [:]
        settings.hiddenMetrics = []

        let live = Streak(
            metric: .steps, cadence: .daily, threshold: 8_000,
            current: 40, best: 40, startDate: nil, lastHitDate: nil,
            currentUnitCompleted: false, currentUnitProgress: 0.75, currentUnitValue: 6_000
        )
        store.streaks = [live]
        store.allCandidates = [live]
        store.history = []
        store.dataMaybeRevoked = false
        store.persistCurrentSnapshot()

        await store.load()

        // The hostless bundle has no HealthKit entitlement, so the fetch fails the
        // way a locked phone's does.
        XCTAssertEqual(store.streaks.first?.current, 40, "a failed Health read must not rewrite the streak")
        XCTAssertEqual(SnapshotStore.load()?.hero?.current, 40, "nor the widget snapshot")
    }

    // MARK: - FS-05 Onboarding restore

    func testOnboardingRestoreKeepsALaterTrackingChoice() {
        let settings = StreakSettings.shared
        let saved = (settings.trackedStreaks, settings.manualStreakOrder, settings.lastOnboardingTrackedKeys)
        defer {
            settings.trackedStreaks = saved.0
            settings.manualStreakOrder = saved.1
            settings.lastOnboardingTrackedKeys = saved.2
        }

        settings.lastOnboardingTrackedKeys = [
            "steps-daily", "exerciseMinutes-daily", "standHours-daily", "activeEnergy-daily", "workouts-daily",
        ]
        let later = ["custom-audit", "workouts-daily", "steps-daily", "exerciseMinutes-daily"]
        settings.trackedStreaks = Set(later)
        settings.manualStreakOrder = later

        settings.restoreOnboardingTrackedStreaksIfNeeded()

        XCTAssertEqual(settings.trackedStreaks, Set(later))
        XCTAssertEqual(settings.manualStreakOrder, later)
    }

    func testOnboardingRestoreRunsOnlyOnce() {
        let settings = StreakSettings.shared
        let saved = (settings.trackedStreaks, settings.manualStreakOrder, settings.lastOnboardingTrackedKeys)
        defer {
            settings.trackedStreaks = saved.0
            settings.manualStreakOrder = saved.1
            settings.lastOnboardingTrackedKeys = saved.2
        }

        let keys = ["steps-daily", "exerciseMinutes-daily", "standHours-daily", "activeEnergy-daily", "workouts-daily"]
        settings.lastOnboardingTrackedKeys = keys
        settings.trackedStreaks = Set(keys.prefix(3))
        settings.manualStreakOrder = Array(keys.prefix(3))
        settings.restoreOnboardingTrackedStreaksIfNeeded()
        XCTAssertEqual(settings.trackedStreaks, Set(keys))

        // Later the subscriber trims back to the first three.
        settings.trackedStreaks = Set(keys.prefix(3))
        settings.manualStreakOrder = Array(keys.prefix(3))
        settings.restoreOnboardingTrackedStreaksIfNeeded()
        XCTAssertEqual(settings.trackedStreaks, Set(keys.prefix(3)))
    }

    // MARK: - FS-06 Snapshot after midnight

    func testSnapshotFromYesterdayReadsAsNotDoneToday() {
        let today = DateHelpers.startOfDay()
        let item = StreakSnapshot.Item(
            metric: "steps", cadence: "daily", threshold: 8_000, current: 12, best: 20,
            currentUnitCompleted: true, currentUnitProgress: 1.2, currentUnitValue: 9_600
        )
        let snap = StreakSnapshot(updated: at(DateHelpers.addDays(-1, to: today), 21, 0), hero: item, badges: [item])

        let now = snap.asOf(at(today, 8, 0))
        XCTAssertEqual(now.hero?.currentUnitCompleted, false)
        XCTAssertEqual(now.hero?.currentUnitProgress, 0)
        XCTAssertEqual(now.hero?.current, 12)
        XCTAssertEqual(now.badges.first?.currentUnitCompleted, false)

        let sameDay = snap.asOf(at(DateHelpers.addDays(-1, to: today), 23, 0))
        XCTAssertEqual(sameDay.hero?.currentUnitCompleted, true)
    }

    // MARK: - FS-08 At-risk reminder

    func testReminderFiresOnceWithTheStreaksOwnLabel() {
        let today = DateHelpers.startOfDay()
        let running = streak(
            .workouts, threshold: 20, current: 12, customID: "run",
            workoutType: "running", workoutMeasure: .minutes
        )
        let plan = NotificationService.reminderPlan(for: [running], now: at(today, 8, 0), hour: 19, minute: 0)
        XCTAssertEqual(plan?.repeats, false)
        XCTAssertEqual(plan?.title, "Keep the \(running.thresholdLabel) streak alive")
        let fire = plan.flatMap { DateHelpers.gregorian.date(from: $0.fireComponents) }
        XCTAssertEqual(fire, at(today, 19, 0))
    }

    func testReminderAfterTodaysTimeIsForTomorrow() {
        let today = DateHelpers.startOfDay()
        let plan = NotificationService.reminderPlan(
            for: [streak(current: 12, completed: true)],
            now: at(today, 20, 0),
            hour: 19,
            minute: 0
        )
        XCTAssertEqual(plan?.repeats, false)
        let fire = plan.flatMap { DateHelpers.gregorian.date(from: $0.fireComponents) }
        XCTAssertEqual(fire, at(DateHelpers.addDays(1, to: today), 19, 0))
    }

    func testReminderSkipsTodayWhenEveryGoalIsMet() {
        let today = DateHelpers.startOfDay()
        let plan = NotificationService.reminderPlan(
            for: [streak(current: 12, completed: true)],
            now: at(today, 8, 0),
            hour: 19,
            minute: 0
        )
        let fire = plan.flatMap { DateHelpers.gregorian.date(from: $0.fireComponents) }
        XCTAssertEqual(fire, at(DateHelpers.addDays(1, to: today), 19, 0))
    }

    // MARK: - FS-09 Returning after 30 days

    func testReturningUserIsNotSentBackToOnboarding() {
        XCTAssertFalse(SetupGate.shouldRestartOnboarding(
            hasCompletedSetup: true, hasAnyCachedDay: true, healthNeverRequested: false
        ))
        XCTAssertFalse(SetupGate.shouldRestartOnboarding(
            hasCompletedSetup: true, hasAnyCachedDay: false, healthNeverRequested: false
        ), "an empty cache alone (an in-memory store) is not a new user")
        XCTAssertFalse(SetupGate.shouldRestartOnboarding(
            hasCompletedSetup: true, hasAnyCachedDay: false, healthNeverRequested: nil
        ))
        XCTAssertTrue(SetupGate.shouldRestartOnboarding(
            hasCompletedSetup: true, hasAnyCachedDay: false, healthNeverRequested: true
        ))
    }

    // MARK: - FS-10 Free cap

    func testFreeUsersSeeAtMostTheFreeCap() {
        let all = (1...5).map { i in streak(current: 10 - i, customID: "c\(i)") }
        let free = StreakStore.visibleStreaks(all, tracked: nil, manualOrder: [], unlimited: false)
        XCTAssertEqual(free.map(\.trackingKey), ["custom-c1", "custom-c2", "custom-c3"])

        let order = ["custom-c5", "custom-c4", "custom-c3", "custom-c2", "custom-c1"]
        let lapsed = StreakStore.visibleStreaks(all, tracked: Set(order), manualOrder: order, unlimited: false)
        XCTAssertEqual(lapsed.map(\.trackingKey), ["custom-c5", "custom-c4", "custom-c3"])

        let pro = StreakStore.visibleStreaks(all, tracked: nil, manualOrder: [], unlimited: true)
        XCTAssertEqual(pro.count, 5)
    }

    // MARK: - FS-11 Sleep stages

    func testSleepNightWrittenAsStageSamplesIsCreditedToWakeDay() {
        let wake = day(2026, 10, 20)
        let evening = DateHelpers.addDays(-1, to: wake)
        let stages: [(start: Date, end: Date)] = [
            (at(evening, 22, 0), at(evening, 23, 30)),
            (at(evening, 23, 30), at(wake, 0, 45)),
            (at(wake, 0, 45), at(wake, 6, 0)),
        ]
        let totals = HealthKitService.mergedHoursByDay(
            intervals: stages,
            start: DateHelpers.addDays(-2, to: wake),
            end: DateHelpers.addDays(1, to: wake)
        )
        XCTAssertEqual(totals[wake] ?? 0, 8, accuracy: 0.01)
        XCTAssertEqual(totals[evening] ?? 0, 0, accuracy: 0.01)
    }

    func testSleepAwakeningsInsideOneNightStayOnTheWakeDay() {
        let wake = day(2026, 10, 20)
        let evening = DateHelpers.addDays(-1, to: wake)
        let stages: [(start: Date, end: Date)] = [
            (at(evening, 22, 0), at(evening, 23, 40)),
            // 20 minutes awake, then back to sleep after midnight.
            (at(wake, 0, 0), at(wake, 6, 0)),
            // An afternoon nap is its own session on the same day.
            (at(wake, 14, 0), at(wake, 15, 0)),
        ]
        let totals = HealthKitService.mergedHoursByDay(
            intervals: stages,
            start: DateHelpers.addDays(-2, to: wake),
            end: DateHelpers.addDays(1, to: wake)
        )
        XCTAssertEqual(totals[wake] ?? 0, 1 + 40.0 / 60 + 6 + 1, accuracy: 0.01)
        XCTAssertEqual(totals[evening] ?? 0, 0, accuracy: 0.01)
    }
}
