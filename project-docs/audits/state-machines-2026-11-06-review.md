# Review of the 2026-11-06 state machine audit

Independent review of `state-machines-2026-11-06.md` and its repro suite. Every claim was re-read against the code on this branch (HEAD `eb78294`, build 165). No app code was changed and nothing was fixed.

**Summary: 9 claims. 8 CONFIRMED, 1 NOT A BUG (SM-7 as routed), 0 UNVERIFIED. 1 misfiled product call is a state bug (P-11), and SM-7 leaves a narrower residual bug (SM-7r). False-positive rate 1 of 9 (11%); 5 of the 8 confirmed claims also carried a wrong citation, impact, variant or test.**

## Runs

One `gh-sim` run, both suites copied into `FitnessStreaksTests` for the run and removed afterwards:
`gh-sim test --scheme FitnessStreaks --only FitnessStreaksTests/StateMachineAuditRepro --only FitnessStreaksTests/StateMachineAuditReview`, run id `fitness-streaks@20261106-211014-2184-claude-mbpro3a2d7-1106-211636-4760`.

Result: 3 passed, 5 failed, 361 s, Xcode 27.1, iPhone 17, iOS 27.2. Every precondition assertion passed; each failure is on the final assertion.

| Test | Result | Recorded value |
|---|---|---|
| Repro `testControlReviveOnDetectionDayRestoresTheRun` | pass | |
| Repro `testBugReviveOnTheNextDayIsOfferedButRestoresNothing` | fail, as the audit recorded | `("Optional(0)") is not equal to ("Optional(30)")` |
| Repro `testControlRestoreAfterSubscribingReAddsTheOtherPicks` | pass | |
| Repro `testBugPinToTopDoesNotSurviveSubscribing` | fail, as the audit recorded | `("Optional("steps-daily")") is not equal to ("Optional("standHours-daily")")` |
| Repro `testSupportingQueueBuiltBeforeUntrackNamesTheUntrackedStreak` | pass | (proves nothing about the queue, see SM-5) |
| Review `testSM2NewBreakIsDetectedWhileAnOlderRecordIsStillOpen` | fail | `("[]") is not equal to ("["steps-daily"]")` |
| Review `testSM4SecondSaveOnTheSameStreakIsCounted` | fail | `("1") is not equal to ("2")`; engine still 38 with only the latest save |
| Review `testSM9SharedCalendarFollowsASystemZoneChange` | fail | `pinned=GMT system=Pacific/Auckland autoupdating=Pacific/Auckland fresh=Pacific/Auckland shared=GMT` |

The repro suite reproduced its recorded result exactly.

The review tests (`StateMachineAuditReview`, source in the appendix) use only seams that are compiled into the test target: `Shared/` is a source of `FitnessStreaksTests` (`project.yml:144-152`), so `StreakStore.detectBreaks`, `StreakSettings.pruneBroken` and `StreakEngine.discover` are callable. `handleBreaks`, `reviveBrokenStreak`, `load` and `NotificationService` scheduling are not testable headless (private, or HealthKit and `UNUserNotificationCenter` in an un-hosted bundle), as the audit says.

Line numbers: the audit says it read build 164, but its `SettingsView.swift` citations are 36 lines behind this tree, because the Language row (`7d90113`, +36 lines in `SettingsView.swift`) landed before the audit commit. Line numbers below are for HEAD.

## Verdicts

