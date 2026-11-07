VERDICT: PASS

# Verification of the 2026-11-06 state machine fixes (round 2)

Independent check of `state-machines-2026-11-06-fixes.md` against `state-machines-2026-11-06-review.md` and the audit's transition tables, after the verify-round follow-ups. Range read in full: `git diff 5e0e167..c88254c` (app code, tests, docs; `c88254c` is an empty snapshot commit on top of `180df23`). No app code or test was changed here. This replaces the round 1 report (FAIL on a P-11 regression), which is now fixed.

All ten fixes work on their review routes, both follow-ups hold, the suite is green with every added test passing, and the fail-without-fix proof reproduced for the top three.

## Fixes

| ID | Works | Regression check | Evidence |
|---|---|---|---|
| SM-1 | Yes | None found | `reviveBrokenStreak` records `revivePreservation(for:current:now:)` (`StreakStore.swift:753-759`, `:766-789`). On the review's route (miss D-1, D unmet, buy on D+1) the engine's `current` is 0, so the save moves to D (`:776`) and the run of 30 is bridged; if D was met, the new run starts on D, the save stays on D-1 and D is kept (31). Weekly and older records keep the record's own day. The sheet's `canRevive` gate and offer are untouched (`BrokenStreakSheet.swift:204-209`, not in the diff). `testReviveOnTheNextDayAfterAnotherMissRestoresTheRun` drives the real `revivePreservation` plus `StreakEngine.discover` and fails without the fix (proof run below). Device check left open: the purchase, the revive with live `allCandidates`, and the reload. |
| SM-2 | Yes | None found | `handleBreaks` delegates to pure `applyBreaks` (`StreakStore.swift:694-741`). Only a record for the same missed day skips (`:704-707`). Pro: the new miss is saved, the old record is left. Free: the old record for that key is replaced and the new one announced (`:733-735`); the replaced record's revive window (`brokenAt` within 1 day) had already closed, since a new miss needs a fresh run of 3 or more. `needsRediscover` compares the arrays (`:351`), so a same-count replacement still rediscovers. Saves and records are written before the `notifyStreakBroken` awaits. `testProMissIsSavedWhileAnOlderRecordIsOpen` fails without the fix. |
| SM-4 | Yes | Upgrade safe | `recordSave` writes the bridge entry and appends to `saveLog` (`StreakSettings.swift:579-582`); both writers use it (`StreakStore.swift:674`, `:756`). Readers: Stats (`StatsView.swift:118`), Saves (`SavesView.swift:118`, row id now the save itself), Settings (`SettingsView.swift:243`). Upgrade: no `saveLog` key, so the log is seeded from `gracePreservations` (`StreakSettings.swift:497-499`, `:586-589`); the `gracePreservations` key and format are unchanged and nothing else writes or prunes it. `testSecondSaveOnTheSameStreakIsCounted` fails without the fix; `testSaveLogUpgradeKeepsTheSavesStoredBeforeIt` covers the seed. Screenshot: Stats "STREAKS+ SAVES TO DATE 2", Saves two Recent Saves rows. |
| SM-5 | Yes | None found | `refilter()` rebuilds the queue when reminders are on (`StreakStore.swift:65-69`); every untrack, pin, picker save, restart and subscribe reaches it. On watchOS `refilter()` is never called. Free or lapsed users with a stale `notificationsEnabled` hit `remindersWanted == false` in `scheduleDailyReminder` and only cancel. `testRefilterRebuildsTheReminderQueue` asserts the seam got the new tracked set; it does not see the real notification center. Device check: untrack, background, read pending requests. |
| SM-6 | Yes | None found | The restore keeps the user's order of the trimmed picks and appends the restored picks (`StreakSettings.swift:573-574`). With no pin the result equals the old one (control test). `testPinToTopSurvivesTheOnboardingRestore` drives the real restore. Onboarding screens and the trial offer are untouched. |
| SM-3 | Yes | None found | Settings reads the permission on `.task` and on `scenePhase == .active` (`SettingsView.swift:117-120`, `:601-608`); the decision is `showsBlockedBanner` (`NotificationService.swift:232-239`). The toggle is never switched off by the read; a free user with reminders off and no banner still sees none. The test covers the pure decision only. Device check: revoke in iOS Settings, return, see BLOCKED; allow, return, see it clear. |
| P-11 | Yes | Round 1 regression fixed | `purchase()` and `restore()` clear `lastError` first (`StoreKitService.swift:396`, `:438`), so Restore with nothing to restore shows "NO ACTIVE PURCHASES FOUND." (`PaywallView.swift:597`), and `TrialOfferSheet.swift:358` likewise. Follow-up: the price-load failure lives in `productLoadError`, written only by `loadProducts()` (`StoreKitService.swift:200`, `:293`, `:300`, `:304`), and `productBlock` reads it (`PaywallView.swift:245`), so Restore no longer hides PRICES DIDN'T LOAD, TRY AGAIN (`:405-406`, calls `loadProducts`) or NOT NOW. Every other `lastError` reader (`App.swift:495`, `BrokenStreakSheet.swift:186`, `OnboardingView.swift:959`, `PaywallView.swift:583`) reads it right after a `purchase()` that sets it on every `.failed` path. The stub `StoreKitService` is unaffected (`PaywallView` is `#if REVENUECAT`). No headless test is possible (stub in the test target). Screenshot: the real `PaywallView` on the simulator shows the retry block from `productLoadError`. Device checks: fail a purchase, then Restore with nothing to restore; with prices failing, tap RESTORE and see the block stay. |
| SM-8 | Yes | None found (see note 1) | `cancelAll()` bumps `queueGeneration` (`NotificationService.swift:213`); the loop stops before and after each `add` once it moved (`:79`, `:85-89`) and clears the request added across a toggle off (`:87`). `testTurningRemindersOffWhileSchedulingLeavesNothingQueued` runs the real scheduler against a fake queue that interleaves the toggle; `testScheduleQueuesTheWholeHorizon` is the control. |
| SM-7r | Yes | None found (see note 2) | `load()` during a load sets `reloadRequested` and the loop reruns once after (`StreakStore.swift:224-232`). `refilter()` skips the commit while a load runs or is queued (`:61-63`). Follow-up: `commitThresholdsAfterLoad()` (`:75-78`) runs after the reminder step (`:380-381`), fill-missing only, skipped when a load is queued. Every action that clears goals (per-streak RECALIBRATE `StreakDetailView.swift:428-431`, `:487-490`; RECALIBRATE ALL `SettingsView.swift:131-133`, `:384-386`; hiding a metric `:651-654`) also calls `load()`, so in the reminder window it sets `reloadRequested` and the follow-up commit is skipped: no old goal is written back. `refreshIfNeeded` returns while loading (`:213`), so foregrounding does not queue extra loads. Tests assert the flags and the commit; device check: RECALIBRATE ALL during the load's last step, then confirm new goals. |
| SM-9 | Yes, given iOS resets `TimeZone.current` in a running app | None found | `DateHelpers.gregorian` is a lock-guarded cached calendar reset to `TimeZone.current` when it differs (`DateHelpers.swift:8-21`), still Monday-first. No caller caches it beyond a local `let`. Widgets and the watch compile it (full run). `testSharedCalendarFollowsASystemZoneChange` moves the real process zone. Device check: change zone with the app suspended, reopen. |

