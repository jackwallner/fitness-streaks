# Streak Finder state machine audit, 2026-11-06

Scope: iOS app, `Shared/`, widget, watch app and watch complication, committed code on `main` build 164 (working tree was clean; `git stash -u` found nothing to stash). Android is out of scope. There is no backend function in this repo: entitlement truth is RevenueCat, read through `StoreKitService`. Nothing was fixed and no app code was changed.

**Summary: 9 bugs. 2 proved by test (SM-1, SM-6). 7 code path only (SM-2, SM-3, SM-4, SM-5, SM-7, SM-8, SM-9). 12 product calls, not counted.**

SM-5 has a passing supporting test that shows the pending queue content is stale; it does not prove the scheduler skip, so SM-5 stays code path. SM-9 has no valid test (the time zone seam failed its precondition).

Run: `gh-sim test --scheme FitnessStreaks --only FitnessStreaksTests/StateMachineAuditRepro`, run id `fitness-streaks@20261106-191621-9aba-claude-mbpro354da-1106-202008-2343` (3 passed, 3 failed). Recorded values are quoted in the Evidence column. Passing: `testControlReviveOnDetectionDayRestoresTheRun`, `testControlRestoreAfterSubscribingReAddsTheOtherPicks`, `testSupportingQueueBuiltBeforeUntrackNamesTheUntrackedStreak`. Failing: the two bug tests below, plus `testBugDayMathFollowsTheDeviceTimeZone`, whose own precondition failed (see SM-9), so it is dropped from the repro file and proves nothing.

## Test seams in this repo (checked before marking anything "Code path")

| Seam | Where | Used here |
|---|---|---|
| `StreakEngine.discover(..., now:)` with `committedThresholds`, `gracePreservations`, `plannedFreezes` | `StreakEngine.swift:34` | SM-1 |
| `NotificationService.reminderPlans(for:now:hour:minute:days:)` (pure) | `NotificationService.swift:112` | SM-5 supporting |
| `StreakStore.detectBreaks`, `visibleStreaks`, `applyTrackedFilter`, `detectLikelyDataLoss`, `mergeWithCacheForMissingDays` (static, pure) | `StreakStore.swift` | SM-5 supporting |
| `StreakSettings.shared` (App Group defaults, mutable between tests; no injectable suite) | `StreakSettings.swift:260` | SM-6 |
| `StoreKitService.debugSetPro`, `debugSetPurchaseGrantsFullStreakAccess` (DEBUG, stub class) | `StoreKitService.swift:608-617` | none needed |
| `ConversionDiagnostics.defaultsOverride`, `ReviewPromptTracker` (App Group defaults) | `ConversionDiagnostics.swift:34` | machine docs only |
| `NSTimeZone.default` | process wide | tried for SM-9, does not move `TimeZone.current` (recorded GMT after setting Pacific/Auckland), unusable |
| `StreakSnapshot.asOf(_:)`, `SnapshotStore.encode/decode` | `StreakSettings.swift:222` | machine docs only |

Not available, and why the notification and purchase claims stay "Code path":

- `NotificationService` is an `enum` of statics that call `UNUserNotificationCenter.current()` directly (`NotificationService.swift:57`, `:80`, `:178`, `:207`). There is no injected scheduler. `FitnessStreaksTests` is an un-hosted bundle (no `TEST_HOST` in `project.yml:144-155`), where `UNUserNotificationCenter.current()` is not safe to call, and the simulator cannot grant or revoke notification permission from a test. Adding a fake would need an app code change, which this audit may not make.
- The test target does not define `REVENUECAT` (`project.yml:85` sets it on the app target only), so the tests compile the stub `StoreKitService` (`StoreKitService.swift:568-620`). `purchase(package:)`, `isEntitled` and the delegate are not compiled into tests, and there is no constructible `CustomerInfo` fixture.
- `StreakStore.handleBreaks`, `reviveBrokenStreak` and `load` reach HealthKit, SwiftData and the notification center. They were not called from tests.

Scheduler call sites (complete list, from `grep` over `FitnessStreaks`, `Shared`, `FitnessStreaksWatch`):

| Call | File:line | Context |
|---|---|---|
| `scheduleDailyReminder` | `StreakStore.swift:339` | end of a successful `load()` only |
| `scheduleDailyReminder` | `SettingsView.swift:482`, `:485` | notification hour or minute `onChange` |
| `scheduleDailyReminder` | `SettingsView.swift:565` | `enableNotifications()` after permission granted |
| `cancelAll` | `NotificationService.swift:58` | start of every `scheduleDailyReminder` |
| `cancelAll` | `SettingsView.swift:119` | `onChange(of: storeKit.isPro)` to false (only while SettingsView is mounted) |
| `cancelAll` | `SettingsView.swift:438` | toggle turned off |
| `notifyStreakBroken` | `StreakStore.swift:658` | `handleBreaks`, free users only |

