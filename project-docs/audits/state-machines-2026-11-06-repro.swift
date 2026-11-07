// State machine audit repro suite, 2026-11-06. Moved out of the test target so it does not break the build.
// To rerun: copy to FitnessStreaksTests/StateMachineAuditRepro.swift, then
//   gh-sim test --scheme FitnessStreaks --only FitnessStreaksTests/StateMachineAuditRepro
// Recorded run: fitness-streaks@20261106-191621-9aba-claude-mbpro354da-1106-202008-2343
// Expected: testBugReviveOnTheNextDayIsOfferedButRestoresNothing and testBugPinToTopDoesNotSurviveSubscribing fail;
// the two Control tests and the Supporting test pass.
import XCTest

/// State machine audit repro suite, 2026-11-06. Failing tests are expected: each
/// "Bug" test asserts the behaviour the app promises, preceded by assertions of
/// its own preconditions, and each has a passing control.
@MainActor
final class StateMachineAuditRepro: XCTestCase {

    private let steps = StreakSettings.streakKey(metric: .steps, cadence: .daily)

    override func setUp() {
        super.setUp()
        let s = StreakSettings.shared
        s.trackedStreaks = nil
        s.manualStreakOrder = []
        s.lastOnboardingTrackedKeys = []
        s.gracePreservations = [:]
        s.recentlyBroken = []
    }

    // MARK: - SM-1 revive offered on day D+1 cannot be honoured by the engine

    private func day(_ offsetFromD: Int) -> Date {
        let d = DateHelpers.gregorian.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        return DateHelpers.addDays(offsetFromD, to: d)
    }