## Fail-without-fix proof (top three: SM-1, SM-2, SM-4)

On a throwaway branch `scratch-revert` I reverted only the logic and kept every test and the seams they call: `applyBreaks` got back the any-open-record guard, `revivePreservation` returned the record's own missed day, and `recordSave` rebuilt the log one per key (the old count). The three tests ran in one `--only` run and all failed on their final assertions: SM-1 `Optional(0)` vs `Optional(30)` (its precondition passed), SM-2 `[]` vs `["steps-daily"]`, SM-4 `1` vs `2`. The branch was deleted; this branch carries only the doc commit on top of what was given.

The SM-7r follow-up test `testStreakTrackedDuringALoadsLastStepGetsItsGoalCommitted` cannot compile without its fix (it calls `commitThresholdsAfterLoad()`); its precondition proves the refilter skipped the commit. It asserts the hook's effect, not that `performLoad` calls it; the call at `StreakStore.swift:381` is confirmed by reading.

## Disputed, held and skipped

- Disputed: the fixes doc lists none, and states the round 1 must-change was correct. Nothing to rule on.
- Held for Jack: verify note 4 (Settings RECENT SAVES now lists every save in 30 days). Correctly held: it is a UX call raised by the verify report, not a review claim, and the code was not changed (`SettingsView.swift:241-245`).
- Skipped: none. SM-7 (NOT A BUG as routed) is correctly left alone; its residual SM-7r is fixed.