| ID | Verdict | User route (shipping UI) | Impact | Evidence |
|---|---|---|---|---|
| SM-1 | CONFIRMED | iPhone, free, RevenueCat build. Steps run of 30, miss on D-1. Open the app on D: "STREAK ENDED" banner (`DashboardView.swift:54-59`). Leave it (swipe the sheet away or ignore the banner; only CLOSE, KEEP SAME GOAL and PICK A NEW GOAL delete the record, `DashboardView.swift:133-143`). Do not meet the goal on D. On D+1: banner, sheet, "REVIVE WITH STREAKS+ TRIAL", "START TRIAL · REVIVE STREAK", confirm in App Store sheet. Run stays 0, record deleted. | Free users who see a break, sleep on it and buy the next day without having met the goal on D. This is the main conversion moment, and the user pays (or starts a trial that bills) for a restore that does not happen and cannot be retried. Highest cost in the audit. | `canRevive` measures from `brokenAt`, the detection time, not the miss (`BrokenStreakSheet.swift:204-209`), although its own doc says "If the break is older than yesterday ... can't retroactively revive" (`:201-203`) and `reviveBrokenStreak` says "The engine only bridges yesterday's miss ... gate this on canRevive" (`StreakStore.swift:669-670`). On D+1 the engine needs D met to bridge (`StreakEngine.swift:579-588`). Repro rerun: control passes (30 on D), bug test fails with 0 on D+1 after both preconditions (run is 0 without the save, gate is open on D+1) passed. The gate in the test is a verbatim copy of the private `canRevive`. |
| SM-2 | CONFIRMED | iPhone. Free user breaks a run on D (record R). Does not clear R through the sheet. Subscribes anywhere except the broken sheet (launch trial offer, Settings, Saves, picker cap). Rebuilds the same streak to 3 or more days and misses again before D+14. Next load: no save, no record, no push. | Converts who subscribe soon after a break, which is when users convert, and who ignore the old banner. Cost: the exact loss Streaks+ sells protection against ("Unlimited, automatic, no action needed", `SettingsView.swift:229`), silently, right after paying. Free variant: the second break is also unrecorded, so no banner or push for it. | `handleBreaks` skips any key with an open record before `attemptAutoSave` (`StreakStore.swift:631` then `:633`). Nothing clears R on subscribe (`App.swift:358-366`; `StoreKitService.setIsPro` `:534-538` does not touch `recentlyBroken`). The broken banner shows for Pro too (`DashboardView.swift:331-339`, no `isPro` filter). Review test: the real `pruneBroken` keeps an 8-day-old record and the real `detectBreaks` reports the new miss (both preconditions passed); the final assertion mirrors the guard at `:631` and fails with `[]`. The guard itself is private, so the skip rests on that line, which is unambiguous. |
| SM-3 | CONFIRMED | iPhone, Pro. Reminders on. Turn the app's notifications off in iOS Settings (or "Turn Off" on a delivered notification). Back in Settings: toggle ON, "Daily nudge at 7:00 PM", no BLOCKED banner. Reverse: denied before, toggle shows "BLOCKED IN IOS SETTINGS. TAP TO FIX", fix in iOS Settings, return: banner stays until the toggle is tapped again. | Narrower than the audit says. The reminder feature does not "silently stop" for good: `scheduleDailyReminder` re-checks permission on every load (`NotificationService.swift:60-62`), so reminders resume on their own once iOS permission is back. What is wrong is the Settings screen: it reports reminders on while iOS blocks them, and the banner built for that case never shows. Reaches Pro users who turn notifications off at the system level, often by accident from a notification. | Toggle binds to `settings.notificationsEnabled` only (`SettingsView.swift:465-479`); `notificationsBlockedBySystem` is `@State` set only in `enableNotifications()` (`:17`, `:595-609`); no `scenePhase` or `onAppear` permission read in `SettingsView`. Code is unambiguous; no headless seam for iOS permission. |
| SM-4 | CONFIRMED | iPhone, Pro. Miss a day on steps (auto-saved at next load), keep going, miss again. Stats: "STREAKS+ SAVES TO DATE" 1. Saves tab and Settings "RECENT SAVES": one steps row. | Every Pro user with two or more misses on one streak, which is ordinary use of the plan. Cost: the headline number of the paid feature undercounts and the save history is lost. The streak count itself is right (latest save is cumulative). | Both writers assign by key (`StreakStore.swift:634`, `:674`); readers use `.count` and `.values` (`StatsView.swift:118`, `:144-149`, `SavesView.swift:117-126`, `SettingsView.swift:236-241`). The engine comment confirms one save per key by design for bridging (`StreakEngine.swift:573-575`), not for a count. Review test: two saves written the way `:634` writes them leave `count == 1`; the engine still returns 38 (30 + 5 + 3) from the latest save, so only the count and log are wrong. |
| SM-5 | CONFIRMED | iPhone, Pro, reminders on. Open the longest or most urgent streak, ACTIONS, UNTRACK, Untrack (`StreakDetailView.swift:463-465`, `:496-497`). Or Settings, TRACKED STREAKS, SAVE. Leave the app. At reminder time the push names the removed streak, every day until the app loads again. | Pro users with reminders on who untrack or re-pick and do not reopen the app before the reminder fires. Cost: a push about a streak the user just removed; fixed by the next load (foreground after 60 s, `StreakStore.swift:183-186`). | `untrack()`, `makePrimary()`, picker `save()` and dashboard `restart()` call `refilter()` (`StreakDetailView.swift:593-615`, `StreakPicker.swift:376-382`, `DashboardView.swift:775-781`), which never schedules (`StreakStore.swift:56-60`). Scheduler call sites are only `StreakStore.swift:339` and `SettingsView.swift:518`, `:521`, `:601`. The audit's supporting test only compares two pure plan lists and proves nothing about the queue; the verdict rests on the call sites. |
| SM-6 | CONFIRMED | iPhone, free. Onboarding with the default 5 core picks, decline the trial (trimmed to 3, `OnboardingView.swift:829-837`). Open the 2nd or 3rd streak, ACTIONS, PIN TO TOP (shown only when not hero, `StreakDetailView.swift:452-456`). Subscribe from any paywall. The hero reverts to the onboarding order. | Free users who declined the onboarding trial with more than 3 picks, pinned, then subscribed. Cost: the new subscriber's chosen hero moves the moment they pay; one tap to re-pin. | The audit's citation is misread: "a subscriber's later edits always win" (`StreakSettings.swift:555-556`) is about edits after the restore ran; the doc also says it "Runs only while tracking is still exactly the trimmed onboarding picks", which a pin does not change. So the restore running is the documented rule. The bug is narrower: the restore overwrites `manualStreakOrder` (`:562`) and so breaks PIN TO TOP's promise ("Make this the primary streak on the dashboard", `StreakDetailView.swift:456`), which no doc excuses. Repro rerun: control passes, bug test fails with `steps-daily` first instead of the pinned `standHours-daily`, after its three preconditions passed. |
| SM-7 | NOT A BUG (as routed) | Audit route: RECALIBRATE ALL GOALS during the launch load's 400-day read, old goals written back. That does not happen: the running load reads `committedThresholds`, `gracePreservations`, `plannedFreezes`, `lookbackDays` and `intensity` at `StreakStore.swift:293-303`, after its only HealthKit awaits (`:233`, `:255`), so an action during the read is applied by the running load. The revive variant has no window either: for a user who just subscribed, `notificationsEnabled` is false, so nothing after `:294` suspends (`handleBreaks` awaits only `notifyStreakBroken`, guarded by `notificationsEnabled` first, `NotificationService.swift:178`; `scheduleDailyReminder` returns before any await, `:60`). | Not reachable as described. A narrower residual is listed as SM-7r below. | `StreakStore.swift:195`, `:233`, `:255`, `:293-303`, `:327`, `:339`; `NotificationService.swift:60-62`, `:178`. |
| SM-8 | CONFIRMED (toggle-off variant only) | iPhone, Pro, reminders on, in Settings. Trigger a load (open the app, change Intensity `SettingsView.swift:334-335`, add a freeze) and turn PROACTIVE AT-RISK ALERTS off while that load is adding its 31 requests. Requests added after the toggle's `cancelAll()` stay queued until the next load. | Sub-second window at the end of each load, needs Pro, reminders on and a toggle-off at that moment. Cost: reminders after the user turned them off, only on days before they next open the app. The time-change variant is not established: both tasks write the same identifiers 0...30 (`NotificationService.swift:78`, `:88-90`), so the later task overwrites the earlier one's requests and reads the new hour and minute. | Guard runs once before the add loop (`NotificationService.swift:60-62`), each `await center.add` (`:80`) yields the main actor, and the toggle off runs `cancelAll()` synchronously (`SettingsView.swift:472-474`). No headless seam; code leaves no doubt that the interleave is possible. |
| SM-9 | CONFIRMED | iPhone. Travel across zones with the app suspended in memory (not killed), reopen. `DateHelpers.gregorian` is a `static let` built once (`DateHelpers.swift:4-8`); a `scenePhase` refresh (`App.swift:250-255`) recomputes in the old zone. | Travelers whose app survives the trip in memory, until the process is killed. What goes wrong: the app's "today", progress and day split stay in the old zone while the device date has moved (and while `DashboardView.shouldShowAtRisk` uses `Calendar.current`, `DashboardView.swift:343`), and today's reminder can be lost because its components are built in the old zone and read by iOS in the new one (`NotificationService.swift:119-127`). The audit's stated cost, a false STREAK ENDED or a spurious save, is not established: the pinned zone is consistent with itself and with the history it bucketed, and the rebucketing after a relaunch happens on any zone change. Ranked last. | Review test with a real system zone change in process (`TZ` plus `NSTimeZone.resetSystemTimeZone()`): precondition passed (`TimeZone.current`, `Calendar.autoupdatingCurrent` and a freshly built gregorian calendar all moved to Pacific/Auckland) while `DateHelpers.gregorian` stayed on GMT. The audit's `NSTimeZone.default` seam was the wrong lever. No `NSSystemTimeZoneDidChange` handler (`App.swift:245-256`). |

