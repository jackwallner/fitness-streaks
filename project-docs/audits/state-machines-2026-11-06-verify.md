VERDICT: FAIL

# Verification of the 2026-11-06 state machine fixes

Independent check of the fixes in `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the audit's transition tables. Range read: `git diff 5e0e167..effc901` (app code, tests, docs). No app code or test was changed here.

Nine of the ten fixes work on their review routes, and the suite is green. The check fails on one regression that P-11's fix introduces in a neighbouring state of the paywall (below). Everything else is either verified or listed as a device check.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| SM-1 | Yes | None found | `reviveBrokenStreak` writes `revivePreservation` (`StreakStore.swift:747`, `:757-779`). On the review's route (miss D-1, D unmet, buy on D+1) `current` is 0, so the save is dated D (`:767`) and the engine bridges 30. If D was met the save stays on D-1 and keeps D (31). The `canRevive` gate and the offer are unchanged (`BrokenStreakSheet.swift:204-209`). Test `testReviveOnTheNextDayAfterAnotherMissRestoresTheRun` drives the real `revivePreservation` and `StreakEngine.discover`. It fails without the fix (proof run below: `Optional(0)` vs `Optional(30)`, precondition passed). Device check left open: the purchase, `reviveBrokenStreak` with live `allCandidates`, and the reload. |
| SM-2 | Yes | None found | `handleBreaks` now delegates to pure `applyBreaks` (`StreakStore.swift:659-669`, `:685-728`). Only a record for the same missed day skips (`:695-698`). A Pro miss is saved and the old record is left alone. A free miss replaces the older record for that key (`:724`), and a later miss on the same streak is at least two days after the old `brokenAt`, so `canRevive` (`BrokenStreakSheet.swift:204-209`) had already closed on it. `needsRediscover` now compares arrays (`:343`), so a same-count replacement still rediscovers. Records and saves are written before the `notifyStreakBroken` awaits, which also closes the old lost-update window. Test `testProMissIsSavedWhileAnOlderRecordIsOpen` fails without the fix (`[]` vs `["steps-daily"]`). |
| SM-4 | Yes | Upgrade safe | `recordSave` writes the bridge entry and appends to `saveLog` (`StreakSettings.swift:579-582`). Both writers use it (`StreakStore.swift:665`, `:747`). Readers: Stats `totalSaves` (`StatsView.swift:118`), Saves (`SavesView.swift:117-126`), Settings (`SettingsView.swift:209`, `:241-245`). Upgrade: with no `saveLog` key the log is rebuilt from `gracePreservations` on every launch until the first new save persists it (`StreakSettings.swift:497-499`, `:586-589`). The `gracePreservations` format is unchanged and nothing else writes or prunes it. Test `testSecondSaveOnTheSameStreakIsCounted` fails without the fix (`1` vs `2`). Screenshots: Stats "STREAKS+ SAVES TO DATE 2" and two Recent Saves rows. |
| SM-5 | Yes | See note 1 | `refilter()` rebuilds the queue when reminders are on (`StreakStore.swift:65-69`). Every untrack, pin, picker save and restart reaches it. A refilter racing a load's own schedule is resolved by SM-8's generation check: the later schedule wins. `testRefilterRebuildsTheReminderQueue` asserts only that the hook received the new tracked set. Device check left open: untrack, background, then read `getPendingNotificationRequests`. |
| SM-6 | Yes | None found | The restore keeps the user's order of the trimmed picks and appends the rest (`StreakSettings.swift:571-574`). With no pin, the trimmed order is the onboarding prefix (`OnboardingView.swift:801-805`, `:829-836`), so the old result is unchanged (control test). `testPinToTopSurvivesTheOnboardingRestore` drives the real restore. |
| SM-3 | Yes | None found | Settings reads the permission on `.task` and on `scenePhase == .active` (`SettingsView.swift:117-120`, `:601-608`). The decision is `showsBlockedBanner` (`NotificationService.swift:232-239`). Denied with reminders on shows the banner. Allowed clears it. A fresh prompt deny still shows none, as before. The toggle is never switched off by the read. The test covers the pure decision only. Device check left open: revoke in iOS Settings, return, see BLOCKED; allow, return, see it clear. |
| P-11 | Yes, on the review's route | **Regression** | `purchase()` and `restore()` clear `lastError` first (`StoreKitService.swift:393`, `:435`). On a paywall with loaded prices, Restore with nothing to restore now shows "NO ACTIVE PURCHASES FOUND." (`PaywallView.swift:597`). But see "Must change". No test exists (stub `StoreKitService` in the test target). |
| SM-8 | Yes | None found | `cancelAll()` bumps `queueGeneration` (`NotificationService.swift:213`). The loop stops before and after each `add` once the generation has moved (`:79`, `:85-89`), and clears the request added across a toggle off (`:87`). Two near-simultaneous schedules (the hour and minute `onChange`, or a refilter racing a load) now leave the later one's queue only. `testTurningRemindersOffWhileSchedulingLeavesNothingQueued` runs the real scheduler against a fake queue that interleaves the toggle. |
| SM-7r | Yes | See note 2 | `load()` during a load sets `reloadRequested` and the loop reruns once after (`StreakStore.swift:215-225`). `isLoading` goes false then true with no await in between, so "RECALIBRATING…" (`SettingsView.swift:114-116`) stays up through the rerun. `refilter()` skips `commitThresholds` while loading or pending (`:61-63`). On watchOS and in seeded screenshot mode `performLoad` returns before setting `isLoading`, so the loop cannot spin. Nothing a load runs calls `load()`. Both tests assert flags and the skipped commit. Device check left open: RECALIBRATE ALL GOALS during the load's last step, then confirm the new goals land. |
| SM-9 | Yes, given iOS refreshes `TimeZone.current` | None found | `DateHelpers.gregorian` is now a lock-guarded cached calendar reset to `TimeZone.current` on each read (`DateHelpers.swift:8-21`), and stays Monday-first. No other code caches it in a `static let`. `testSharedCalendarFollowsASystemZoneChange` moves the real process zone (`TZ` plus `resetSystemTimeZone`). Device check left open: change the zone with the app suspended, reopen, and confirm the day split moved. The fix relies on iOS resetting the system zone cache for a running app. |

Fail-without-fix proof (the top three, SM-1, SM-2 and SM-4): on a throwaway branch I reverted only the logic and kept the seams the tests call. `applyBreaks` got the old any-open-record guard, `revivePreservation` got the record's own missed day, and `recordSave` got a log rebuilt one per key. All three tests failed on their final assertions, and the SM-1 precondition passed. The branch was deleted afterwards. It was named `scratch-revert-2205` because another fleet session's worktree already holds `scratch-revert` in the shared repo.

## Disputed

The fixes doc has no "Disputed" section and lists nothing as disputed, so there is nothing to rule on. Held: none. Skipped: none. SM-7 (NOT A BUG as routed) is correctly left out, and its residual SM-7r is fixed.

## Must change

1. **P-11 removes the paywall's "PRICES DIDN'T LOAD" block on Restore.** `PaywallView.productBlock` shows the price-load error and its TRY AGAIN and NOT NOW buttons only while `storeKit.lastError` is set and no packages loaded (`PaywallView.swift:234-246`, `:394-424`). `restore()` now clears `lastError` the moment it starts (`StoreKitService.swift:435`).
   - Route: any paywall whose prices failed to load (for example, a RevenueCat offerings or App Store product fetch failure while `customerInfo` still works). Tap RESTORE with nothing to restore.
   - Before the fix: the block stayed (the status line showed the wrong message, which was the P-11 bug).
   - Now: the block disappears as soon as RESTORE is tapped and does not return on success. The plans area is blank, with no TRY AGAIN. The only way to retry is CLOSE and reopen.
   - This is the audit's M1 transition "any | restore finds nothing". Keep the attempt-scoped message without wiping the load error. Two options: hold the price-load error in its own property for `productBlock`, or have the paywall's `restore()` read only an error set during this attempt.

## Scope (check 4)

- Every change maps to a listed claim. The `ReminderQueue` seam, the `scheduleReminders` hook, the seeded `saveLog` and the `needsRediscover` comparison exist only to serve SM-8, SM-5, SM-4 and SM-2.
- Paywalls, trials and membership are untouched: no change to `canRevive`, the offers, when a paywall or trial appears, or how membership is judged. The onboarding order of screens is unchanged too: SM-6 changes only the stored order after a restore.
- Nothing needs a backend, App Store Connect or RevenueCat change.
- No claim was UNVERIFIED in the review.
- No stored setting or record is cleared on a cached entitlement. SM-2's free branch replaces an older record because a new miss was detected, and that record could no longer be revived. The Pro branch keeps it.
- No stored format changed. `saveLog` is a new key, and existing saves seed it.
- All 10 in-scope claims are in the fixes table, with none held or skipped.

## Tests

| Run | GitHub run | Result |
|---|---|---|
| Full suite plus screenshots, `gh-sim all --scheme FitnessStreaks` on HEAD `effc901`, id `fitness-streaks@20261107-020643-2205-claude-mbpro3a18d-1107-022031-11701` | 42363545702 | Passed: 157 passed, 0 failed, 0 skipped. All 17 `StateMachineRegressionTests` passed. Watch and watch widget targets compiled for watchsimulator. |
| Proof, fixes for SM-1, SM-2 and SM-4 reverted with tests kept, `--only` the three tests, id `fitness-streaks@20261107-020643-2205-claude-mbpro3a18d-1107-033203-28061` | 42368577973 | 0 passed, 3 failed as intended: `Optional(0)` vs `Optional(30)`; `[]` vs `["steps-daily"]`; `1` vs `2` |
| First proof attempt from a git worktree, id `scratch-mbpro3a18d-1107-030532-14739` | 42366701023 | Infrastructure failure (gh-sim could not find the worktree folder in the repo). Proves nothing; rerun above. |
| iPhone Duo launch, `-DuoScreen streaks/settings`, id `fitness-streaks@20261107-020643-2205-claude-mbpro3a18d-1107-040425-25219` | 42370857011 | Launched; unfolded capture shows Settings in the trailing pane |

These match the fixes doc's 157 passed, 0 failed. No test failed, so no 5e0e167 comparison was needed. `python3 Tools/Localization/check.py`: 756 keys, 0 problems (no new copy).

## Screens

- Stats (iPhone 17, seeded, Pro): "STREAKS+ SAVES TO DATE 2", from `saveLog`.
- Saves: two Recent Saves rows (Exercise, Steps) with the new row ids. Layout is unchanged.
- Settings (iPhone Duo, unfolded): Settings mounts in the trailing pane and renders normally with the new `.task` and `scenePhase` reads. The capture shows the top of the screen only. RECENT SAVES and NOTIFICATIONS are further down and not in the shot, and the launch harness cannot scroll. The iPhone 17 `streaks/settings` route opens Settings only when split, so it showed the dashboard.
- The BLOCKED banner (SM-3) and the paywall Restore states (P-11) cannot be reached on a simulator: the permission comes from iOS, and simulator restores always error. Both stay device checks.

## Notes

1. SM-5, minor: the cold-launch `.task` in `App.swift:331-335` refilters for a cached Pro user, which now rebuilds the reminder queue from the snapshot-restored streaks before the launch load. A successful load replaces it seconds later. Only if that load bails early (the data-loss guard, or a HealthKit error) does the queue keep the snapshot-based plans instead of the previous load's. Low impact, not counted.
2. SM-7r, minor: a `refilter()` that lands after a running load has committed thresholds (during its final reminder step) now skips the commit. A streak newly tracked in that sub-second window gets its goal committed at the next load instead.
3. SM-1 relies on `allCandidates` being current when the revive runs. It is current, since the sheet only shows after a load. With empty candidates the save falls back to yesterday, which on D+1 would drop a met day D (30 instead of 31).
4. Settings RECENT SAVES now lists every save in 30 days with no cap, where before it showed at most one per streak. A heavy Pro user could see a long list. This is UX only.
5. SM-9 adds a `TimeZone.current` read and a lock to every `DateHelpers.gregorian` access. The suite time (334 s) shows no visible cost.
6. Every test the change added passed on HEAD in the full run.