## Must change

Nothing.

## Scope (check 4)

- Every change maps to a listed claim or to the round 1 must-change and note 2. The `ReminderQueue`, `scheduleReminders`, `productLoadError`, seeded `saveLog` and `needsRediscover` changes exist only to serve SM-8, SM-5, P-11, SM-4 and SM-2.
- No change to trial or onboarding flows, prices, offers, `canRevive`, how membership is judged, or when or to whom a paywall or trial appears. `productLoadError` only restores the retry block's pre-change visibility.
- No backend, App Store Connect or RevenueCat change.
- No claim was UNVERIFIED in the review.
- Nothing is cleared on an inferred state. SM-2's free branch replaces an older record only when fresh Health data shows a new miss for that streak; the save-or-record choice is the unchanged `attemptAutoSave(isPro:)`, and the replaced record could no longer be revived. The Pro branch keeps it.
- No stored format changed: `saveLog` is a new key seeded from existing saves.
- All 10 in-scope claims are in the fixes table; none skipped; the one held item is unchanged.

## Tests

| Run | GitHub run | Result |
|---|---|---|
| Full suite plus screenshots, `gh-sim all --scheme FitnessStreaks` on HEAD `c88254c`, id `fitness-streaks@20261107-052126-ea43-claude-imac8274-1107-052232-17561` | 42376676319 | Passed: 158 passed, 0 failed, 0 skipped (291 s). All 18 `StateMachineRegressionTests` passed; the edited `BugHuntRegressionTests` passed. Watch and watch widget targets built. |
| Proof, SM-1, SM-2 and SM-4 logic reverted with tests kept, `--only` the three tests, id `fitness-streaks@20261107-052126-ea43-claude-imac8274-1107-053708-6399` | 42377795557 | 0 passed, 3 failed as intended (values above) |

Matches the fixes doc's final run (158 passed, 0 failed). No test failed, so no `5e0e167` comparison was needed. `python3 Tools/Localization/check.py`: 756 keys, 0 problems (no new copy).

## Screens

From run 42376676319 (iPhone 17, seeded, Pro):
- Paywall (`-PaywallSnapshot monthly`, real `PaywallView`): PRICES DIDN'T LOAD with "Plans are available on device and TestFlight.", TRY AGAIN and NOT NOW, now driven by `productLoadError`. Tapping RESTORE is not possible in the launch harness, and simulator restores always error, so the Restore states stay device checks.
- Stats: "STREAKS+ SAVES TO DATE 2" from `saveLog`; layout unchanged.
- Saves: two Recent Saves rows (Exercise, Steps) with the new row ids; layout unchanged.
- Settings: `-DuoScreen streaks/settings` on a folded iPhone 17 shows the dashboard (Settings opens in the pane only when split), so the Settings changes (permission read, RECENT SAVES) were not captured here. Round 1 captured Settings in the iPhone Duo trailing pane (run 42370857011) with the same SettingsView code. The BLOCKED banner needs a real iOS permission change.

## Notes

1. SM-8, minor residual, not a regression: when a newer schedule (a refilter or time change) cancels while an older one is suspended in `add`, the older request lands after the cancel and the older loop returns with reminders still wanted (`NotificationService.swift:85-89`). If the newer schedule queues fewer requests (none when no streak has reached 2), that one stray request stays until the next schedule. Before the fix the older loop kept adding all 31.
2. SM-7r, pre-existing and outside the review's route: a RECALIBRATE during `handleBreaks`'s `notifyStreakBroken` await is still written back by the commit at `StreakStore.swift:368`. It needs a new break record with `notificationsEnabled` true, which for a free user only happens after a lapse (review P-7). The review established no window on this path for its routes.
3. SM-1 on the D+1 route bridges two misses (D-1 and D) with one save, which is what two Streaks+ auto-saves would have produced; the gate that limits when the revive is offered is unchanged.
4. SM-5 cold launch: with no widget snapshot, the launch `refilter()` (`App.swift:331-335`) clears the queue until the launch load rebuilds it. Low impact, as round 1 note 1.
5. Every test this change added or edited passed on HEAD in the full run.