### SM-7r (residual of SM-7): CONFIRMED

Route: iPhone, Pro, reminders on. Tap RECALIBRATE ALL GOALS (or a per-streak RECALIBRATE, a lookback change, a freeze change) while a load is in its last step, `scheduleDailyReminder` adding 31 requests (`StreakStore.swift:339`, `NotificationService.swift:70-84`). `load()` returns at `StreakStore.swift:195`; the running load has already committed the old thresholds at `:327`. "RECALIBRATING…" clears when that load ends (`SettingsView.swift:113-115`) with the old goals on screen, and the change only lands at the next load. If a `refilter()` runs first (pin, untrack, picker save, subscribe), `commitThresholds` re-commits the old thresholds and the recalibration is lost (`StreakStore.swift:58`, `StreakSettings.swift:527-535`). Impact: sub-second window per load; a confirmed destructive action that looks done and is not.

### Misfiled product call: P-11 is a state bug, CONFIRMED

Route: iPhone. A purchase fails (payment declined) or the app is foregrounded offline (`refreshEntitlement` throws, `StoreKitService.swift:456-457`). Later, on a paywall with products already loaded, tap Restore with nothing to restore: the old error shows instead of "NO ACTIVE PURCHASES FOUND." `lastError` is cleared only by a successful `loadProducts` (`StoreKitService.swift:297`), which the paywall skips when products are loaded (`PaywallView.swift:90-92`); `restore()` leaves it as is (`:431-442`), and the paywall prints it (`PaywallView.swift:597`). Same in `TrialOfferSheet.swift:358`. Cost: a wrong, alarming message on the restore path.