`streaks.broken.*` requests are never cancelled by any call (`cancelAll` removes `allReminderIDs` only, `NotificationService.swift:206-208`).

## Bugs, ranked by impact (users reached times cost)

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | File:line |
|---|---|---|---|---|---|---|---|
| SM-1 | The revive offer is gated on the day the break was detected, but the engine can only bridge when the day after the miss was met. | A free user pays (or starts the trial) to "restore on the spot" and the streak stays at 0. The broken record is deleted, so the offer is gone and the run cannot be recovered. | `BrokenStreakSheet.swift:276` "Start a Streaks+ trial and we'll restore your 30-day steps run on the spot." Also `:127`, `SettingsView.swift:232` "we'll revive the run on the spot", `StreakStore.swift:665-670` "the engine bridges the missed day on the next load ... callers should gate this on `canRevive`". | Free user, steps streak of 30. Misses day D-1. First load on day D marks it broken (record `brokenAt` = D, `missedDate` = D-1). User does not meet the goal on D. On D+1: Dashboard, banner "30-day steps run · TAP FOR OPTIONS" (`DashboardView.swift:602`), BrokenStreakSheet, "REVIVE WITH STREAKS+ TRIAL" panel (`BrokenStreakSheet.swift:228`), "START TRIAL · REVIVE STREAK", TrialOfferSheet CTA, App Store confirmation. Needs an Apple ID eligible for the intro offer (or any paid plan). Record lives 14 days (`pruneBroken`), so the offer shows on D+1 to D+13 as long as `days <= 1` from `brokenAt`, i.e. D+1 only. | Every free user with a streak of 3 or more that breaks, who returns on the calendar day after the first load and has not met the goal that day. Breaks are the main free to paid trigger. Cost: a started trial (billed in a week) or a paid plan with nothing restored, and the run is unrecoverable afterwards. | Test, 2 tests: control `testControlReviveOnDetectionDayRestoresTheRun` passes (30). `testBugReviveOnTheNextDayIsOfferedButRestoresNothing` fails with `XCTAssertEqual failed: ("Optional(0)") is not equal to ("Optional(30)")`; its two preconditions (run is 0 without the save, sheet gate returns true on D+1) passed first. The sheet gate is mirrored in the test from the private `canRevive`. | `BrokenStreakSheet.swift:197-209`, `StreakStore.swift:671-689`, `StreakEngine.swift:568-589` |
| SM-2 | A leftover `recentlyBroken` record makes `handleBreaks` skip a new break for the same streak, so a Pro user's streak is neither saved nor recorded. | A paying user's 6-day streak silently resets. No save row, no banner, no sheet. | `SettingsView.swift:229` "Streaks+ auto-saves any day you miss. Your streak survives ... Unlimited, automatic, no action needed." and `StreakSettings.swift:572-575` "Pro: unlimited, every miss is saved". | Free user, steps streak breaks on D (record R created, kept 14 days). User subscribes from Settings, "Unlock" row, PaywallView (not from the BrokenStreakSheet, which is the only place that removes R). Streak rebuilds to 3 or more days, then a miss on D+k with k at most 13. Next load: `detectBreaks` returns the break, `guard !newBroken.contains(where: { $0.key == key })` at `StreakStore.swift:631` hits `continue` before `attemptAutoSave` at `:633`. Subscribing does not clear R: `RootView.onChange(isPro)` (`App.swift:358-366`) and `StoreKitService.setIsPro` do not touch `recentlyBroken`. | Pro subscribers who bought from onboarding, Settings, Saves or picker paywalls while a record was open, and who break the rebuilt streak within the record's 14 days. Cost: the exact loss the plan sells protection against, on a plan they just paid for. | Code path. Settle with a test that seeds `recentlyBroken` and Pro, then drives `handleBreaks` (needs it internal or an injected store); or on device with `-UITestSetPro` plus a seeded record. | `StreakStore.swift:628-645`, `App.swift:358-366`, `BrokenStreakSheet.swift:210-217` |
| SM-3 | The reminder toggle and its "blocked" banner never reconcile with the iOS notification permission. | Pro user revokes notifications in iOS Settings: the toggle still reads ON, no banner, and no reminder ever arrives. The reverse: the user denied once, sees "BLOCKED IN IOS SETTINGS. TAP TO FIX", enables it in iOS Settings, comes back, and the banner is still there. | `SettingsView.swift:488` "Daily nudge at 7:00 PM if a tracked streak isn't locked in yet." with the toggle `accessibilityValue` "On" (`:449`). | Pro. Settings, NOTIFICATIONS, PROACTIVE AT-RISK ALERTS on, allow. iOS Settings, Streaks, Notifications, off. Back to the app, Settings. Toggle ON. `isAuthorized()` is called only inside `scheduleDailyReminder` and `notifyStreakBroken` (`NotificationService.swift:62`, `:178`); `SettingsView` reads it nowhere, and `notificationsBlockedBySystem` (`:17`) is set only inside `enableNotifications()` (`:559-573`) on a tap. | Pro users with reminders on who later change the system permission, or who first denied. Cost: the paid reminder feature silently stops, the exact thing the toggle says is running. | Code path. Settle on a device: grant, revoke in iOS Settings, return, read the toggle and `getPendingNotificationRequests`. | `SettingsView.swift:17`, `:429-441`, `:451`, `:559-573`, `NotificationService.swift:57-62` |
| SM-4 | Saves are stored one per streak key, so a second save overwrites the first. The "saves to date" count and the Recent Saves list undercount. | A Pro user saved 5 times on steps sees SAVES 1 and one row. Earlier saves vanish from the log. | `StatsView.swift:149` "STREAKS+ SAVES TO DATE" (and the SAVES tile at `:65`); `SavesView.swift:117-125` "Recent Saves"; `SettingsView.swift:236-241` "RECENT SAVES". | Pro. Miss a day on a streak (auto-saved at the next load, `StreakStore.swift:634`), keep the streak going, miss another day. Stats tab: SAVES 1, expected 2. Saves tab: one steps row. `gracePreservations` is `[String: GracePreservation]` keyed by `trackingKey`; both write sites assign by key (`StreakStore.swift:634`, `:674`) and the display reads `.count` and `.values` (`StatsView.swift:118`, `SavesView.swift:118`). | Every Pro user with two or more misses on the same streak, which is the normal use of the plan. Cost: the headline stat of the paid feature is wrong and the history is lost. The engine itself is unaffected: the latest entry carries the cumulative length. | Code path (dictionary assignment by key; no seam reaches `handleBreaks`). Settle with a test that runs two breaks through `handleBreaks` and reads `gracePreservations.count`. | `StreakStore.swift:633-645`, `:674`, `StatsView.swift:118`, `SavesView.swift:117-125`, `SettingsView.swift:236-241` |
| SM-5 | The reminder queue is rebuilt only at the end of `load()`. Untrack, picker save, "KEEP SAME GOAL" and PIN TO TOP call `refilter()`, which never reschedules. | After untracking the streak the reminders are about, the next 30 daily notifications still say "Time for 10k steps" or "Keep the 10k steps streak alive. You're at 40 days." until the app loads again. | `StreakDetailView.swift:500` "It will disappear from your dashboard." and `NotificationService.swift:111` "Empty when no streak has reached 2, which clears the queue" (queue is meant to track the tracked streaks). | Pro, reminders on. Dashboard, tap the hero (the longest streak), ACTIONS, UNTRACK, Untrack. Close the app. At the reminder time the push names the untracked streak, and again on each following day until a load runs (foreground after 60 s, or a background refresh, which iOS may not grant). Same with Settings, TRACKED STREAKS, SAVE (`StreakPicker.swift:380`). Needs reminders on and the untracked streak to be the longest or most urgent. | Pro users with reminders on who untrack or re-pick streaks and do not reopen the app that day. Cost: a wrong push for a streak the user removed. | Code path with passing supporting test `testSupportingQueueBuiltBeforeUntrackNamesTheUntrackedStreak` (shows the pending queue differs from the one a rebuild would produce). Call sites above show `refilter()` (`StreakStore.swift:56-60`) is not followed by a schedule. Settle on a device: untrack, background, read pending requests. | `StreakStore.swift:56-60`, `StreakDetailView.swift:593-601`, `StreakPicker.swift:376-381`, `DashboardView.swift:775-781` |
| SM-6 | Subscribing re-applies the onboarding order and discards a later PIN TO TOP. | A free user pinned a different streak to the top. After they subscribe the original streak is the hero again. | `StreakSettings.swift:555` "only once: a subscriber's later edits always win" and `StreakDetailView.swift:527-531` "MAKE THIS YOUR PRIMARY / Move to top of dashboard". | Free user picks 5 streaks in onboarding (the default preselects the 5 core metrics, `OnboardingView.swift:779`), declines the trial (trimmed to 3, `:829-837`). Opens the third streak, ACTIONS, PIN TO TOP (`StreakDetailView.swift:603-615`, changes `manualStreakOrder` only). Later subscribes (any paywall). `RootView.onChange(isPro)` or `onChange(purchaseGrantsFullStreakAccess)` runs `restoreOnboardingTrackedStreaksIfNeeded` (`App.swift:347`, `:364`); its guard (`StreakSettings.swift:559-560`) checks the tracked set only, which a pin does not change, so it sets `manualStreakOrder = keys` (`:562`). | Free users who declined the onboarding trial with more than 3 picks (the default), pinned, and later subscribe. Cost: the new subscriber's chosen hero changes the moment they pay. | Test: control `testControlRestoreAfterSubscribingReAddsTheOtherPicks` passes. `testBugPinToTopDoesNotSurviveSubscribing` fails with `XCTAssertEqual failed: ("Optional("steps-daily")") is not equal to ("Optional("standHours-daily")")` on the final first-of-order assertion; its three preconditions (pinned first, 3 tracked, restore ran with 5 tracked) passed first. | `StreakSettings.swift:552-564`, `StreakDetailView.swift:603-615`, `App.swift:341-367` |
| SM-7 | `StreakStore.load()` returns immediately when another load is running, so a user action that needs a reload is dropped, and the running load can undo it. | Settings, RECALIBRATE ALL GOALS shows "RECALIBRATING…" and then the old goals come back. Revive after payment shows 0 until the next refresh. | `SettingsView.swift:349` "This re-derives every goal from your recent Apple Health activity." and `BrokenStreakSheet.swift:276` "on the spot". | Cold launch or foreground, then immediately Settings, RECALIBRATE ALL GOALS (`SettingsView.swift:343-345`) while the launch load is still reading 400 days from HealthKit. `settings.committedThresholds = [:]` runs, `load()` returns at `StreakStore.swift:195`; the running load then calls `commitThresholds(for: filtered)` (`:327`) with the thresholds it already computed, writing the old values back. `onChange(of: store.isLoading)` (`SettingsView.swift:113`) clears the "RECALIBRATING…" text. Same drop for `reviveBrokenStreak` (`StreakStore.swift:688`), freeze add/remove, lookback change and per-streak recalibrate (`StreakDetailView.swift:431`, `:490`). | Users who act within the first seconds of a load. Longer on large Health histories. Cost: a confirmed destructive action silently not applied (recalibrate) or a paid revive that looks like it failed. | Code path. Settle with a unit test on `StreakStore` using an injected history source that suspends, or on device by tapping within a second of foregrounding. | `StreakStore.swift:183-195`, `:327`, `SettingsView.swift:113-115`, `:341-346` |
| SM-8 | `scheduleDailyReminder` is not serialized: cancel, then several suspension points, then 31 adds. A toggle off, an Off from Pro lapse or a second schedule can interleave and leave requests behind. | Reminders keep firing after the user turned them off, or fire at the old time after a time change. | `SettingsView.swift:436-438` toggle off plus `cancelAll()`, `:488` "Daily nudge at \(time)". | Pro. Settings, toggle off within the short window while a `load()` or time-change schedule is mid-loop (`NotificationService.swift:58-85`: `cancelAll`, `await isAuthorized`, then `await center.add` per request). The in-flight task already passed its `notificationsEnabled` guard (`:60`), so it keeps adding after the toggle's `cancelAll()` (`SettingsView.swift:438`). Same for changing the reminder time while a load schedules (the load's plans carry the old time). | Narrow window per event (tens to hundreds of ms), reached at every launch load and every time change. Cost: reminders the user turned off or moved. | Code path. Settle with a fake center behind `NotificationService` (needs an app seam) or on device with a long add loop. | `NotificationService.swift:56-90`, `SettingsView.swift:429-441`, `:481-486` |
| SM-9 | `DateHelpers.gregorian` is a `static let` calendar created once, so its time zone is fixed at first use. Every day boundary (HealthKit buckets, "today", break detection, snapshot `asOf`, freezes) ignores a later change of the device time zone until the process restarts. `Calendar.current` (used in `DashboardView.shouldShowAtRisk`) does follow. | After flying across zones with the app suspended, "today" and the day split are those of the old zone, and the at-risk logic and the engine disagree. | `AGENTS.md` "Today / this-week is treated as 'live' ... Weekly totals: summed per ISO week" and `StreakSettings.swift:220-221` "A snapshot written on an earlier day says nothing about today's progress". | Travel across zones with the app resident in memory (iOS keeps suspended apps for days), open it, Dashboard refreshes through `scenePhase` (`App.swift:250-255`). `fetchHistory` (`HealthKitService.swift:172-177`) buckets by the stale zone; `NSCalendarDayChanged` is the only day signal handled (`App.swift:245`); no `NSSystemTimeZoneDidChange` handler exists. | Travellers who do not kill the app, per trip. Cost: a day bucketed by the old zone can read as missed, a false "STREAK ENDED" (free) or a spurious save (Pro). | Code path. A test attempt through the `NSTimeZone.default` seam failed its own precondition on the runner (`XCTAssertEqual failed: ("GMT") is not equal to ("Pacific/Auckland") - precondition: device zone changed`): `TimeZone.current` did not follow `NSTimeZone.default`, so the seam does not work and no test is claimed. A system zone change is not reproducible in a test. Settle on a device: change zone in iOS Settings with the app suspended, reopen, log `DateHelpers.gregorian.timeZone`. | `DateHelpers.swift:4-8`, `HealthKitService.swift:172-177`, `DashboardView.swift:343` |

