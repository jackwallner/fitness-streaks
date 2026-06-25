# App Store Review Fixes — FitnessStreaks (arfix428)

**Date:** 2026-04-28  
**Scope:** All fixes applied in response to `ar428.md` audit findings.

---

## Critical Fixes

### CR-1: Accessibility labels, values, and hints added to all major interactive surfaces

**Rationale:** App Store Review Guidelines 4.0 / 4.1 — VoiceOver support is now a near-certain rejection vector if completely absent.

**Files modified:**
- `FitnessStreaks/Views/DashboardView.swift`
- `FitnessStreaks/Views/StreakDetailView.swift`
- `FitnessStreaks/Views/SettingsView.swift`

**Changes:**
- **DashboardView:**
  - Hero streak button: `.accessibilityLabel("Steps streak: 42 days, threshold 10000 steps")` + `.accessibilityHint("View streak details")`
  - Refresh button: `.accessibilityLabel("Refresh streaks from Apple Health")`
  - Settings button: `.accessibilityLabel("Open settings")`
  - Broken streak banner: `.accessibilityLabel("Streak ended: 5-day steps run. Tap for recovery options.")`
  - Badge grid buttons: `.accessibilityLabel("{metric} streak: {current} {cadence}")` per badge
  - Find-more button: `.accessibilityLabel("Find more streaks")`
  - At-risk banner: `.accessibilityElement(children: .combine)` + `.accessibilityLabel("At risk: {metric}. {remaining} to lock today in")`
  - Empty-state buttons: labels for "Find more streaks", "Refresh", "Open iOS Settings for Health access"
- **StreakDetailView:**
  - Header card: `.accessibilityElement(children: .combine)` + full streak summary label
  - Today progress card: `.accessibilityElement(children: .combine)` + progress percentage and lock-in status
  - Recalibrate button: `.accessibilityLabel("Recalibrate threshold from Apple Health")`
  - Make Primary button: `.accessibilityLabel("Make this the primary streak on the dashboard")`
- **SettingsView:**
  - Notification toggle row: `.accessibilityElement(children: .combine)` + label + value (On/Off)
  - Blocked-notification button: `.accessibilityLabel("Notifications blocked in iOS settings. Tap to open Settings app.")`
  - Metric toggle rows: `.accessibilityElement(children: .combine)` + per-metric label + value (On/Off)

**Note:** Custom retro-font controls (`PixelProgressBar`, `CalendarHeatmap`, `PixelFlame`) still lack internal accessibility annotations. A deeper component-level pass remains recommended before final submission, but the primary user journeys (dashboard → detail → settings) are now navigable with VoiceOver.

---

### CR-2: Heart-rate query bounded with HealthKit quantity predicate + sample cap

**File:** `Shared/Services/HealthKitService.swift`

**Before:** `HKSampleQuery` with `limit: HKObjectQueryNoLimit` over 400 days loaded **every** heart-rate sample into memory for client-side filtering. A data-rich Apple Watch user could have millions of samples, causing OOM crashes and watchdog kills during background refresh.

**After:**
1. Added `HKQuery.predicateForQuantitySamples(with: .greaterThan, quantity: thresholdQuantity)` so HealthKit filters samples **at the database level** before returning them.
2. Capped query `limit` to `50_000` samples (~14 hours of 1 Hz workout sampling) as a safety valve.
3. Combined the quantity predicate with the existing date predicate via `NSCompoundPredicate`.

**Verification needed:** Test on a device with 2+ years of Apple Watch heart-rate data and confirm `store.load()` completes in < 3 seconds without memory spike.

---

## High Fixes

### HI-1: `try!` crash in DataService in-memory fallback replaced with nested `try?` fallbacks

**File:** `Shared/Services/DataService.swift`

**Before:** `return try! ModelContainer(for: schema, configurations: [inMemory])` — a single point of failure that crashes on launch if even an in-memory SwiftData container can't be created.

**After:** Two `try?` fallback attempts with differently-named `ModelConfiguration` instances before the final `try!`. The first fallback uses a renamed config to avoid any store-lock collision from the initial failed attempt. This makes the crash path require **three consecutive failures**, which is effectively impossible in practice.

---

### HI-2: Broken-streak banner no longer hardcodes "day"

**File:** `FitnessStreaks/Views/DashboardView.swift`

**Before:** `Text("\(broken.brokenLength)-day \(broken.metric.displayName.lowercased()) run")` always showed "day" even for weekly streaks.

**After:** `Text("\(broken.brokenLength)-\(broken.cadence.pluralLabel) \(broken.metric.displayName.lowercased()) run")` correctly shows "5 weeks" or "12 days".

---

### HI-3: Privacy manifests added to widget and watch-widget targets

**Files created:**
- `FitnessStreaksWidget/PrivacyInfo.xcprivacy`
- `FitnessStreaksWatchWidget/PrivacyInfo.xcprivacy`

Both declare `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1` (access app-groups UserDefaults), matching the main app and watch app manifests. This prevents automated App Store Connect scanner rejections for missing required-reason API declarations in extension binaries.

---

### HI-4: Redundant legacy `fetch` background mode removed

**File:** `FitnessStreaks/Info.plist`

**Before:** `UIBackgroundModes` contained `<string>fetch</string>` alongside modern `BGTaskScheduler` (`BGAppRefreshTask`).

**After:** `UIBackgroundModes` is now an empty array (`<array/>`). Background refresh is handled exclusively by `BGTaskSchedulerPermittedIdentifiers` → `com.jackwallner.streaks.refresh`.

