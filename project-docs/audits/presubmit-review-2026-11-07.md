# Pre-submit review: Streak Finder 1.3.3 (2026-11-07)

Scope: app sources changed from the live App Store version to `origin/main` at `b6f0fd67`.
App Store Connect shows 1.3.2 build 164 as READY_FOR_SALE and 1.3.3 build 166 as
PREPARE_FOR_SUBMISSION. Build 164 was bumped at `cefbaa1d`, so the diff is
`cefbaa1d..b6f0fd67`, without docs, fastlane, qa, tests or android. That leaves 12 files:
the Language row in Settings (`UIPrefersShowingLanguageSettings`), separate paywall
errors (`productLoadError`), the save log, breaks recorded per miss and next-day revive,
loads requested during a load queued after it, the reminder queue generation guard, the
Settings permission re-read, and the time-zone-following calendar. It also adds 94
catalog lines, and `Tools/Localization/check.py` reports 756 keys, 6 languages, 0 problems.

Checked and clean: no force unwraps, subscripts or `uniqueKeysWithValues` in the
changed code reachable in Release (the seeded `uniqueKeysWithValues` is DEBUG only).
The `saveLog` decode falls back to `gracePreservations` when the key is absent or
unreadable, so old saved data does not throw. Every `gracePreservations` writer outside
DEBUG goes through `recordSave`, so the log and the engine map stay in step. Purchase
and restore clear only `lastError`, and the paywall retry block reads
`productLoadError`, so an earlier purchase error no longer hides prices or a failed
load. The paywall still shows the Terms (Apple EULA) and Privacy links. The diff adds no
hard-coded prices, other-platform links, health claims or debug UI. The reminder
queue guard and `NotificationService` are `@MainActor`. `OSAllocatedUnfairLock` is
fine on the iOS 17 and watchOS 10 targets.

No P0 or P1 findings. Nothing was changed in code.

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P2 | Shared/Services/StreakStore.swift:281 | A `refilter()` during a load skips its own threshold commit and leaves it to `commitThresholdsAfterLoad()`. When that load ends on the data-loss guard (line 281) or in the `catch`, the commit never runs. A streak picked during that load keeps an uncommitted goal until the next successful load commits the engine's goal. | Not fixed: by design. Committing after a failed load could write back goals from before a Recalibrate All, which is the bug the change prevents. The next load commits anyway. |
| P2 | FitnessStreaks/Views/OnboardingView.swift:760 | `startDiscovery()` awaits `store.load()` and reads `allCandidates`. If another load is already running (launch task, or a scene-active refresh), `load()` now queues a reload and returns at once, so onboarding can read the earlier, possibly empty candidates and show the empty phase. The same early return existed in 1.3.2 (`if isLoading { return }`). | Not fixed: not a regression, and it needs a launch load still in flight when Health access is granted. Fixing it means callers awaiting the queued load, a behaviour change for every caller. |
| P2 | Shared/Services/HealthKitService.swift:177 | `DateHelpers.gregorian` now follows a time-zone change while the app runs. A change during the concurrent per-type fetches could key some types to the old zone's midnights and others to the new zone's, so one load reads a day as zero. | Not fixed: needs a zone change inside a fetch of about a second, and the next load corrects it. Not provable without a device. |
| P2 | FitnessStreaks/Views/PaywallView.swift:234 | When offerings load without an error but the current offering has no packages, the product block is empty, with no prices and no retry. The behaviour is the same as 1.3.2. | Not fixed: needs a RevenueCat misconfiguration. Not a code regression. |

Tests: not run. `gh-sim test --scheme FitnessStreaks` (GitHub Actions run 42455338955, id
`fitness-streaks@20261107-222815-7517-claude-mbpro3d928-1107-223453-4360`) sat queued from
06:34Z to 08:05Z on 2026-11-08 with 0 of 5 GitHub Macs running and 25 runs queued fleet-wide,
so it was cancelled after the 90 minute limit. No code changed in this review, so the last
recorded pass stands: 158 tests in `state-machines-2026-11-06-verify.md`, on code that
matches `origin/main` app sources.

## Second pass, deep (2026-11-08)

Base: `origin/main` at `5e7cb23` merged into this branch (8 commits since the first
pass: the paywall purchase block pinned below a scrolling plan list, the free custom
streak copy changed to three, and the light launch background). Live is still 1.3.2
build 164 (`cefbaa1`). This pass read every path a user can reach in 1.3.3, not just
the diff: purchase, restore, trial offers, onboarding, the load queue and break or
save handling, settings persistence, reminders, the widget snapshot, the Watch,
SwiftData, iPhone Duo routing and localization.