## Product calls (not counted)

No citation of a promise, or the code matches a documented rule.

| ID | Call | Where |
|---|---|---|
| P-1 | Reminders are not conditional on the goal still being open. Today's push is built at last load; days 1 to 30 are unconditional ("holds no count", doc comment on `reminderPlans`). A user who meets the goal after the last load and never reopens the app still gets "Keep the 10k streak alive". The settings line says "if a tracked streak isn't locked in yet". Cannot be fixed with local notifications alone; needs HealthKit background delivery or softer copy. | `NotificationService.swift:112-165`, `SettingsView.swift:488` |
| P-2 | "Free tier gets one custom streak" in a comment, `freeCustomLimit = 3` in code. Already raised in audit823. | `StreakPicker.swift:190-195` |
| P-3 | `purchaseGrantsFullStreakAccess` is set after `setIsPro(true)` in `purchase()`, so `isPro && purchaseGrantsFullStreakAccess` is briefly true, and stays true until the next `setIsPro(true)`. If the entitlement is revoked in that window (refund), the free cap stays lifted until relaunch. | `StoreKitService.swift:411-424`, `:534-538` |
| P-4 | A widget or complication snapshot older than a day keeps `current` and only resets today's progress. After two or more days without a refresh it shows "N streak" with no stale cue. | `StreakSettings.swift:222-227`, `FitnessStreaksWidget.swift:47-52` |
| P-5 | Past planned freezes stay in the list for 30 days and the red X removes one with no confirmation. Removing a past freeze breaks the streak retroactively; the break and save logic only look at misses after the last load, so no save or recovery sheet follows. | `SavesView.swift:189`, `SettingsView.swift:705`, `StreakStore.swift:594-597` |
| P-6 | A `GracePreservation` is keyed by streak, not goal. `threshold` is stored but never read by `applyingGrace`, so a recalibration to a higher goal keeps the old length. | `StreakEngine.swift:538-611`, `StreakSettings.swift:591-600` |
| P-7 | The "Streak ended" push is gated by the Pro-only reminder toggle (`notificationsEnabled`), so free users, the only ones who get break records, never receive it; a lapsed Pro keeps receiving it with the toggle hidden. | `NotificationService.swift:178`, `SettingsView.swift:421-423`, `:116-120` |
| P-8 | After a long absence the break is dated "yesterday" (`missed = yesterday` when current is 0), so a revive or Pro save credits the whole absence as one missed day. | `StreakStore.swift:592-593` |
| P-9 | "PICK A NEW GOAL" opens the tracked-streak picker, which cannot change a committed threshold; only RECALIBRATE on the streak detail can. | `BrokenStreakSheet.swift:62-74`, `DashboardView.swift:136-139` |
| P-10 | `.pending` purchase outcome (paid, no active entitlement yet) lifts the cap in memory only and the paywall shows "PURCHASE PENDING APPROVAL." but is dismissed at once by `onChange(grantsUnlimitedTrackedStreaks)`, so the message is never read. Ask to Buy is reported as `.failed` by RevenueCat, not `.pending`. | `PaywallView.swift:100-102`, `:573-585` |
| P-11 | `StoreKitService.lastError` is never cleared by restore or entitlement refresh, so Restore with nothing to restore can show an earlier error instead of "NO ACTIVE PURCHASES FOUND." | `PaywallView.swift:596-598`, `StoreKitService.swift:431-460` |
| P-12 | A trial offer sheet is marked seen only when it dismisses (`App.swift:368-369`). Killing the app while it is up shows it again next launch. | `App.swift:368-380` |