## Product calls

| ID | Review |
|---|---|
| P-1 | Agree it is a design call: the doc comment on `reminderPlans` documents count-free later days (`NotificationService.swift:104-111`). The Settings copy "if a tracked streak isn't locked in yet" (`SettingsView.swift:524`) overstates it; a copy fix is the cheap answer. |
| P-2 | Agree: comment drift only (`StreakPicker.swift:189-190`). |
| P-3 | Agree, and less than stated: the flag is cleared at the next `setIsPro(true)` (`StoreKitService.swift:535`), which runs on every foreground through `refreshEntitlement` (`App.swift:252-253`). The window is one foreground session; no realistic refund lands in it. |
| P-4, P-5, P-6, P-8, P-9, P-10, P-12 | Agree they are product calls (user-initiated or documented behavior, or copy). |
| P-7 | Agree it is a product call. Note that a lapsed Pro whose Settings was not open at lapse keeps `notificationsEnabled` true (`SettingsView.swift:116-121` only runs while mounted) and so keeps getting "Streak ended" pushes with no in-app toggle. |
| P-11 | Misfiled: a reachable wrong state, see above. |

## What survived, ranked (reach times cost)

1. SM-1: paid revive that restores nothing, offer then gone.
2. SM-2: Pro auto-save skipped after an open free-era break record.
3. SM-4: saves count and history undercount for every multi-save Pro user.
4. SM-5: reminders name a streak the user just untracked.
5. SM-6: subscribing undoes a free user's PIN TO TOP.
6. SM-3: Settings shows reminders on while iOS blocks them; stale BLOCKED banner.
7. P-11: stale error on Restore.
8. SM-8: reminders survive a toggle-off during a load's scheduling step.
9. SM-7r: recalibrate during a load's scheduling step is deferred or lost.
10. SM-9: day math stays in the old time zone after travel until the app is killed.