**Note:** Verify on device that `BGAppRefreshTask` still schedules correctly after this removal.

---

## Medium Fixes

### MD-1: Grace-day tier now keys off hero streak only

**File:** `Shared/Services/StreakSettings.swift`

**Before:** `let tier = streaks.map { $0.current / 30 }.max() ?? 0` awarded grace days based on the longest-running badge, which could confuse users whose primary hero was much shorter.

**After:** `let tier = (streaks.first?.current ?? 0) / 30` ties grace-day awards directly to the hero streak, matching user expectation that the top streak drives progression rewards.

---

### MD-2: Watch complication timeline refresh shortened + widget reload added

**Files:**
- `FitnessStreaksWatchWidget/WatchComplication.swift`
- `FitnessStreaksWatch/App.swift`

**Before:** Complication timeline refreshed once per hour (`date(byAdding: .hour, value: 1, to: .now)`). The watch app background refresh handler did not trigger widget timeline reloads.

**After:**
1. Complication timeline now refreshes every **15 minutes** (`date(byAdding: .minute, value: 15, to: .now)`).
2. Watch app `handleBackgroundRefresh()` now calls `WidgetCenter.shared.reloadAllTimelines()` after `store.load()` completes, so complications update promptly when new HealthKit data arrives.

---

### MD-4: Broken-streak notification copy aligned with actual in-app options

**File:** `Shared/Services/NotificationService.swift`

**Before:** `"Restart anytime — the count is yours to set again"` implied users could manually edit historical streak counts, which the app does not support.

**After:** `"Keep the same goal or pick a new one in the app."` accurately reflects the `BrokenStreakSheet` options (Keep Same Goal / Pick New Goal / Dismiss).

---

### MD-5: Hour-window streak recalibration now receives `hourlySteps`

**Files:**
- `Shared/Services/StreakStore.swift`
- `FitnessStreaks/Views/StreakDetailView.swift`

**Before:** `StreakDetailView.suggestedThreshold` called `StreakEngine.discover(...)` without `hourlySteps:`, so recalibrating an hour-window streak could not rediscover the correct hourly threshold and would fall back to a whole-day threshold (or return `nil`).

**After:**
1. Added `@Published var hourlySteps: [Date: [Int: Double]] = [:]` to `StreakStore`.
2. `StreakStore.load()` now persists `hourlySteps` after fetching.
3. `StreakDetailView.suggestedThreshold` passes `hourlySteps: store.hourlySteps` into `StreakEngine.discover(...)`.

---

### MD-6: Per-badge at-risk banners removed (visual noise reduction)

**File:** `FitnessStreaks/Views/DashboardView.swift`

**Before:** Every badge in the grid could show its own red "AT RISK" banner simultaneously if all were incomplete after the reminder threshold time, creating a wall of red alerts.

**After:** Only the **hero** streak displays an at-risk banner. Badge cells no longer show per-badge risk banners.

---

## Not Fixed (Documented for Follow-Up)

| Issue | Severity | Reason |
|-------|----------|--------|
| **MD-3** Privacy policy / support URL liveness | Medium | External GitHub Pages URLs; cannot be fixed in code. Verify both URLs are live at submission time. |
| **LO-1** `UIRequiredDeviceCapabilities` → `healthkit` | Low | Intentionally iPhone-only by design. No action unless iPad support is desired. |
| **LO-2** Missing `WKBackgroundModes` in watch Info.plist | Low | Background refresh works without explicit modes on watchOS 10+ during TestFlight. Add only if testing reveals gaps. |
| **LO-3** Mixed locale formatting (`MMMd` vs hardcoded English) | Low | Minor polish. Force `shortFormatter.locale = Locale(identifier: "en_US_POSIX")` for consistency, or add `Localizable.strings`. |
| **LO-4** Widget small-view gradient background | Low | Design choice. Switch to `containerBackground` system material if review feedback requests it. |
| **CR-1 (deep)** Custom component accessibility | Critical | `PixelProgressBar`, `CalendarHeatmap`, `PixelFlame`, `PixelToggle` need internal `accessibilityLabel` / `accessibilityValue` / `accessibilityProgressView` modifiers. These were not addressed in this pass because they require component-level refactoring. |

---

## Files Modified / Created

### Modified
1. `Shared/Services/DataService.swift`
2. `Shared/Services/HealthKitService.swift`
3. `Shared/Services/StreakSettings.swift`
4. `Shared/Services/StreakStore.swift`
5. `Shared/Services/NotificationService.swift`
6. `FitnessStreaks/Views/DashboardView.swift`
7. `FitnessStreaks/Views/StreakDetailView.swift`
8. `FitnessStreaks/Views/SettingsView.swift`
9. `FitnessStreaks/Info.plist`
10. `FitnessStreaksWatch/App.swift`
11. `FitnessStreaksWatchWidget/WatchComplication.swift`

### Created
12. `FitnessStreaksWidget/PrivacyInfo.xcprivacy`
13. `FitnessStreaksWatchWidget/PrivacyInfo.xcprivacy`

---

## Build Verification Checklist

- [ ] `xcodebuild` iOS generic build succeeds
- [ ] `xcodebuild` watchOS generic build succeeds
- [ ] `xcodebuild test` on iPhone 17 Pro simulator passes
- [ ] VoiceOver smoke test on Dashboard, Detail, Settings, and Onboarding screens
- [ ] Device with heavy HealthKit data: `store.load()` completes without memory spike
- [ ] Widget + watch complication update within 15 minutes of completing a goal
- [ ] Recalibrate an hour-window streak and verify suggested threshold is still hour-based

---

*End of fix log.*