## Related fixes, in order

1. **Break, save, revive (SM-1, SM-2, SM-4, P-6, P-8).** One change to the data model: key `gracePreservations` by `(key, missedDate)` or keep an append-only saves log next to the bridging record. Gate `canRevive` on `missedDate` and on what `applyingGrace` can bridge (the day after the miss must be met, or revive must write a save for each missed day). Clear `recentlyBroken` for a key when it becomes Pro, and make `handleBreaks` replace, not skip, a stale record.
2. **Reminder queue (SM-3, SM-5, SM-8, P-1, P-7).** One `reconcileReminders()` that reads permission, `notificationsEnabled`, `isPro` and the visible streaks, is serialized (one task chain), and runs on foreground, after `refilter()`, after the toggle and after permission changes. `SettingsView` reads permission on appear and on `scenePhase` active.
3. **Reload requests (SM-7).** Coalesce: remember a pending reload and run it when the current load ends; do not let a stale load commit thresholds the user cleared.
4. **Tracked set and order (SM-6).** Record the user edit (a `lastOnboardingTrackedKeys = []` on pin, or compare the order too) and restore only when both tracked set and order are still the trimmed onboarding values.
5. **Time (SM-9).** Use an autoupdating calendar for day math, or reset on `NSSystemTimeZoneDidChange`, and rebuild the cached `date` of `DailyActivity` rows.