    private func at(_ date: Date, _ hour: Int) -> Date {
        DateHelpers.gregorian.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    /// 30 hit days (D-31 ... D-2), a miss on D-1, a miss on D, a partial D+1.
    private var historyWithTwoMisses: [ActivityDay] {
        (-31...1).map { offset in
            let value: Double
            switch offset {
            case ...(-2): value = 12_000
            case -1: value = 4_000
            case 0: value = 3_000
            default: value = 500
            }
            return ActivityDay(date: day(offset), steps: value)
        }
    }

    private var saveForMissOnDMinus1: GracePreservation {
        GracePreservation(
            key: steps, missedDate: day(-1), preservedLength: 30, threshold: 10_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: at(day(1), 8)
        )
    }

    private func current(now: Date, withSave: Bool) -> Int? {
        StreakEngine.discover(
            history: historyWithTwoMisses.filter { $0.date <= DateHelpers.startOfDay(now) },
            committedThresholds: [steps: 10_000],
            gracePreservations: withSave ? [steps: saveForMissOnDMinus1] : [:],
            now: now
        ).first { $0.trackingKey == steps }?.current
    }

    /// Mirror of `BrokenStreakSheet.canRevive` (BrokenStreakSheet.swift:204-209), which is private.
    private func sheetOffersRevive(_ broken: BrokenStreak, now: Date) -> Bool {
        let missed = DateHelpers.startOfDay(broken.brokenAt)
        let today = DateHelpers.startOfDay(now)
        let days = DateHelpers.gregorian.dateComponents([.day], from: missed, to: today).day ?? 0
        return days <= 1
    }

    private var brokenRecord: BrokenStreak {
        // Detected on the first load of day D: the run ended at 30 and D-1 was missed.
        BrokenStreak(
            key: steps, metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 30, brokenAt: at(day(0), 7), missedDate: day(-1)
        )
    }

    func testControlReviveOnDetectionDayRestoresTheRun() {
        let now = at(day(0), 9)
        XCTAssertEqual(current(now: now, withSave: false), 0, "precondition: the run is dead without a save")
        XCTAssertTrue(sheetOffersRevive(brokenRecord, now: now), "precondition: sheet offers revive")
        XCTAssertEqual(current(now: now, withSave: true), 30)
    }

    func testBugReviveOnTheNextDayIsOfferedButRestoresNothing() {
        let now = at(day(1), 9)
        XCTAssertEqual(current(now: now, withSave: false), 0, "precondition: the run is dead without a save")
        XCTAssertTrue(sheetOffersRevive(brokenRecord, now: now), "precondition: sheet still offers revive on D+1")
        // "we'll restore your 30-day run on the spot"
        XCTAssertEqual(current(now: now, withSave: true), 30,
                       "the buyer was told the run is restored; the engine leaves it at the value shown")
    }

    // MARK: - SM-6 pin to top is overwritten when the onboarding picks are restored

    private var onboardingKeys: [String] {
        [(StreakMetric.steps), .exerciseMinutes, .standHours, .activeEnergy, .workouts]
            .map { StreakSettings.streakKey(metric: $0, cadence: .daily) }
    }

    private func trimmedFreeState(order: [String]) {
        let s = StreakSettings.shared
        s.lastOnboardingTrackedKeys = onboardingKeys
        s.trackedStreaks = Set(onboardingKeys.prefix(StreakSettings.freeTrackedLimit))
        s.manualStreakOrder = order
    }

    func testControlRestoreAfterSubscribingReAddsTheOtherPicks() {
        trimmedFreeState(order: Array(onboardingKeys.prefix(3)))
        XCTAssertEqual(StreakSettings.shared.trackedStreaks?.count, 3, "precondition: free cap trim")
        StreakSettings.shared.restoreOnboardingTrackedStreaksIfNeeded()
        XCTAssertEqual(StreakSettings.shared.trackedStreaks, Set(onboardingKeys))
    }

    func testBugPinToTopDoesNotSurviveSubscribing() {
        let pinned = onboardingKeys[2]
        // StreakDetailView.makePrimary(): the pinned key moves to the front of manualStreakOrder.
        var order = Array(onboardingKeys.prefix(3)).filter { $0 != pinned }
        order.insert(pinned, at: 0)
        trimmedFreeState(order: order)
        XCTAssertEqual(StreakSettings.shared.manualStreakOrder.first, pinned, "precondition: pinned")
        XCTAssertEqual(StreakSettings.shared.trackedStreaks?.count, 3, "precondition: free cap trim")

        StreakSettings.shared.restoreOnboardingTrackedStreaksIfNeeded()

        XCTAssertEqual(StreakSettings.shared.trackedStreaks?.count, 5, "precondition: the restore ran")
        // StreakSettings.swift:555 "a subscriber's later edits always win"
        XCTAssertEqual(StreakSettings.shared.manualStreakOrder.first, pinned)
    }

    // MARK: - SM-5 supporting: the queued reminders name a streak that was just untracked

    private func streak(_ metric: StreakMetric, threshold: Double, current: Int) -> Streak {
        Streak(
            customID: nil, metric: metric, cadence: .daily, threshold: threshold,
            current: current, best: current, startDate: nil, lastHitDate: nil,
            currentUnitCompleted: false, currentUnitProgress: 0.2, currentUnitValue: threshold * 0.2
        )
    }

    func testSupportingQueueBuiltBeforeUntrackNamesTheUntrackedStreak() {
        let long = streak(.steps, threshold: 10_000, current: 40)
        let other = streak(.exerciseMinutes, threshold: 30, current: 10)
        let now = at(day(0), 8)
        let before = NotificationService.reminderPlans(for: [long, other], now: now, hour: 19, minute: 0)
        // StreakDetailView.untrack(): tracked set loses the key, then store.refilter() only.
        let visible = StreakStore.applyTrackedFilter([long, other], tracked: [other.trackingKey])
        let after = NotificationService.reminderPlans(for: visible, now: now, hour: 19, minute: 0)

        XCTAssertEqual(visible.map(\.trackingKey), [other.trackingKey], "precondition: steps is untracked")
        XCTAssertEqual(before.count, NotificationService.reminderHorizonDays + 1, "precondition: a full queue was pending")
        XCTAssertTrue(before.allSatisfy { $0.title.contains(long.thresholdLabel) },
                      "precondition: every pending reminder names the steps goal")
        XCTAssertNotEqual(before.map(\.title), after.map(\.title),
                          "the queue a rebuild would produce differs from the one still pending")
    }

    // SM-9 (DateHelpers.gregorian fixed zone) has no test: setting NSTimeZone.default
    // did not move TimeZone.current on the runner (precondition failed: "GMT" vs
    // "Pacific/Auckland"), so the seam cannot reproduce a system zone change.
}
