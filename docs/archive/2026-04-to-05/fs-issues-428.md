# FitnessStreaks Issues Analysis — April 2026

**Scope:** Full codebase review covering StreakEngine, HealthKit, persistence, notifications, UI, tests, and architecture.
**Audience:** Engineering (bug-fix and refactor roadmap).

---

## 1. StreakEngine — Logic & Performance

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 1.1 | **Medium** | Hour-window discovery is **dead code**: `discoverHourWindows()` still exists, `hourlySteps` is threaded through `discover(...)` and `bestHourlyThresholdForSteps(...)` exists, but the call site in `discover(...)` is gated by `/* Hour-window streaks removed — daily streaks only per user request */`. This creates build warnings, dead branches, and unused cache memory. | `StreakEngine.swift:72` | Low |
| 1.2 | **High** | `computeDailyStreak(...)` and `computeDailyStreakFromValues(...)` are **near-identical** (≈150 lines). They share the same pass/fail walk, best-streak logic, and window check. Only difference is `Date`-based lookup vs direct `Double` array access. Deduplicate into a single private helper that takes a `Bool`-closure `isCompleted(dayIndex)`. | `StreakEngine.swift:355–502` | Medium |
| 1.3 | **Medium** | `applyingGrace(...)` has a suspicious boundary: `canBridge = streak.current >= max(0, daysAfterMiss - 1)`. When `daysAfterMiss == 0` (same calendar day), `canBridge` is always `true`, so any streak with `current ≥ 0` claims it can bridge. Grace should only activate for **yesterday** (daysAfterMiss == 1). | `StreakEngine.swift:510` | Low |
| 1.4 | **Low** | `vibeScore(...)` hard-codes magic constants (`1.4`, `0.8`, `0.2`, `0.1`) without named constants or unit tests. Tuning is invisible and fragile. | `StreakEngine.swift:625` | Low |
| 1.5 | **Medium** | `discoverBestThreshold` recalculates `completionRate` via `Double(days.count)` but never checks for `days.isEmpty`. While callers pass non-empty arrays, a guard is safer. | `StreakEngine.swift:319` | Trivial |

---

## 2. StreakStore — Orchestration & Data Flow

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 2.1 | **High** | `load()` **runs the full discovery engine twice** in the non-error path: first at `StreakEngine.discover(...)` (line 99) to feed `handleBreaks`, then again at `discover(...)` (line 112) to produce `all`. The first result is immediately discarded. For 400 days × 10 metrics this is a significant CPU waste on the main thread. | `StreakStore.swift:95–116` | Medium |
| 2.2 | **Medium** | `handleBreaks(all:previous:)` receives `all` but **only ever reads keys from `fresh`** (the filtered parameter). The `all` parameter is unused. Signature is misleading and can be simplified. | `StreakStore.swift:159` | Low |
| 2.3 | **Medium** | Error fallback path re-runs `discover` **without** `hourlySteps`, so custom hour-window streaks silently downgrade to daily on any `StreakEngineError`. | `StreakStore.swift:134` | Medium |
| 2.4 | **Low** | `load()` calls `settings.pruneBroken()` at the top, which removes broken-streak records older than 48 h. A user who opens the app after a weekend will **never see the broken banner** for a streak that broke on Friday. This makes the "Broken Streak" sheet nearly invisible for casual users. | `StreakStore.swift:94` | Low |
| 2.5 | **Low** | `refilter()` reads the snapshot from disk (`SnapshotStore.load`) even though `load()` just persisted it. This extra I/O is unnecessary when `refilter()` is called immediately after `load()` in onboarding / settings. | `StreakStore.swift:183` | Low |

---

## 3. HealthKit Integration

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 3.1 | **Medium** | `fetchHistory(days:metrics:)` always fetches **all 10 metrics** regardless of which are hidden or tracked. For a user tracking only 2 streaks, 80 % of the queries are wasted. The method should accept a `Set<HKQuantityType>` derived from tracked + candidate metrics. | `HealthKitService.swift:138` | Medium |
| 3.2 | **Low** | `heartRateMinutesAbove(...)` adds an arbitrary `+5` seconds for the first sample in each burst. The intent (minimum burst duration) is not documented and produces slightly inflated minute counts. | `HealthKitService.swift:423` | Low |
| 3.3 | **Low** | `standHourCounts(...)` uses `HKCategoryValueAppleStandHour.stood`. If stand reminders are disabled, samples may simply not exist for that hour (rather than being `.idle`). The code interprets absence as 0, which is correct, but should be explicitly verified against `.idle` if Apple ever changes default behaviour. | `HealthKitService.swift:279` | Low |
| 3.4 | **Low** | `refreshCache()` is **public but appears unused**. `StreakStore.load()` fetches history and upserts directly via `DataService`; it never calls `refreshCache()`. Dead code or leftover API surface. | `HealthKitService.swift:435` | Low |