## State machines

Invariant ids are scoped per machine. "Breaks" names the invariant a bad transition violates.

### M1. Entitlement and purchase (`StoreKitService`)

State: `isPro` (persisted `isProEntitled.v1` in the App Group), `purchaseGrantsFullStreakAccess` (memory only), `purchaseInProgress`, `isLoadingProducts`, `offerings`, `introEligibility`, `lastError`, `isConfigured`.
Derived: `grantsUnlimitedTrackedStreaks = isPro || purchaseGrantsFullStreakAccess`; `hasEligibleTrial`, `preferredOfferPackage`.

Invariants:
- E1. `purchaseGrantsFullStreakAccess` is true only between a completed purchase and the first `isPro == true`.
- E2. `isPro` equals "any active RevenueCat entitlement" at the last `customerInfo`.
- E3. Watch and widget read `isProEntitled.v1` and never write it.
- E4. At most one purchase in flight.
- E5. The simulator never configures the production key (`StoreKitService.swift:237-269`).

| From | Event | To | Breaks |
|---|---|---|---|
| free | `purchase` returns entitled | `isPro` true, then flag set true (`:411-423`) | E1 (P-3) |
| free | `purchase` returns not entitled | flag true, `isPro` false (`.pending`) | none, flag lives to relaunch |
| free | `purchase` throws (including Ask to Buy) | `lastError` set, `.failed` | none |
| any | `purchase` while one is running | returns `.cancelled` (`:403`), UI says "Trial wasn't started" | none, message is wrong |
| pro | `receivedUpdated` with no entitlement | `isPro` false, flag untouched | E1 if flag was true |
| any | `refreshEntitlement` throws | `isPro` kept, `lastError` set | none (offline keeps the last value) |
| any | `restore` finds nothing | `isPro` unchanged, `lastError` unchanged | P-11 |
| pro to free, SettingsView mounted | `onChange(isPro)` | `notificationsEnabled` false, `cancelAll` | none |
| pro to free, SettingsView not mounted | none | `notificationsEnabled` stays true | R2 (M6) |

