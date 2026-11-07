# Fixes for the 2026-11-06 state machine audit

Update 2026-11-07: `state-machines-2026-11-06-verify.md` failed the first round on one regression from P-11 (Restore hid the paywall's price-load retry block). It is fixed in `fix: keep the paywall's price-load retry block up through Restore`. The report's note 2, a goal commit that SM-7r's fix skips during a load's last step, is fixed too, in `fix: commit the goal of a streak tracked during a load's last step`. Note 4 is held for Jack (a UX call); notes 1, 3, 5 and 6 need no change (see "Verify notes"). The P-11 and SM-7r rows and the test results below are updated. Nothing in the verify report is disputed.

Fixes for every claim `state-machines-2026-11-06-review.md` marked CONFIRMED, in the review's ranked order, on branch `fleet/20261106-225834-5698-claude` from `5e0e167`. The review left nothing UNVERIFIED and listed SM-7 (as routed) as NOT A BUG, so SM-7 is untouched; its confirmed residual SM-7r is fixed. Product calls other than the misfiled P-11 are left alone.

**Summary: 10 in scope. 10 fixed, 0 held, 0 skipped. Verify round: 1 must-change fixed, 1 note fixed, 1 note held for Jack, 4 notes need no change, 0 disputed.**

## Claims

SM-1, SM-2 and SM-4 share one commit: they are one data path (break detection, the save written for it and the revive that writes the same save), and the saves log is the API both writers use. All regression tests are in `FitnessStreaksTests/BugHuntRegressionTests.swift`, class `StateMachineRegressionTests`, so the tracked Xcode project did not change. The review's repro and review suites were not added to the target; their sound tests are reused there (SM-1, SM-2, SM-4, SM-6, SM-9). The audit's SM-5 "supporting" test, which the review said proves nothing, is not kept.

| ID | Outcome | Commit subject | Regression test (`FitnessStreaksTests/StateMachineRegressionTests`) | What changed |
|---|---|---|---|---|
| SM-1 | Fixed | `fix: save every miss, count every save and make a next-day revive restore the run` | `testReviveOnTheNextDayAfterAnotherMissRestoresTheRun`; controls `testReviveOnTheDetectionDayRestoresTheRun`, `testReviveOnTheNextDayAfterMeetingTheGoalKeepsThatDay` (the repro's history and record) | `reviveBrokenStreak` writes its save through `StreakStore.revivePreservation`, which for a daily streak dates the save on the latest miss (yesterday when no run has started since, else the day before the new run), the save a Streaks+ auto-save would have written on that load. The sheet's revive gate (`canRevive`) and the offer it shows are unchanged, so nothing changes about when the trial offer appears; the revive it sells now restores the run. |
| SM-2 | Fixed | `fix: save every miss, count every save and make a next-day revive restore the run` | `testProMissIsSavedWhileAnOlderRecordIsOpen`, `testFreeMissReplacesAnOlderRecord`; control `testRecordForTheSameMissIsNotRecordedTwice` | `handleBreaks` decisions moved into the pure `StreakStore.applyBreaks`. Only a record for the same missed day skips a break. A Pro miss is saved even with an older record open (the record is left as is: nothing is cleared because of the cached entitlement); a free miss replaces the older record for that streak and is announced. |
| SM-4 | Fixed | `fix: save every miss, count every save and make a next-day revive restore the run` | `testSecondSaveOnTheSameStreakIsCounted`; upgrade `testSaveLogUpgradeKeepsTheSavesStoredBeforeIt` | New append-only `StreakSettings.saveLog` (key `saveLog`) beside the unchanged `gracePreservations` the engine bridges from. Every save goes through `recordSave`. Stats "SAVES TO DATE", Saves "Recent Saves" and Settings "RECENT SAVES" read the log (row ids no longer use the streak key). Upgrade: with no stored log, the log starts from the saves already in `gracePreservations`; nothing is dropped and the stored format of `gracePreservations` is unchanged. |
| SM-5 | Fixed | `fix: rebuild reminders when the tracked streaks change` | `testRefilterRebuildsTheReminderQueue` | `refilter()` (untrack, pin, picker save, dashboard restart, subscribe) rebuilds the reminder queue when reminders are on, through a `scheduleReminders` seam the test replaces. |
| SM-6 | Fixed | `fix: keep PIN TO TOP when subscribing restores the onboarding picks` | `testPinToTopSurvivesTheOnboardingRestore` (the repro's bug test), control `testOnboardingRestoreWithoutAPinKeepsTheOnboardingOrder` | The restore keeps the user's order of the trimmed picks and appends the restored picks after them, instead of overwriting `manualStreakOrder` with the onboarding order. |
| SM-3 | Fixed | `fix: Settings re-reads the notification permission on appear and return` | `testBlockedBannerFollowsThePermission` | Settings reads the iOS permission on appear and whenever the app becomes active: denied with reminders on shows the BLOCKED banner, a restored permission clears it. The toggle is never switched off because of the permission. The wiring (task, scene phase) has no headless seam; the decision is `NotificationService.showsBlockedBanner`. |
| P-11 | Fixed | `fix: restore and purchase show only their own error`; follow-up `fix: keep the paywall's price-load retry block up through Restore` | none: the test target compiles the stub `StoreKitService` (no `REVENUECAT`), so `loadProducts()`, `restore()` and `purchase()` cannot run headless | `purchase()` and `restore()` clear `lastError` before they start, so Restore with nothing to restore shows "NO ACTIVE PURCHASES FOUND." instead of an earlier error. Follow-up for the verify report's regression: the price-load failure now lives in its own `productLoadError`, set only by `loadProducts()`, and the paywall's "PRICES DIDN'T LOAD" block (with TRY AGAIN and NOT NOW) reads it, so a Restore or purchase attempt no longer hides it. `lastError` stays attempt-scoped. No copy changed. Device check: fail a purchase (or foreground offline), then Restore with nothing to restore on a loaded paywall; and with prices failing to load, tap RESTORE and see the retry block stay. |
| SM-8 | Fixed | `fix: a toggle off during reminder scheduling leaves nothing queued` | `testTurningRemindersOffWhileSchedulingLeavesNothingQueued`; control `testScheduleQueuesTheWholeHorizon` | Every `cancelAll()` bumps a queue generation. `scheduleDailyReminder` stops when the generation moved across an await (toggle off, lapse or a newer schedule), and clears the request added across the cancel when reminders are now off. Requests go through a `ReminderQueue` seam so a fake can interleave the toggle. |
| SM-7r | Fixed | `fix: a load asked for during a load runs after it`; follow-up `fix: commit the goal of a streak tracked during a load's last step` | `testRefilterDuringALoadDoesNotWriteOldGoalsBack`, `testLoadRequestedDuringALoadRunsAfterIt`, follow-up `testStreakTrackedDuringALoadsLastStepGetsItsGoalCommitted` | `load()` called while a load runs records the request and runs once more when the current load ends, so RECALIBRATE, lookback, freeze and revive changes land. `refilter()` no longer commits thresholds while a load runs or is pending (that load commits from fresh goals), so a pin or untrack cannot write the old goals back.  Follow-up (verify note 2): a successful load commits once more after its reminder step through `commitThresholdsAfterLoad()` (fill-missing only, from this load's goals, skipped when another load is queued), so a streak tracked in that window gets its goal committed now instead of at the next load. |
| SM-9 | Fixed | `fix: day math follows a device time zone change` | `testSharedCalendarFollowsASystemZoneChange` (the review's `TZ` plus `resetSystemTimeZone()` seam) | `DateHelpers.gregorian` is a locked cached calendar whose zone is reset to `TimeZone.current` when it differs, instead of a calendar built once. Monday-first weeks are kept. |

## Held for Jack

- Verify note 4 (UX, not a bug): Settings RECENT SAVES now lists every save in the last 30 days, where before it showed at most one per streak, because it reads the full `saveLog` (SM-4). Decision: keep the full 30-day list, or cap Settings to the latest N saves (Saves and Stats keep the full log either way).

## Skipped

None.

## Disputed

None. The verify report's one must-change item (P-11 removes the "PRICES DIDN'T LOAD" block on Restore) is correct: `productBlock` read `storeKit.lastError` (`PaywallView.swift:245` before the follow-up) and `restore()` clears it (`StoreKitService.swift:438`). 
## Verify notes

| Note | Outcome | Evidence |
|---|---|---|
| 1, SM-5 cold-launch refilter | No change | The queue it builds comes from the snapshot, and the snapshot is written by the same `refilter()` and load that last rebuilt the queue (`persistCurrentSnapshot()` beside each `scheduleReminders`, `StreakStore.swift:56-69`). When the launch load bails early the queue holds the same streaks the previous one did. |
| 2, SM-7r skipped commit | Fixed | See the SM-7r row. |
| 3, SM-1 with empty `allCandidates` | No change, no route | The broken-streak sheet is shown only after a load has set `allCandidates`, as the report says. |
| 4, uncapped RECENT SAVES | Held for Jack | See "Held for Jack". |
| 5, calendar lock cost | No change | Suite time shows no cost; not a defect. |
| 6 | No change | Statement that the new tests passed. |

## Test results

All runs on GitHub's Macs, Xcode 27.1, iPhone 17, iOS 27.2.

| Run | Id | Result |
|---|---|---|
| Verify round, full suite on the final tree (both follow-ups) | `fitness-streaks@20261107-043342-851c-claude-imac5a95-1107-050539-21328` (GitHub run 42375373034) | Passed: 158 passed, 0 failed, 0 skipped |
| Verify round, full suite with the P-11 follow-up only | `fitness-streaks@20261107-043342-851c-claude-imac5a95-1107-043504-2664` (GitHub run 42373143802) | Passed: 157 passed, 0 failed, 0 skipped |
| First round, full suite, `gh-sim test --scheme FitnessStreaks` | `fitness-streaks@20261106-225834-5698-claude-imacc8fa-1107-003714-8879` (GitHub run 42356263273) | Passed: 157 passed, 0 failed, 0 skipped |
| Targeted, `--only` StateMachineRegressionTests, BugHuntRegressionTests, PaidFeatureTests | `fitness-streaks@20261106-225834-5698-claude-imacc8fa-1106-230815-5670` (GitHub run 42349993595) | Passed: 68 passed, 0 failed |
| Proof: `StateMachineRegressionTests` on a copy of the final tree with each fix's logic reverted and the seams kept | `fs-reverted-imacc8fa-1106-235107-22909` (GitHub run 42352987440) | 13 failed, 6 passed, as intended |

The proof run shows each regression test fails without its fix: every bug test failed on its final assertion (SM-1 `Optional(0)` vs `Optional(30)`; SM-2 `[]` vs `["steps-daily"]`, for Pro and free; SM-4 `1` vs `2`; SM-5 expectation unfulfilled; SM-6 onboarding order instead of the pinned order; SM-3 both banner cases; SM-8 requests 10 to 30 still queued after the toggle off; SM-7r `10000.0` written back and the load request dropped; SM-9 `GMT` vs `Pacific/Auckland`). The six controls passed in it: `testReviveOnTheDetectionDayRestoresTheRun`, `testReviveOnTheNextDayAfterMeetingTheGoalKeepsThatDay`, `testRecordForTheSameMissIsNotRecordedTwice`, `testOnboardingRestoreWithoutAPinKeepsTheOnboardingOrder`, `testSaveLogUpgradeKeepsTheSavesStoredBeforeIt`, `testScheduleQueuesTheWholeHorizon`. The review's runs on the audited code had already shown the same failures for SM-1, SM-2, SM-4, SM-6 and SM-9.

No test failed in the full suite, so none needed a rerun on `5e0e167`, and no test that already failed on `5e0e167` is known. `python3 Tools/Localization/check.py`: 0 problems (no new copy).

Verify round: no test failed, so none needed a run on `5e0e167`. `testStreakTrackedDuringALoadsLastStepGetsItsGoalCommitted` fails without its fix by construction: its precondition asserts the goal is uncommitted right before `commitThresholdsAfterLoad()`, and before the fix nothing commits in that window. The P-11 follow-up has no headless test (the test target compiles the stub `StoreKitService`). `python3 Tools/Localization/check.py`: 756 keys, 0 problems (no new copy).

Device checks still worth doing, since they have no headless seam: SM-3 (revoke notifications in iOS Settings, return to Settings, see the banner; allow again, see it clear) and P-11 (fail a purchase, then Restore with nothing to restore on a loaded paywall; with prices failing to load, tap RESTORE and see PRICES DIDN'T LOAD and TRY AGAIN stay).