## Errors in the audit

- SM-7: race claimed without checking where the running load suspends. The stated route is applied, not dropped.
- SM-6: right outcome, wrong citation; the quoted doc line covers edits after the restore, and the guard is documented to check the tracked set only.
- SM-3: impact overstated ("no reminder ever arrives"); reminders resume by themselves when permission returns.
- SM-8: the time-change variant ignores that requests share identifiers.
- SM-5: the supporting test compares two pure plan lists; it does not touch the queue and should not be cited as evidence.
- P-11 filed as a product call though it is a reachable wrong message; P-3's window is overstated.
- `SettingsView.swift` citations are 36 lines stale against the commit the audit landed on.
- SM-9: right mechanism, unproven cost (false break); the failed seam was `NSTimeZone.default`, while `TZ` plus `resetSystemTimeZone()` works headless.

## Method changes that would have prevented these errors

1. For every race, list the `await` points between the read of the shared state and the write, and the guards in front of them. No suspension point in the window, no race (SM-7, SM-8).
2. Before citing a doc comment as a promise, quote its whole paragraph and say what it scopes. A documented rule is not a bug (SM-6).
3. Separate "the screen states something false" from "the feature stops working" in impact, and check for self-healing on the next load (SM-3, SM-5, SM-8).
4. A supporting test must exercise the state the claim is about. A test over pure helpers that cannot see the queue, store or view is not evidence (SM-5).
5. Re-run line citations against the commit the audit lands on (`git diff <audited>..HEAD --stat` per cited file).
6. File "product call" only when no user-visible state is wrong; a stale error message is a state bug (P-11).
7. Check the test target's sources before declaring no seam: `Shared/` is compiled into `FitnessStreaksTests`, which exposes `detectBreaks` and `pruneBroken` for SM-2's preconditions. For time zone work, move the process zone with `TZ` plus `NSTimeZone.resetSystemTimeZone()`, not `NSTimeZone.default`.

## Appendix: review tests

Ran once from `FitnessStreaksTests/StateMachineAuditReview.swift`, then removed from the target.