### M2. Trial offer funnel (`RootView`, `StreakSettings` flags)

State: `showTrialOffer`, `showTrialPaywall`, `pendingPaywallAfterTrialDismiss`, `trialPurchaseInFlight`, `trialPurchaseError`, `hasSeenTrialOffer`, `firstTrialOfferShownAt`, `hasReofferedTrial`.

Invariants:
- T1. The offer shows at most once, plus one re-offer 7 or more days later with a streak of 3 or more.
- T2. No offer while `grantsUnlimitedTrackedStreaks`.
- T3. `firstTrialOfferShownAt` is set exactly when `hasSeenTrialOffer` first becomes true.
- T4. Never two sheets at once.

| From | Event | To | Breaks |
|---|---|---|---|
| setup done, products loaded | 4 s timer | `showTrialOffer` true (`App.swift:431-449`) | none |
| offer shown | dismiss by any path | `hasSeenTrialOffer` true (`:369`) | P-12 if killed first |
| offer shown | CTA, `.purchased` or `.pending` | sheet closes, flag set | none |
| offer shown | CTA, `.cancelled` or `.failed` | error text, sheet stays | none |
| seen, 7 days | re-offer | `hasReofferedTrial` true, then show (`:470-471`) | T4 if another sheet is up (ignored by SwiftUI, flag already burned) |
| onboarding trial page | enter | `hasSeenTrialOffer` true (`OnboardingView.swift:871`) | T3 stamps before the page is seen |
| any | `grants` flips true | all flags cleared, restore picks (`:341-350`) | SM-6 |