Checked and clean:
- Purchase and restore clear `lastError` first. Every paywall has CLOSE, plus Terms,
  Privacy and Restore, which are now pinned and stay on screen. An entitled user who
  opens a paywall is dismissed straight away.
- isPro gating uses `grantsUnlimitedTrackedStreaks`, so access starts while an
  entitlement is still pending. A lapse turns reminders off: every schedule cancels
  first and checks `remindersWanted`.
- Onboarding cannot repeat for a set-up user who has cached days, and every trial
  page exit runs `completeSetup`.
- The order kept by `restoreOnboardingTrackedStreaksIfNeeded` cannot duplicate keys,
  so `applyManualOrder`'s `uniqueKeysWithValues` is safe.
- Duo tour and screenshot hooks, the RevenueCat probe and the `-UITest` flags are all
  DEBUG only.
- No hard-coded prices, links to other platforms or health claims.
- `Tools/Localization/check.py` reports 756 keys, 6 languages, 0 problems.

| Severity | File:line | What happens | Status |
|---|---|---|---|
| P1 | FitnessStreaks/Views/OnboardingView.swift:241 | RESTORE on the onboarding trial page discarded the outcome. A tap that found no purchase, or failed offline, left the page unchanged with no message. (A restore that works closes onboarding through the entitlement change.) | Fixed: the page's error line shows the store error or "NO ACTIVE PURCHASES FOUND." (`RestoreFeedback`, test `testRestoreFeedbackSaysWhyWhenNothingWasRestored`). |
| P2 | FitnessStreaks/Views/OnboardingView.swift:764 | Same as the first pass's onboarding row. It also covers the dashboard's Health access button: a load already running makes `load()` queue and return, so the caller reads the earlier candidates. A brand-new user's launch load throws before Health access, so `lastUpdated` stays nil and any scene-active refresh is stale enough to run. | Not fixed: needs a scene-active refresh to start just before discovery, and HealthKit's sheet is not shown to change the scene phase. Making queued callers wait changes every caller. |
| P2 | Shared/Services/StreakSettings.swift:218 | `StreakSnapshot.recentlyBroken` has a default but uses synthesized `Decodable`, so a snapshot written before 2026-04-27 (no key) fails to decode. The widget shows its sync prompt until the next load rewrites the snapshot. | Not fixed: only builds from April wrote such snapshots, and it fixes itself on the first load. |
| P2 | Shared/Models/DailyActivity.swift:18 | `earlySteps` and `heartRateMinutes` are non-optional with no default. A store from a build before 2026-04-27 could fail lightweight migration. `DataService` then falls back to an in-memory cache, which is not a crash. | Not fixed: no evidence that any user still has a store that old. |
| P2 | Shared/Services/StreakStore.swift:171 | `Dictionary(uniqueKeysWithValues:)` on cached days (also `StreakEngine.swift:48`) traps if two cached rows share a `date`. That needs two time-zone hops that differ by 24 hours, because `upsert` never rewrites `date`. | Not fixed: the trigger is extreme (crossing the date line twice) and the code is unchanged since 1.3.2. |
| P2 | Shared/Services/StoreKitService.swift:142 | Trial chips and the hero line always say "days". A month or year trial would read "1 DAYS FREE". | Not fixed: every live trial is 7 days. |
| P2 | FitnessStreaks/Views/BrokenStreakSheet.swift:212 | After a purchase from the full paywall that is still pending, the revive is skipped because the code checks `isPro` instead of `grantsUnlimitedTrackedStreaks`. The broken card stays, and the next Streaks+ load does not save it. | Not fixed: needs RevenueCat to lag after a completed StoreKit purchase. The in-sheet trial path revives on pending. |
| P2 | FitnessStreaksWatch/App.swift:36 | The Watch saves any snapshot it receives without checking age, so a late queued `transferUserInfo` could overwrite a newer one. | Not fixed: WatchConnectivity delivers in order, and the next phone refresh corrects it. |
| P2 | (app-wide) | No in-app health disclaimer. The app makes no treat, cure or diagnose claims, and it shipped without one. | Not fixed: adding one is new copy. |

Tests: see the commit that records the gh-sim result below.
