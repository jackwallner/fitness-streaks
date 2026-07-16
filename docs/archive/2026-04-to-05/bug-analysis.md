# Fitness Streaks Bug Analysis

Date: 2026-04-26
Repository: `jackwallner/fitness-streaks`
Reviewed commit: `609fad3` (`fix: contextual permission prompts and notification toggle UX`)
Branch status: local `main` aligned with `origin/main` after `git fetch --prune origin`

## Verification Performed

- Fetched latest GitHub refs from `origin`.
- Confirmed local `main` has no ahead/behind commits versus `origin/main`.
- Confirmed working tree was clean before writing this report.
- Reviewed the main SwiftUI app, watch app, widget extensions, shared HealthKit/cache/settings/streak engine code, project configuration, Info.plists, and entitlements.
- Ran builds:
  - `xcodebuild -project FitnessStreaks.xcodeproj -scheme FitnessStreaks -destination 'generic/platform=iOS' build` - succeeded.
  - `xcodebuild -project FitnessStreaks.xcodeproj -scheme FitnessStreaksWatch -destination 'generic/platform=watchOS' build` - succeeded.

## Executive Summary

The project currently compiles for both iOS and watchOS, and the local repository is up to date with GitHub. The most important bugs are runtime/data correctness issues rather than compiler failures.

Highest-impact issues:

1. Stand-hour streaks are likely calculated from the wrong HealthKit data type, so stand streaks may never surface correctly.
2. Widget snapshots are not recomputed after onboarding/settings tracking changes, so widgets can show stale or unselected streaks.
3. Notification scheduling does not actually enforce “only notify if at risk” and uses “days” even for weekly streaks.
4. Settings changes for hidden metrics do not refresh the dashboard, so disabled metrics can remain visible.
5. Streak discovery does duplicate expensive HealthKit work during refresh.

## Findings

### 1. Stand-hour streaks use stand minutes divided by 60 instead of actual stand-hour events

Severity: High
Area: HealthKit data correctness
Files:

- `Shared/Services/HealthKitService.swift`
- `Shared/Models/StreakMetric.swift`

Evidence:

- `quantityTypes` includes `.appleStandTime`.
- `fetchHistory` fetches `.appleStandTime` in minutes.
- The app then derives `standHoursValue = (sh[key] ?? 0) / 60.0`.
- `StreakMetric.standHours` thresholds are `[6, 8, 10, 12]`, which read like Apple Watch stand-hour counts.

Impact:

`appleStandTime` is a duration quantity, not the same as Apple Watch “stand hours” count. Dividing stand minutes by 60 can produce values far below the intended 6/8/10/12 hour thresholds, causing stand streaks to be missing or inaccurate.

Recommended fix:

Use the Apple stand-hour category samples (`HKCategoryTypeIdentifier.appleStandHour`) and count samples whose value indicates the user stood for that hour. Keep `standHours` as a count of stood hours per day.

---

### 2. Widget snapshots are stale after onboarding tracked-streak selection

Severity: High
Area: Widget correctness / onboarding
Files:

- `FitnessStreaks/Views/OnboardingView.swift`
- `Shared/Services/StreakStore.swift`
- `Shared/Services/HealthKitService.swift`
- `Shared/Services/StreakSettings.swift`

Evidence:

In onboarding:

- The minimum step clears `settings.trackedStreaks = nil`.
- `await store.load()` runs while the tracked filter is cleared.
- `HealthKitService.refreshCache` saves the widget snapshot during that load.
- The review step later sets `settings.trackedStreaks = selectedStreaks` and calls `store.refilter()`.
- No new `SnapshotStore.save(...)` occurs after the final selection.

Impact:

A first-time user can finish onboarding with widgets still showing all/unfiltered top streaks rather than the streaks they explicitly selected.

Recommended fix:

After `settings.trackedStreaks` changes and `store.refilter()` runs, recompute and save the snapshot from the filtered `store.streaks`.

---

### 3. Widget snapshots are stale after changing tracked streaks in Settings

Severity: High
Area: Widget correctness / settings
Files:

- `FitnessStreaks/Views/Components/StreakPicker.swift`
- `Shared/Services/StreakSettings.swift`

Evidence:

`StreakPickerSheet.save()` only does:

- `settings.trackedStreaks = selection`
- `store.refilter()`
- `dismiss()`

`StreakSettings.trackedStreaks.didSet` calls `WidgetCenter.shared.reloadAllTimelines()`, but it does not update the `SnapshotStore` payload that widgets read.

Impact:

Widgets reload but still read the previous serialized snapshot. The dashboard updates, but widgets can remain out of sync until a later HealthKit refresh.

Recommended fix:

Centralize tracked-streak updates in `StreakStore` or add a method such as `store.persistCurrentSnapshot()` and call it after every `refilter()`.

---

### 4. Hidden metric toggles do not refresh the dashboard or widget snapshot

Severity: Medium-High
Area: Settings behavior
File: `FitnessStreaks/Views/SettingsView.swift`

