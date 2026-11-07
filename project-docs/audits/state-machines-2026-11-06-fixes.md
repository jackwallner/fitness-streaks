# Fixes for the 2026-11-06 state machine audit

Fixes for every claim `state-machines-2026-11-06-review.md` marked CONFIRMED, in the review's ranked order, on branch `fleet/20261106-225834-5698-claude` from `5e0e167`. The review left nothing UNVERIFIED and listed SM-7 (as routed) as NOT A BUG, so SM-7 is untouched; its confirmed residual SM-7r is fixed. Product calls other than the misfiled P-11 are left alone.

**Summary: 10 in scope. 10 fixed, 0 held, 0 skipped.**

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
| P-11 | Fixed | `fix: restore and purchase show only their own error` | none: the test target compiles the stub `StoreKitService` (no `REVENUECAT`), so `restore()` and `purchase()` cannot run headless | `purchase()` and `restore()` clear `lastError` before they start, so Restore with nothing to restore shows "NO ACTIVE PURCHASES FOUND." instead of an earlier error. Device check: fail a purchase (or foreground offline), then tap Restore on a loaded paywall. |
| SM-8 | Fixed | `fix: a toggle off during reminder scheduling leaves nothing queued` | `testTurningRemindersOffWhileSchedulingLeavesNothingQueued`; control `testScheduleQueuesTheWholeHorizon` | Every `cancelAll()` bumps a queue generation. `scheduleDailyReminder` stops when the generation moved across an await (toggle off, lapse or a newer schedule), and clears the request added across the cancel when reminders are now off. Requests go through a `ReminderQueue` seam so a fake can interleave the toggle. |
| SM-7r | Fixed | `fix: a load asked for during a load runs after it` | `testRefilterDuringALoadDoesNotWriteOldGoalsBack`, `testLoadRequestedDuringALoadRunsAfterIt` | `load()` called while a load runs records the request and runs once more when the current load ends, so RECALIBRATE, lookback, freeze and revive changes land. `refilter()` no longer commits thresholds while a load runs or is pending (that load commits from fresh goals), so a pin or untrack cannot write the old goals back. |
| SM-9 | Fixed | `fix: day math follows a device time zone change` | `testSharedCalendarFollowsASystemZoneChange` (the review's `TZ` plus `resetSystemTimeZone()` seam) | `DateHelpers.gregorian` is a locked cached calendar whose zone is reset to `TimeZone.current` when it differs, instead of a calendar built once. Monday-first weeks are kept. |

## Held for Jack

None.

## Skipped

None.

## Test results

All runs on GitHub's Macs, Xcode 27.1, iPhone 17, iOS 27.2.

| Run | Id | Result |
|---|---|---|
| Full suite, `gh-sim test --scheme FitnessStreaks` on the final tree | `fitness-streaks@20261106-225834-5698-claude-imacc8fa-1107-003714-8879` (GitHub run 42356263273) | Passed: 157 passed, 0 failed, 0 skipped |
| Targeted, `--only` StateMachineRegressionTests, BugHuntRegressionTests, PaidFeatureTests | `fitness-streaks@20261106-225834-5698-claude-imacc8fa-1106-230815-5670` (GitHub run 42349993595) | Passed: 68 passed, 0 failed |
| Proof: `StateMachineRegressionTests` on a copy of the final tree with each fix's logic reverted and the seams kept | `fs-reverted-imacc8fa-1106-235107-22909` (GitHub run 42352987440) | 13 failed, 6 passed, as intended |

The proof run shows each regression test fails without its fix: every bug test failed on its final assertion (SM-1 `Optional(0)` vs `Optional(30)`; SM-2 `[]` vs `["steps-daily"]`, for Pro and free; SM-4 `1` vs `2`; SM-5 expectation unfulfilled; SM-6 onboarding order instead of the pinned order; SM-3 both banner cases; SM-8 requests 10 to 30 still queued after the toggle off; SM-7r `10000.0` written back and the load request dropped; SM-9 `GMT` vs `Pacific/Auckland`). The six controls passed in it: `testReviveOnTheDetectionDayRestoresTheRun`, `testReviveOnTheNextDayAfterMeetingTheGoalKeepsThatDay`, `testRecordForTheSameMissIsNotRecordedTwice`, `testOnboardingRestoreWithoutAPinKeepsTheOnboardingOrder`, `testSaveLogUpgradeKeepsTheSavesStoredBeforeIt`, `testScheduleQueuesTheWholeHorizon`. The review's runs on the audited code had already shown the same failures for SM-1, SM-2, SM-4, SM-6 and SM-9.

No test failed in the full suite, so none needed a rerun on `5e0e167`, and no test that already failed on `5e0e167` is known. `python3 Tools/Localization/check.py`: 0 problems (no new copy).

Device checks still worth doing, since they have no headless seam: SM-3 (revoke notifications in iOS Settings, return to Settings, see the banner; allow again, see it clear) and P-11 (fail a purchase, then Restore with nothing to restore on a loaded paywall).