---

## 4. Data Persistence & SwiftData

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 4.1 | **High** | `DataService.init()` silently **destroys the entire store** (`container = nil`) if `loadPersistentStores` throws. All 400 days of cached HealthKit history are lost with no user-facing warning. A lightweight migration strategy (or schema versioning with `modelContainer` options) should be added before any future model changes. | `DataService.swift:46` | High |
| 4.2 | **Medium** | `DailyActivity` uses `@Model` but has **no unique identifier / constraint**. Two insertions for the same day will create duplicate rows. The `cache` path calls `upsertDay` (delete-then-insert), but background widget timeline reloads or concurrent processes could race. | `DailyActivity.swift` | Medium |
| 4.3 | **Low** | `SnapshotStore` writes to `UserDefaults` on every `load()` cycle. For widget / watch refresh this is acceptable, but it does not use an app-group suite (`group.com.jackwallner.streaks`) for the `UserDefaults` instance. The widget reads from `UserDefaults.standard`, which may not share data with the watch or app if the suite is not configured correctly in the entitlements. | `SnapshotStore.swift` | Low |

---

## 5. Notifications

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 5.1 | **Medium** | `scheduleDailyReminder(...)` only schedules for the **hero streak**. If the hero is completed but a secondary (badge) streak is at risk, the user receives **no reminder**. It should iterate over all tracked streaks and schedule the one with the highest risk / lowest progress. | `NotificationService.swift:42` | Medium |
| 5.2 | **Low** | `notifyStreakBroken(...)` uses `UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)`. If the streak breaks while the user is actively in the app (e.g., at midnight), the notification fires **1 second later** inside a session. Consider suppressing or deferring when `UIApplication.shared.applicationState == .active`. | `NotificationService.swift:92` | Low |

---

## 6. UI / UX

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 6.1 | **Medium** | **Feature panel lie**: `OnboardingView` states `"DAILY STREAKS ONLY"`, but the codebase supports weekly cadence and hour windows. This is misleading if weekly streaks are ever re-enabled, or confusing if the code still contains the weekly logic. | `OnboardingView.swift:380` | Low |
| 6.2 | **Medium** | `StreakPickerSheet.onAppear(...)` **auto-selects the top 5 candidates** every time it opens. If the user intentionally de-selected a streak, returning to the sheet re-checks it without warning. | `StreakPicker.swift:210` | Low |
| 6.3 | **Medium** | Onboarding `.minimum` step sets `settings.trackedStreaks = nil` before calling `store.load()`. If the user re-enters onboarding after initial setup, their existing selections are **wiped** before they can review them. | `OnboardingView.swift:416` | Low |
| 6.4 | **Low** | `StreakDetailView.suggestedThreshold(...)` **re-runs the entire discovery engine** (`StreakEngine.discover(...)`) just to compute a single threshold value for the "Recalibrate" button. On a detail view this is expensive and blocks the main thread. Cache or compute incrementally. | `StreakDetailView.swift:244` | Medium |
| 6.5 | **Low** | `weekdayHistogram(...)` computes `median` as `vals.sorted()[vals.count / 2]`. If `vals.isEmpty` this **crashes** with a hard subscript error. Empty histograms can happen for new streaks with <1 week of data. | `StreakDetailView.swift:356` | Trivial |
| 6.6 | **Low** | `BrokenStreakSheet` "Restart Same Goal" does **not** reset the streak counter to 0. It only adds the key back to tracked streaks. Because the engine re-evaluates history, if the user missed yesterday the streak will still appear broken. The user expects a clean reset. | `DashboardView.swift:283` | Medium |
| 6.7 | **Low** | `DashboardView.relative(...)` instantiates a new `RelativeDateTimeFormatter` on every call. Should be a static/shared formatter. | `DashboardView.swift:274` | Trivial |
| 6.8 | **Low** | `WatchTodayView` has **no error state**. If HealthKit authorization is denied or `StreakStore.load()` throws, the view stays in `.loading` forever. | `WatchTodayView.swift` | Low |

