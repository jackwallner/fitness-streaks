import UserNotifications
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

    private func fireDates(_ plans: [NotificationService.ReminderPlan]) -> [Date?] {
        plans.map { DateHelpers.gregorian.date(from: $0.fireComponents) }
    }

    func testReminderTodayNamesTheStreaksOwnLabelAndCount() {
        let today = DateHelpers.startOfDay()
        let running = streak(
            .workouts, threshold: 20, current: 12, customID: "run",
            workoutType: "running", workoutMeasure: .minutes
        )
        let plans = NotificationService.reminderPlans(for: [running], now: at(today, 8, 0), hour: 19, minute: 0)
        XCTAssertEqual(plans.first?.title, "Keep the \(running.thresholdLabel) streak alive")
        XCTAssertEqual(plans.first?.body, "You're at 12 days. Get it in before midnight.")
        XCTAssertEqual(fireDates(plans).first, at(today, 19, 0))
    }

    func testReminderAfterTodaysTimeStartsTomorrow() {
        let today = DateHelpers.startOfDay()
        let plans = NotificationService.reminderPlans(
            for: [streak(current: 12, completed: true)],
            now: at(today, 20, 0),
            hour: 19,
            minute: 0
        )
        XCTAssertEqual(fireDates(plans).first, at(DateHelpers.addDays(1, to: today), 19, 0))
    }

    func testReminderSkipsTodayWhenEveryGoalIsMet() {
        let today = DateHelpers.startOfDay()
        let plans = NotificationService.reminderPlans(
            for: [streak(current: 12, completed: true)],
            now: at(today, 8, 0),
            hour: 19,
            minute: 0
        )
        XCTAssertEqual(fireDates(plans).first, at(DateHelpers.addDays(1, to: today), 19, 0))
    }

    /// A user who stops opening the app gets no background refresh, so the queue
    /// must keep nudging every day on its own, as the old repeating request did.
    func testReminderQueuesEveryDayAheadWithoutALoad() {
        let today = DateHelpers.startOfDay()
        let plans = NotificationService.reminderPlans(
            for: [streak(current: 12)],
            now: at(today, 8, 0),
            hour: 19,
            minute: 0
        )
        let horizon = NotificationService.reminderHorizonDays
        XCTAssertEqual(plans.count, horizon + 1)
        XCTAssertEqual(
            fireDates(plans),
            (0...horizon).map { at(DateHelpers.addDays($0, to: today), 19, 0) }
        )
        XCTAssertLessThanOrEqual(plans.count, NotificationService.allReminderIDs.count - 1)
    }

    func testFutureRemindersHoldNoCountThatCanGoStale() {
        let today = DateHelpers.startOfDay()
        let plans = NotificationService.reminderPlans(
            for: [streak(current: 12), streak(.exerciseMinutes, threshold: 30, current: 40, completed: true)],
            now: at(today, 8, 0),
            hour: 19,
            minute: 0
        )
        for plan in plans.dropFirst() {
            XCTAssertFalse(plan.title.contains("12") || plan.body.contains("12"), plan.body)
            XCTAssertFalse(plan.title.contains("40") || plan.body.contains("40"), plan.body)
            XCTAssertFalse(plan.body.contains("You're at"), plan.body)
        }
        XCTAssertEqual(Set(plans.dropFirst().map(\.title)).count, 1)
    }

    func testNoStreakAtRiskQueuesNothing() {
        let today = DateHelpers.startOfDay()
        XCTAssertTrue(NotificationService.reminderPlans(
            for: [streak(current: 1)], now: at(today, 8, 0), hour: 19, minute: 0
        ).isEmpty)
        XCTAssertTrue(NotificationService.reminderPlans(
            for: [], now: at(today, 8, 0), hour: 19, minute: 0
        ).isEmpty)
    }

    func testCancelCoversTheLegacyRepeatingRequestAndTheWholeQueue() {
        let ids = Set(NotificationService.allReminderIDs)
        XCTAssertTrue(ids.contains(NotificationService.dailyReminderID))
        for index in 0...NotificationService.reminderHorizonDays {
            XCTAssertTrue(ids.contains(NotificationService.reminderID(index)))
        }
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

/// Regression tests for the 2026-11-06 state machine audit and its review
/// (project-docs/audits/state-machines-2026-11-06*.md).
@MainActor
final class StateMachineRegressionTests: XCTestCase {

    private let steps = StreakSettings.streakKey(metric: .steps, cadence: .daily)
    private let exercise = StreakSettings.streakKey(metric: .exerciseMinutes, cadence: .daily)

    private var saved: (
        grace: [String: GracePreservation], log: [GracePreservation], broken: [BrokenStreak],
        tracked: Set<String>?, order: [String], onboarding: [String], committed: [String: Double],
        notifications: Bool
    )!

    override func setUp() {
        super.setUp()
        let s = StreakSettings.shared
        saved = (s.gracePreservations, s.saveLog, s.recentlyBroken, s.trackedStreaks, s.manualStreakOrder,
                 s.lastOnboardingTrackedKeys, s.committedThresholds, s.notificationsEnabled)
        s.gracePreservations = [:]
        s.saveLog = []
        s.recentlyBroken = []
        s.trackedStreaks = nil
        s.manualStreakOrder = []
        s.lastOnboardingTrackedKeys = []
        s.notificationsEnabled = false
    }

    override func tearDown() {
        let s = StreakSettings.shared
        s.gracePreservations = saved.grace
        s.saveLog = saved.log
        s.recentlyBroken = saved.broken
        s.trackedStreaks = saved.tracked
        s.manualStreakOrder = saved.order
        s.lastOnboardingTrackedKeys = saved.onboarding
        s.committedThresholds = saved.committed
        s.notificationsEnabled = saved.notifications
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        let d = DateHelpers.gregorian.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        return DateHelpers.addDays(offset, to: d)
    }

    private func at(_ date: Date, _ hour: Int) -> Date {
        DateHelpers.gregorian.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    // MARK: - SM-1 revive on the day after the break was noticed

    /// 30 hit days (D-31 ... D-2), a miss on D-1, then `dValue` on D and a partial D+1.
    private func history(dValue: Double) -> [ActivityDay] {
        (-31...1).map { offset in
            let value: Double
            switch offset {
            case ...(-2): value = 12_000
            case -1: value = 4_000
            case 0: value = dValue
            default: value = 500
            }
            return ActivityDay(date: day(offset), steps: value)
        }
    }

    private func engineSteps(_ history: [ActivityDay], now: Date, grace: [String: GracePreservation]) -> Streak? {
        StreakEngine.discover(
            history: history.filter { $0.date <= DateHelpers.startOfDay(now) },
            committedThresholds: [steps: 10_000],
            gracePreservations: grace,
            now: now
        ).first { $0.trackingKey == steps }
    }

    private var brokenOnD: BrokenStreak {
        BrokenStreak(
            key: steps, metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 30, brokenAt: at(day(0), 7), missedDate: day(-1)
        )
    }

    private func revivedLength(dValue: Double, now: Date) -> Int? {
        let h = history(dValue: dValue)
        let current = engineSteps(h, now: now, grace: [:])
        let save = StreakStore.revivePreservation(for: brokenOnD, current: current, now: now)
        return engineSteps(h, now: now, grace: [steps: save])?.current
    }

    func testReviveOnTheDetectionDayRestoresTheRun() {
        XCTAssertEqual(revivedLength(dValue: 3_000, now: at(day(0), 9)), 30)
    }

    func testReviveOnTheNextDayAfterAnotherMissRestoresTheRun() {
        let now = at(day(1), 9)
        XCTAssertEqual(engineSteps(history(dValue: 3_000), now: now, grace: [:])?.current, 0, "precondition: run is dead")
        XCTAssertEqual(revivedLength(dValue: 3_000, now: now), 30)
    }

    func testReviveOnTheNextDayAfterMeetingTheGoalKeepsThatDay() {
        XCTAssertEqual(revivedLength(dValue: 12_000, now: at(day(1), 9)), 31)
    }

    // MARK: - SM-2 an open record does not block a later miss

    private var openRecord: BrokenStreak {
        BrokenStreak(
            key: steps, metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 30, brokenAt: at(day(-8), 8), missedDate: day(-9)
        )
    }

    private var laterBreak: [StreakStore.DetectedBreak] {
        let before = Streak(metric: .steps, cadence: .daily, threshold: 10_000, current: 6, best: 30,
                            startDate: day(-7), lastHitDate: day(-2), currentUnitCompleted: false,
                            currentUnitProgress: 0.1, currentUnitValue: 1_000)
        let now = Streak(metric: .steps, cadence: .daily, threshold: 10_000, current: 0, best: 30,
                         startDate: nil, lastHitDate: day(-2), lastMissedDate: day(-1),
                         currentUnitCompleted: false, currentUnitProgress: 0.1, currentUnitValue: 1_000)
        return StreakStore.detectBreaks(
            previous: [before], lastKnownLengths: [steps: 6], lastKnownDate: at(day(-1), 20),
            fresh: [now], preservations: [:], today: day(0)
        )
    }

    func testProMissIsSavedWhileAnOlderRecordIsOpen() {
        XCTAssertEqual(laterBreak.map(\.key), [steps], "precondition: detectBreaks reports the new miss")
        let outcome = StreakStore.applyBreaks(laterBreak, broken: [openRecord], autoSave: true, now: at(day(0), 9))
        XCTAssertEqual(outcome.saves.map(\.key), [steps])
        XCTAssertEqual(outcome.saves.first?.missedDate, day(-1))
        XCTAssertEqual(outcome.saves.first?.preservedLength, 6)
        XCTAssertTrue(outcome.newRecords.isEmpty)
    }

    func testFreeMissReplacesAnOlderRecord() {
        let outcome = StreakStore.applyBreaks(laterBreak, broken: [openRecord], autoSave: false, now: at(day(0), 9))
        XCTAssertEqual(outcome.newRecords.map(\.key), [steps])
        XCTAssertEqual(outcome.broken.count, 1)
        XCTAssertEqual(outcome.broken.first?.missedDate, day(-1))
    }

    func testRecordForTheSameMissIsNotRecordedTwice() {
        let same = BrokenStreak(
            key: steps, metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 6, brokenAt: at(day(0), 7), missedDate: day(-1)
        )
        for autoSave in [true, false] {
            let outcome = StreakStore.applyBreaks(laterBreak, broken: [same], autoSave: autoSave, now: at(day(0), 9))
            XCTAssertEqual(outcome, StreakStore.BreakOutcome(broken: [same], saves: [], newRecords: []))
        }
    }

    // MARK: - SM-4 every save is counted and logged

    private func save(missed: Int, length: Int) -> GracePreservation {
        GracePreservation(
            key: steps, missedDate: day(missed), preservedLength: length, threshold: 10_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: at(day(missed + 1), 8)
        )
    }

    func testSecondSaveOnTheSameStreakIsCounted() {
        let s = StreakSettings.shared
        s.recordSave(save(missed: -10, length: 30))
        s.recordSave(save(missed: -4, length: 35))
        XCTAssertEqual(s.saveLog.count, 2)
        XCTAssertEqual(s.gracePreservations.count, 1, "the engine keeps the latest save per streak")
        let history = (-40...0).map { o in
            ActivityDay(date: day(o), steps: o == 0 ? 500 : ([-10, -4].contains(o) ? 2_000 : 12_000))
        }
        let current = StreakEngine.discover(
            history: history, committedThresholds: [steps: 10_000],
            gracePreservations: s.gracePreservations, now: at(day(0), 9)
        ).first { $0.trackingKey == steps }?.current
        XCTAssertEqual(current, 38, "bridging is unchanged")
    }

    func testSaveLogUpgradeKeepsTheSavesStoredBeforeIt() throws {
        let suite = "StateMachineRegressionTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let older = save(missed: -10, length: 30)
        var other = save(missed: -4, length: 5)
        other = GracePreservation(
            key: exercise, missedDate: other.missedDate, preservedLength: 5, threshold: 30,
            metric: .exerciseMinutes, cadence: .daily, hourWindow: nil, grantedAt: other.grantedAt
        )
        let stored = [steps: older, exercise: other]
        defaults.set(try JSONEncoder().encode(stored), forKey: "gracePreservations")

        XCTAssertEqual(StreakSettings.loadSaveLog(defaults: defaults, latest: stored), [older, other])

        defaults.set(try JSONEncoder().encode([older, older, other]), forKey: "saveLog")
        XCTAssertEqual(StreakSettings.loadSaveLog(defaults: defaults, latest: stored).count, 3)
    }

    // MARK: - SM-5 untrack or re-pick rebuilds the reminders

    private func streak(_ metric: StreakMetric, threshold: Double, current: Int) -> Streak {
        Streak(
            metric: metric, cadence: .daily, threshold: threshold,
            current: current, best: current, startDate: nil, lastHitDate: nil,
            currentUnitCompleted: false, currentUnitProgress: 0.2, currentUnitValue: threshold * 0.2
        )
    }

    func testRefilterRebuildsTheReminderQueue() async {
        let store = StreakStore.shared
        let saved = (store.allCandidates, store.streaks, store.scheduleReminders)
        defer {
            store.allCandidates = saved.0
            store.streaks = saved.1
            store.scheduleReminders = saved.2
        }
        let rebuilt = expectation(description: "reminders rebuilt")
        let scheduled = KeyBox()
        store.scheduleReminders = { streaks in
            scheduled.keys = streaks.map(\.trackingKey)
            rebuilt.fulfill()
        }
        StreakSettings.shared.notificationsEnabled = true
        store.allCandidates = [streak(.steps, threshold: 10_000, current: 40), streak(.exerciseMinutes, threshold: 30, current: 10)]
        StreakSettings.shared.trackedStreaks = [exercise]

        store.refilter()

        await fulfillment(of: [rebuilt], timeout: 2)
        XCTAssertEqual(scheduled.keys, [exercise])
    }

    // MARK: - SM-6 subscribing keeps PIN TO TOP

    private var onboardingKeys: [String] {
        [StreakMetric.steps, .exerciseMinutes, .standHours, .activeEnergy, .workouts]
            .map { StreakSettings.streakKey(metric: $0, cadence: .daily) }
    }

    func testPinToTopSurvivesTheOnboardingRestore() {
        let s = StreakSettings.shared
        let pinned = onboardingKeys[2]
        var order = Array(onboardingKeys.prefix(3)).filter { $0 != pinned }
        order.insert(pinned, at: 0)
        s.lastOnboardingTrackedKeys = onboardingKeys
        s.trackedStreaks = Set(onboardingKeys.prefix(StreakSettings.freeTrackedLimit))
        s.manualStreakOrder = order

        s.restoreOnboardingTrackedStreaksIfNeeded()

        XCTAssertEqual(s.trackedStreaks, Set(onboardingKeys), "precondition: the restore ran")
        XCTAssertEqual(s.manualStreakOrder, order + Array(onboardingKeys.suffix(2)))
    }

    func testOnboardingRestoreWithoutAPinKeepsTheOnboardingOrder() {
        let s = StreakSettings.shared
        s.lastOnboardingTrackedKeys = onboardingKeys
        s.trackedStreaks = Set(onboardingKeys.prefix(StreakSettings.freeTrackedLimit))
        s.manualStreakOrder = Array(onboardingKeys.prefix(3))
        s.restoreOnboardingTrackedStreaksIfNeeded()
        XCTAssertEqual(s.manualStreakOrder, onboardingKeys)
    }

    // MARK: - SM-3 the blocked banner follows the iOS permission

    func testBlockedBannerFollowsThePermission() {
        XCTAssertTrue(NotificationService.showsBlockedBanner(status: .denied, remindersOn: true, showing: false),
                      "reminders on but revoked in iOS Settings")
        XCTAssertFalse(NotificationService.showsBlockedBanner(status: .authorized, remindersOn: false, showing: true),
                       "fixed in iOS Settings")
        XCTAssertTrue(NotificationService.showsBlockedBanner(status: .denied, remindersOn: false, showing: true))
        XCTAssertFalse(NotificationService.showsBlockedBanner(status: .denied, remindersOn: false, showing: false))
        XCTAssertFalse(NotificationService.showsBlockedBanner(status: .notDetermined, remindersOn: true, showing: false))
    }

    // MARK: - SM-8 a toggle off during scheduling leaves nothing queued

    #if DEBUG
    func testTurningRemindersOffWhileSchedulingLeavesNothingQueued() async {
        let fake = FakeReminderQueue()
        let wasPro = StoreKitService.shared.isPro
        defer {
            NotificationService.reminderQueue = SystemReminderQueue()
            StoreKitService.shared.debugSetPro(wasPro)
        }
        NotificationService.reminderQueue = fake
        StoreKitService.shared.debugSetPro(true)
        StreakSettings.shared.notificationsEnabled = true
        fake.onAdd = { count in
            guard count == 3 else { return }
            // SettingsView's toggle off.
            StreakSettings.shared.notificationsEnabled = false
            NotificationService.cancelAll()
        }

        await NotificationService.scheduleDailyReminder(for: [streak(.steps, threshold: 10_000, current: 40)])

        XCTAssertGreaterThanOrEqual(fake.added, 3, "precondition: scheduling was under way")
        XCTAssertTrue(fake.pending.isEmpty, "queued after the toggle off: \(fake.pending.sorted())")
    }

    func testScheduleQueuesTheWholeHorizon() async {
        let fake = FakeReminderQueue()
        let wasPro = StoreKitService.shared.isPro
        defer {
            NotificationService.reminderQueue = SystemReminderQueue()
            StoreKitService.shared.debugSetPro(wasPro)
        }
        NotificationService.reminderQueue = fake
        StoreKitService.shared.debugSetPro(true)
        StreakSettings.shared.notificationsEnabled = true

        await NotificationService.scheduleDailyReminder(for: [streak(.steps, threshold: 10_000, current: 40)])

        XCTAssertGreaterThanOrEqual(fake.pending.count, NotificationService.reminderHorizonDays)
    }
    #endif

    // MARK: - SM-7r a recalibration during a load is not lost

    func testRefilterDuringALoadDoesNotWriteOldGoalsBack() {
        let store = StreakStore.shared
        let saved = (store.allCandidates, store.streaks, store.isLoading)
        defer {
            store.allCandidates = saved.0
            store.streaks = saved.1
            store.isLoading = saved.2
        }
        store.allCandidates = [streak(.steps, threshold: 10_000, current: 12)]
        store.isLoading = true
        // RECALIBRATE ALL GOALS while a load runs.
        StreakSettings.shared.committedThresholds = [:]

        store.refilter()

        XCTAssertNil(StreakSettings.shared.committedThresholds[steps])
    }

    func testStreakTrackedDuringALoadsLastStepGetsItsGoalCommitted() {
        let store = StreakStore.shared
        let saved = (store.allCandidates, store.streaks, store.isLoading)
        defer {
            store.allCandidates = saved.0
            store.streaks = saved.1
            store.isLoading = saved.2
        }
        StreakSettings.shared.committedThresholds = [:]
        store.allCandidates = [streak(.steps, threshold: 10_000, current: 12)]
        // The load has committed its goals and is queuing reminders when the
        // user tracks a streak.
        store.isLoading = true
        store.refilter()
        XCTAssertNil(StreakSettings.shared.committedThresholds[steps], "precondition: the refilter skipped its commit")

        store.commitThresholdsAfterLoad()

        XCTAssertEqual(StreakSettings.shared.committedThresholds[steps], 10_000)
    }

    func testLoadRequestedDuringALoadRunsAfterIt() async {
        let store = StreakStore.shared
        let wasLoading = store.isLoading
        defer { store.isLoading = wasLoading }
        store.isLoading = true
        await store.load()
        XCTAssertTrue(store.reloadRequested, "a load asked for during a load is kept")
        store.isLoading = false
        await store.load()
        XCTAssertFalse(store.reloadRequested, "and runs once the load ends")
    }

    // MARK: - SM-9 day math follows a device time zone change

    func testSharedCalendarFollowsASystemZoneChange() {
        let pinned = DateHelpers.gregorian.timeZone.identifier
        let target = pinned == "Pacific/Auckland" ? "America/Los_Angeles" : "Pacific/Auckland"
        let oldTZ = ProcessInfo.processInfo.environment["TZ"]
        setenv("TZ", target, 1)
        tzset()
        NSTimeZone.resetSystemTimeZone()
        defer {
            if let oldTZ { setenv("TZ", oldTZ, 1) } else { unsetenv("TZ") }
            tzset()
            NSTimeZone.resetSystemTimeZone()
        }
        XCTAssertEqual(TimeZone.current.identifier, target, "precondition: the system zone moved")
        XCTAssertEqual(DateHelpers.gregorian.timeZone.identifier, target)
        XCTAssertEqual(DateHelpers.gregorian.firstWeekday, 2, "weeks still start on Monday")
        let noonThere = DateHelpers.gregorian.date(from: DateComponents(year: 2026, month: 6, day: 10, hour: 12))!
        XCTAssertEqual(DateHelpers.gregorian.component(.hour, from: DateHelpers.startOfDay(noonThere)), 0)
    }
}

@MainActor
private final class KeyBox {
    var keys: [String] = []
}

@MainActor
private final class FakeReminderQueue: ReminderQueue {
    var pending: Set<String> = []
    var added = 0
    var onAdd: @MainActor (Int) -> Void = { _ in }

    func isAuthorized() async -> Bool { true }

    func add(_ request: UNNotificationRequest) async throws {
        await Task.yield()
        pending.insert(request.identifier)
        added += 1
        onAdd(added)
    }

    func removePending(withIdentifiers identifiers: [String]) {
        pending.subtract(identifiers)
    }
}