### M3. Onboarding and setup (`OnboardingView.Phase`, `hasCompletedSetup`)

Phases: intro, intensity, loading, selecting, empty, trial. State: `hasCompletedSetup`, `trackedStreaks`, `manualStreakOrder`, `lastOnboardingPickedCount`, `lastOnboardingTrackedKeys`.

Invariants:
- O1. `lastOnboardingTrackedKeys` is non-empty only while tracking equals the trimmed picks and the user has not subscribed or edited.
- O2. Free users never exceed `freeTrackedLimit` visible streaks (enforced at read time by `visibleStreaks`).
- O3. `SetupGate` resets setup only when Health was never requested and nothing was cached.

| From | Event | To | Breaks |
|---|---|---|---|
| selecting | Start | picks stored, order stored, keys stored (`:791-807`) | none |
| trial | decline | trim to 3, keys kept (`:829-837`) | none |
| free, trimmed | PIN TO TOP | order changes, keys kept | O1 stale, leads to SM-6 |
| free, trimmed | picker SAVE | keys cleared (`StreakPicker.swift:378-379`) | none |
| free, trimmed | untrack | tracked changes, keys kept | none (guard fails safely) |
| free, trimmed | subscribe | tracked and order replaced (`StreakSettings.swift:561-563`) | SM-6 |
| setup done | cold launch, no cache, never asked | `hasCompletedSetup` false (`App.swift:238-241`) | none (other picks kept) |

### M4. Streak life cycle (live, broken, saved, revived)

State per tracked streak: engine value (`current`, `best`, `lastMissedDate`), `committedThresholds[key]`, `lastKnownStreakLengths[key]` and its date, `recentlyBroken` record, `gracePreservations[key]`, `plannedFreezes`.

Invariants:
- S1. At most one `recentlyBroken` record per key.
- S2. A Pro user never has a break record for a new miss (auto-save).
- S3. A revive record bridges only a miss the engine can bridge.
- S4. `lastKnownStreakLengths` reflects the last successful load only.
- S5. The saves count equals the number of saves.
- S6. Hidden or untracked metrics are never judged as broken.

| From | Event | To | Breaks |
|---|---|---|---|
| live | first load after a miss, free | record created, push if enabled (`StreakStore.swift:647-658`) | none |
| live | first load after a miss, Pro | `gracePreservations[key]` replaced (`:634`) | S5 (SM-4) |
| live | break while record exists | skipped (`:631`) | S2 (SM-2) |
| broken | buy on detection day | preservation + load: bridged | none |
| broken | buy on D+1, D unmet | preservation written, engine does not bridge, record deleted (`:674-687`) | S3 (SM-1) |
| broken | CLOSE, KEEP SAME GOAL, PICK A NEW GOAL | record deleted | none |
| broken | 14 days | pruned (`StreakSettings.swift:566-570`) | none |
| any | load while loading | dropped (`:195`) | SM-7 |
| any | recalibrate to a higher goal | old preservation applies to new goal | P-6 |
| live | past freeze removed | streak shortens, no record | P-5 |
| live | load fetch returns all zero | `dataMaybeRevoked`, state untouched (`:240-244`) | none (S6 safe) |

### M5. Load pipeline (`StreakStore`)

State: `isLoading`, `isRefreshing`, `loadStage`, `loadProgress`, `lastUpdated`, `dataMaybeRevoked`, `streaks`, `allCandidates`, `history`.

Invariants:
- L1. One load at a time.
- L2. A failed or suspicious fetch never overwrites good state.
- L3. The snapshot written to the widget equals `streaks`.
- L4. The scheduler runs after every state change that alters the reminder text.

| From | Event | To | Breaks |
|---|---|---|---|
| idle | `refreshIfNeeded`, stale over 60 s | loading | none |
| idle | `NSCalendarDayChanged` while loading | `refreshIfNeeded(force:)` returns (`:184`) | L4 until next trigger |
| loading | user action calls `load()` | returns (`:195`) | SM-7 |
| loading | HealthKit throws | keeps streaks, fills from cache if empty (`:343-368`) | cached `date` may be in an older zone (SM-9) |
| loading | success | streaks, snapshot, last-known, scheduler (`:325-339`) | none |
| any | `refilter()` | streaks, snapshot, no scheduler (`:56-60`) | L4 (SM-5) |

### M6. Reminder queue (`NotificationService`)

State: pending requests `streaks.dailyReminder.0...30` and `streaks.broken.*`, `notificationsEnabled`, hour and minute, iOS authorization.