---

## 7. Widgets & Complications

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 7.1 | **Medium** | iOS widget reads from `SnapshotStore` (`UserDefaults`). There is **no background refresh strategy** (e.g., `WidgetCenter.shared.reloadTimelines` after a HealthKit sample arrives). The widget can display stale hero-streak data for hours. | `FitnessStreaksWidget.swift` | Medium |
| 7.2 | **Low** | `FitnessStreaksWidgets` is a `WidgetBundle` containing only **one widget**. The wrapper is unnecessary overhead. If a medium/large variant is planned, keep it; otherwise collapse to a single `Widget`. | `FitnessStreaksWidget.swift:275` | Low |
| 7.3 | **Low** | Watch complication uses a **fixed 1-hour timeline** (`reloadPolicy: .after(nextHour)`). If the user completes their goal at 10:05, the complication still shows "0/10k" until 11:00. Consider triggering a manual reload via `WidgetKit` when the app records new data. | `WatchComplication.swift:65` | Medium |

---

## 8. StreakSettings & Thresholds

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 8.1 | **High** | `commitThresholds(...)` only stores a threshold if `next[key] == nil`. This means **thresholds are write-once and never update**. If a user's fitness improves, their locked "Easy" goal stays at the old low threshold forever. A periodic recalibration (e.g., every 90 days) or a manual "Recalibrate" flow should be supported. | `StreakSettings.swift:289` | Medium |
| 8.2 | **Medium** | `intensityRatio` metric divides `activeEnergy / exerciseMinutes`. If `exerciseMinutes == 0`, the ratio is 0. This is mathematically safe (returns 0), but a resting day (0 exercise minutes) will **break any intensity streak** even if the user otherwise met their active-energy goal. This may be intentional, but it is a sharp edge case. | `StreakMetric.swift:146` | Low |

---

## 9. Architecture & Code Hygiene

| # | Severity | Issue | Location | Fix Complexity |
|---|----------|-------|----------|---------------|
| 9.1 | **Medium** | **No unit tests for `StreakStore`**, `HealthKitService`, `NotificationService`, or widget timeline providers. The only test target (`StreakEngineTests`) covers 7 engine cases. Adding tests for `handleBreaks`, snapshot I/O, and notification scheduling would prevent regressions. | `FitnessStreaksTests/` | Medium |
| 9.2 | **Low** | `Theme.swift` defines `accentDistance`, `accentFlights`, etc. as `#if os(iOS)` adaptive colors, but watchOS gets fixed dark values. WatchOS can render in light contexts (e.g., infographic faces), causing poor contrast. | `Theme.swift` | Low |
| 9.3 | **Low** | `StreakStore`, `HealthKitService`, `NotificationService`, and `DataService` are all **singletons** (`shared`). This makes unit testing difficult (no injection) and hides dependencies. Consider protocol-based abstractions or `@Observable` environment objects. | Various | High |
| 9.4 | **Low** | `DateHelpers.gregorian` hard-codes `firstWeekday = 2` (Monday). This is documented in code, but if the user's locale starts weeks on Sunday, weekly streak calculations will feel offset. | `DateHelpers.swift:6` | Low |

---

## 10. Recommended Priority Order

1. **StreakStore double-engine run (2.1)** — immediate CPU / battery win.
2. **StreakEngine deduplication (1.2)** — reduces maintenance surface.
3. **SwiftData nuke-on-error (4.1)** — data-loss risk.
4. **Threshold lock-in (8.1)** — core product behaviour; users will outgrow stale goals.
5. **Notification hero-only (5.1)** — missing reminders for secondary streaks.
6. **Widget stale data (7.1)** — external-facing quality issue.
7. **StreakPickerSheet re-selection (6.2)** — annoying UX bug.
8. **BrokenStreakSheet restart (6.6)** — mismatch between button promise and actual behaviour.
9. **Test coverage expansion (9.1)** — enables confident refactors of the above.
10. **Dead code removal (1.1, 3.4)** — clean build & smaller binary.

---

*Generated by codebase analysis — April 2026.*