Evidence:

The metric toggles update `settings.hiddenMetrics`, but no `store.load()` or `store.refilter()` is triggered in `metricsSection`.

Impact:

If a user disables a metric that is currently the hero or a visible badge, it can remain visible on the dashboard until the user manually refreshes or another load happens. Widgets can also remain stale because only timeline reload is requested, not snapshot recomputation.

Recommended fix:

When `hiddenMetrics` changes, reload/discover streaks and save a new snapshot. At minimum, attach an `onChange` handler or call `Task { await store.load() }` from the toggle setter.

---

### 5. Notification scheduling does not honor the “at-risk only” behavior

Severity: Medium-High
Area: Notifications
Files:

- `Shared/Services/NotificationService.swift`
- `Shared/Services/StreakStore.swift`
- `FitnessStreaks/Views/SettingsView.swift`

Evidence:

`NotificationService.scheduleDailyReminder(heroLabel:currentLength:)` receives only label and current length. It does not receive `currentUnitCompleted` or cadence. It schedules a repeating 7pm notification whenever notifications are enabled, permission exists, label exists, and `currentLength >= 3`.

Impact:

The app can schedule reminders even when the current day/week is already locked in. This contradicts the documented behavior: “Daily 7pm nudge if your hero streak isn't locked in yet.”

Recommended fix:

Pass the full `Streak` or at least `currentUnitCompleted` and `cadence` into the notification scheduler. Do not schedule when `currentUnitCompleted == true`.

---

### 6. Notification copy says “days” for weekly streaks

Severity: Medium
Area: Notifications / UX correctness
File: `Shared/Services/NotificationService.swift`

Evidence:

The notification body is always:

`You're at \(currentLength) days. Get it in before midnight.`

Impact:

For weekly hero streaks, notifications display incorrect units and an incorrect deadline. Example: a weekly workout streak could say “You're at 5 days” instead of “5 weeks,” and “before midnight” may not match the weekly cadence.

Recommended fix:

Include cadence in the scheduler and format the body as days/weeks with an appropriate deadline phrase.

---

### 7. `StreakStore.load()` performs duplicate HealthKit fetches

Severity: Medium
Area: Performance / battery
Files:

- `Shared/Services/StreakStore.swift`
- `Shared/Services/HealthKitService.swift`

Evidence:

`StreakStore.load()` does:

1. `fetchHistory(days: 400)`
2. `refreshCache(days: 400)`
3. `fetchHourlySteps(days: 90)`

`refreshCache(days:)` internally calls `fetchHistory(days:)` again and also fetches hourly steps.

Impact:

A foreground refresh can duplicate expensive 400-day HealthKit queries and hourly step queries. This can make refresh slower, increase battery use, and increase the chance of failure/timeouts in background refresh.

Recommended fix:

Refactor so `StreakStore.load()` fetches once, upserts that fetched history, computes streaks once, and saves the snapshot once.

---

### 8. Snapshot save can happen before the final in-memory streak ordering/filtering

Severity: Medium
Area: Data flow / widgets
Files:

- `Shared/Services/StreakStore.swift`
- `Shared/Services/HealthKitService.swift`

Evidence:

`StreakStore.load()` calls `HealthKitService.refreshCache()` before calculating its own `allCandidates` and `streaks`. `refreshCache()` independently computes and saves the snapshot.

Impact:

There are two independent discovery passes. If settings or filters change between calls, if hourly fetch succeeds in one call but fails in the other, or if logic diverges later, widgets can disagree with the dashboard.

Recommended fix:

Make `StreakStore` the owner of discovery and snapshot persistence. `HealthKitService` should fetch/cache raw data, while `StreakStore` computes UI state and snapshots from the same result.

---

### 9. Appearance setting is currently unused / forced dark

Severity: Medium
Area: Settings / UX
Files:

- `FitnessStreaks/App.swift`
- `FitnessStreaks/Views/SettingsView.swift`
- `Shared/Services/StreakSettings.swift`

Evidence:

- `AppAppearance` and `appearanceSection` exist.
- `SettingsView.body` does not include `appearanceSection`.
- `FitnessStreaksApp` applies `.preferredColorScheme(.dark)` unconditionally.

Impact:

Any appearance preference is ignored, and the app is always dark. If this is intentional, the dead setting code creates maintenance confusion. If not intentional, users cannot actually use the appearance setting.

Recommended fix:

Either remove the unused appearance setting/section or include `appearanceSection` and bind `.preferredColorScheme(settings.appearance.colorScheme)`.

---

### 10. Hour-window streak ranking ignores hourly threshold tier

Severity: Medium
Area: Streak ranking / discovery
File: `Shared/Services/StreakEngine.swift`

Evidence:

Hour-window streaks use thresholds `[250, 500, 1000, 1500, 2000, 3000]`, but `vibeScore(_:,vibe:)` derives tier index from `s.metric.dailyThresholds` for daily step streaks. Most hourly thresholds are not in the daily step thresholds list, so `tierIdx` falls back to `0`.