Invariants:
- R1. Pending requests exist only if enabled, Pro and authorized.
- R2. `notificationsEnabled` equals what the user and iOS allow.
- R3. The queue names a tracked streak and today's reminder only if the goal is open.
- R4. Rebuilds are atomic (no mix of old and new).

| From | Event | To | Breaks |
|---|---|---|---|
| off | toggle on, permission granted | enabled, queue built (`SettingsView.swift:562-565`) | none |
| off | toggle on, previously denied | off, banner (`:569-571`) | banner never clears |
| off | toggle on, prompt denied | off | none |
| on | iOS permission revoked | toggle stays on | R2 (SM-3) |
| on | load ends | queue replaced | R4 (SM-8) |
| on | hour or minute change | queue replaced, twice (hour then minute `onChange`) | R4 (SM-8) |
| on | untrack, picker, restart, pin | queue untouched | R3 (SM-5) |
| on | goal met after last load, app closed | today's push still fires | R3 (P-1) |
| on | Pro lapses, Settings closed | queue lives until next load; flag stays true | R1, R2 |
| on | toggle off during a schedule | `cancelAll`, in-flight adds continue | R1, R4 (SM-8) |

### M7. Tracked set, order and free cap

State: `trackedStreaks` (`nil` means all), `manualStreakOrder`, `hiddenMetrics`, `customStreaks`, `StreakStore.visibleStreaks`.

Invariants:
- K1. Visible = tracked, ordered, capped at 3 unless `grantsUnlimitedTrackedStreaks`.
- K2. Order keys are unique (`Dictionary(uniqueKeysWithValues:)` at `StreakStore.swift:155` traps otherwise).
- K3. Hiding a metric removes its tracked keys, break records and committed thresholds (`SettingsView.swift:620-634`).

| From | Event | To | Breaks |
|---|---|---|---|
| any | picker SAVE | tracked replaced, order untouched | none |
| any | untrack | tracked minus key, order minus key | none |
| any | pin | order front | K2 holds (filtered first, `StreakDetailView.swift:605`) |
| any | cold launch before first load | `allCandidates` is the snapshot subset (max 9, free-capped) | `untrack` with `trackedStreaks == nil` builds from the subset |
| free | cap hit in picker | cap paywall, selection insert on Pro (`StreakPicker.swift:343-346`) | none |
| Pro to free | tracked over 3 | cap applies at read, picker SAVE disabled (`StreakPicker.swift:205`, `:372`) | none |

### M8. Planned freezes

State: `plannedFreezes` (start-of-day dates), `pruneOldFreezes`, effective freezes `isPro ? set : []` (`StreakStore.swift:293`).

Invariants: F1. Frozen days neither break nor extend. F2. Only Pro honours them. F3. A freeze is added for today or later.

| From | Event | To | Breaks |
|---|---|---|---|
| none | add (today or later) | set grows, `load()` | SM-7 if a load is running |
| set | remove a past day | shortens the run | P-5 |
| set | 30 days after | pruned (`StreakSettings.swift:512-515`) | none |
| Pro to free | lapse | freezes ignored, data kept | none, documented (`StreakStore.swift:288-293`) |

### M9. Snapshot, widget, complication (`SnapshotStore`, `asOf`)

State: `streakSnapshot.v1` in the App Group; written by every `persistCurrentSnapshot`; watch receives it over WatchConnectivity.

Invariants: W1. Widgets never query HealthKit. W2. A snapshot from an earlier day never reads as done today. W3. Free users' snapshot carries at most the free cap.

| From | Event | To | Breaks |
|---|---|---|---|
| fresh | new day, no app run | `asOf` resets today's progress (`StreakSettings.swift:222-227`) | none |
| fresh | 2 or more days, no refresh | still shows `current` | P-4 |
| any | Pro lapse | snapshot rewritten at next load only | W3 until then |

### M10. Review prompt (`ReviewPromptTracker`)

State: launch count, last shown, outcome, pending moment. Invariants: V1. Not on the first session. V2. 30 day cooldown. V3. Never over another sheet. No bad transition found; `isDashboardClear` covers the trial sheets (`DashboardView.swift:270-278`), `markShown` is called before `requestReview()` (the system may not show it, by design).

### M11. Time

State: `DateHelpers.gregorian` (zone fixed at first use), `Calendar.current` (follows), `NSCalendarDayChanged`, `scenePhase`, BGAppRefresh (earliest 30 minutes, not guaranteed).

| From | Event | To | Breaks |
|---|---|---|---|
| any | midnight, app foreground | forced refresh | dropped if loading (L4) |
| any | midnight, app suspended | nothing until foreground or BG task | P-4 |
| any | device zone changes, process alive | engine keeps old zone | SM-9 |
| any | DST day | `byAdding: .day` keeps wall clock | none found |