```swift
import XCTest

/// Independent review of the 2026-11-06 state machine audit. Each test asserts
/// the behaviour the app promises after its own preconditions; a failure on the
/// final assertion reproduces the claim.
@MainActor
final class StateMachineAuditReview: XCTestCase {

    private let steps = StreakSettings.streakKey(metric: .steps, cadence: .daily)
    private var savedGrace: [String: GracePreservation] = [:]
    private var savedBroken: [BrokenStreak] = []

    override func setUp() {
        super.setUp()
        savedGrace = StreakSettings.shared.gracePreservations
        savedBroken = StreakSettings.shared.recentlyBroken
        StreakSettings.shared.gracePreservations = [:]
        StreakSettings.shared.recentlyBroken = []
    }

    override func tearDown() {
        StreakSettings.shared.gracePreservations = savedGrace
        StreakSettings.shared.recentlyBroken = savedBroken
        super.tearDown()
    }

    private func day(_ offset: Int) -> Date {
        let d = DateHelpers.gregorian.date(from: DateComponents(year: 2026, month: 6, day: 10))!
        return DateHelpers.addDays(offset, to: d)
    }

    private func at(_ date: Date, _ hour: Int) -> Date {
        DateHelpers.gregorian.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    private func save(missed: Int, length: Int) -> GracePreservation {
        GracePreservation(
            key: steps, missedDate: day(missed), preservedLength: length, threshold: 10_000,
            metric: .steps, cadence: .daily, hourWindow: nil, grantedAt: at(day(missed + 1), 8)
        )
    }

    // MARK: - SM-4: a second Pro save on the same streak replaces the first

    /// Hits D-40...D-11 (30 days), miss D-10, hits D-9...D-5, miss D-4, hits D-3...D-1, partial today.
    private var twoMissHistory: [ActivityDay] {
        (-40...0).map { o in
            let value: Double = o == 0 ? 500 : ([-10, -4].contains(o) ? 2_000 : 12_000)
            return ActivityDay(date: day(o), steps: value)
        }
    }

    private func engineCurrent(_ grace: [String: GracePreservation]) -> Int? {
        StreakEngine.discover(
            history: twoMissHistory, committedThresholds: [steps: 10_000],
            gracePreservations: grace, now: at(day(0), 9)
        ).first { $0.trackingKey == steps }?.current
    }

    func testSM4SecondSaveOnTheSameStreakIsCounted() {
        XCTAssertEqual(engineCurrent([:]), 3, "precondition: natural run after the second miss")
        // handleBreaks writes each Pro save as `preservations[key] = ...` (StreakStore.swift:634).
        var preservations: [String: GracePreservation] = [:]
        preservations[steps] = save(missed: -10, length: 30)
        preservations[steps] = save(missed: -4, length: 35)
        StreakSettings.shared.gracePreservations = preservations
        XCTAssertEqual(engineCurrent(preservations), 38,
                       "precondition: the engine still bridges the whole run from the latest save")
        // StatsView.totalSaves = settings.gracePreservations.count (StatsView.swift:118).
        XCTAssertEqual(StreakSettings.shared.gracePreservations.count, 2, "two saves were made on steps")
    }

    // MARK: - SM-2: an open record for the key survives and the new break is detected

    func testSM2NewBreakIsDetectedWhileAnOlderRecordIsStillOpen() {
        let open = BrokenStreak(
            key: steps, metric: .steps, cadence: .daily, threshold: 10_000, hourWindow: nil,
            brokenLength: 30, brokenAt: at(day(-8), 8), missedDate: day(-9)
        )
        StreakSettings.shared.recentlyBroken = [open]
        StreakSettings.shared.pruneBroken(now: at(day(0), 9))
        XCTAssertEqual(StreakSettings.shared.recentlyBroken.count, 1, "precondition: an 8-day-old record is kept")

        let before = Streak(metric: .steps, cadence: .daily, threshold: 10_000, current: 6, best: 30,
                            startDate: day(-7), lastHitDate: day(-2), currentUnitCompleted: false,
                            currentUnitProgress: 0.1, currentUnitValue: 1_000)
        let now = Streak(metric: .steps, cadence: .daily, threshold: 10_000, current: 0, best: 30,
                         startDate: nil, lastHitDate: day(-2), lastMissedDate: day(-1),
                         currentUnitCompleted: false, currentUnitProgress: 0.1, currentUnitValue: 1_000)
        let breaks = StreakStore.detectBreaks(
            previous: [before], lastKnownLengths: [steps: 6], lastKnownDate: at(day(-1), 20),
            fresh: [now], preservations: [:], today: day(0)
        )
        XCTAssertEqual(breaks.map(\.key), [steps], "precondition: detectBreaks reports the new miss")
        // handleBreaks, StreakStore.swift:631: `guard !newBroken.contains(where: { $0.key == key }) else { continue }`
        // runs before attemptAutoSave, so this is what reaches the Pro save:
        let reachesSave = breaks.filter { b in !StreakSettings.shared.recentlyBroken.contains { $0.key == b.key } }
        XCTAssertEqual(reachesSave.map(\.key), [steps], "a Pro user's new miss reaches auto-save")
    }

    // MARK: - SM-9: the shared calendar's zone after a system zone change

    func testSM9SharedCalendarFollowsASystemZoneChange() {
        let pinned = DateHelpers.gregorian.timeZone.identifier  // forces first use
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
        let system = TimeZone.current.identifier
        let auto = Calendar.autoupdatingCurrent.timeZone.identifier
        let fresh = Calendar(identifier: .gregorian).timeZone.identifier
        let shared = DateHelpers.gregorian.timeZone.identifier
        let readings = "pinned=\(pinned) system=\(system) autoupdating=\(auto) fresh=\(fresh) shared=\(shared)"
        XCTAssertEqual(system, target, "precondition: the system zone moved. \(readings)")
        XCTAssertEqual(shared, target, "DateHelpers.gregorian follows the device zone. \(readings)")
    }
}
```