Impact:

A 3,000-step-per-hour rhythm is scored like a lowest-tier streak. This can under-rank more impressive hour-window streaks or produce unexpected ordering.

Recommended fix:

If `s.window != nil`, score against `hourlyStepThresholds` rather than `metric.dailyThresholds`.

---

### 11. Hour-window de-duplication misses midnight adjacency

Severity: Low-Medium
Area: Streak ranking / UX
File: `Shared/Services/StreakEngine.swift`

Evidence:

Adjacent hour windows are filtered with:

`abs($0.0 - candidate.0) <= 1`

This handles `4` and `5`, but not `23` and `0`, even though 11pm-midnight and midnight-1am are adjacent.

Impact:

The UI can show two adjacent overnight windows that are likely the same activity pattern.

Recommended fix:

Use circular hour distance: `min(abs(a - b), 24 - abs(a - b))`.

---

### 12. Dashboard risk labels do not distinguish hour-window deadlines

Severity: Low-Medium
Area: UX correctness
Files:

- `FitnessStreaks/Views/DashboardView.swift`
- `FitnessStreaks/Views/Components/StreakHero.swift`

Evidence:

- `DashboardView.riskText(for:)` says remaining amount “to lock today in” for daily streaks.
- `StreakHero` always labels progress as `TODAY'S CHARGE`.
- Hour-window streaks are daily streaks with a specific one-hour window, but the copy does not mention the specific window.

Impact:

For a time-of-day streak, users may not understand that the target applies to a specific hour, not the entire day.

Recommended fix:

If `streak.window != nil`, include the window in the risk/progress copy.

---

### 13. Sleep totals can be inflated by overlapping HealthKit samples

Severity: Low-Medium
Area: HealthKit data correctness
File: `Shared/Services/HealthKitService.swift`

Evidence:

`sleepHoursByDay` sums all samples whose values are asleep states. It does not merge intervals or de-duplicate overlaps across sources/devices.

Impact:

If HealthKit contains overlapping sleep-stage samples or multiple-source samples, daily sleep hours can be over-counted. This can inflate sleep streaks.

Recommended fix:

Normalize sleep intervals by merging overlapping asleep intervals per day before summing, or filter/prefer sources carefully.

---

### 14. Watch onboarding marks setup complete even when authorization fails

Severity: Low-Medium
Area: watchOS onboarding
File: `FitnessStreaksWatch/App.swift`

Evidence:

The watch onboarding button does:

- `try? await healthKit.requestAuthorization()`
- `settings.hasCompletedSetup = true`
- `await store.load()`

The authorization error is ignored.

Impact:

If HealthKit authorization fails, setup can still be marked complete. Depending on `isAuthorized`, the user may get stuck in a confusing state or repeatedly see empty/no-data behavior.

Recommended fix:

Handle errors explicitly and only mark setup complete after successful authorization or a deliberate “continue without access” decision.

---

### 15. `requestAuthorization()` sets `isAuthorized = true` after the prompt returns, regardless of actual read access

Severity: Low-Medium
Area: HealthKit authorization state
File: `Shared/Services/HealthKitService.swift`

Evidence:

`HealthKitService.requestAuthorization()` sets `isAuthorized = true` after `store.requestAuthorization(...)` returns.

Impact:

HealthKit does not reveal per-type read permission status in the same way as write permissions. If the user denies access, the app can still proceed as if authorized and only later show empty/no-data states. Some comments indicate this may be partially intentional, but the property name `isAuthorized` then becomes misleading.

Recommended fix:

Rename the state to something like `hasRequestedAuthorization` or add a separate “can proceed” state. Use UI copy that distinguishes “prompt completed” from “data available.”

## Build/Test Gaps

- There are no meaningful automated tests in `FitnessStreaksTests`.
- The highest-risk code (`StreakEngine`, HealthKit aggregation, snapshot filtering) is mostly pure or mockable and would benefit from unit tests.
- Recommended first tests:
  - Daily streak continues through an incomplete current day.
  - Weekly streak continues through an incomplete current week.
  - Tracked-streak filtering updates snapshot contents.
  - Hidden metrics are excluded after settings changes.
  - Hour-window ranking uses hourly thresholds.
  - Sleep interval merging avoids double-counting overlaps.

## Suggested Fix Priority

1. Correct stand-hour HealthKit aggregation.
2. Centralize snapshot persistence after every `store.streaks` change.
3. Fix notification scheduling and copy using full `Streak` context.
4. Refresh/recompute after hidden metric changes.
5. Remove duplicate HealthKit fetches in `StreakStore.load()`.
6. Add unit tests for `StreakEngine` and snapshot filtering.
7. Clean up appearance settings and hour-window UX/ranking issues.

## Notes

This report is based on static review plus successful local builds. Runtime HealthKit behavior should still be validated on device because HealthKit permissions, Apple Watch data availability, background refresh, and WidgetKit timeline behavior can differ from generic builds.
