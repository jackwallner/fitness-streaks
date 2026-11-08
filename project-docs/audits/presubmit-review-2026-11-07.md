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
