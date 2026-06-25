# Implementation Plan: 429 Updates

## Objective
Address user feedback regarding dashboard UI priorities, settings terminology ("Intensity" instead of "Vibe"), metric tracking logic, and various UI/UX refinements for launch.

## Scope & Impact
- **Views**: `StreakHero.swift`, `DashboardView.swift`, `SettingsView.swift`, `StreakDetailView.swift`, `OnboardingView.swift`
- **Models/Services**: `StreakMetric.swift`, `StreakSettings.swift`, `StreakStore.swift`, `DiscoveryVibe.swift` (rename to Intensity)
- **Features**: Hero visualization, Settings layout and terminology, Onboarding wording, and Discovery window.

## Proposed Solution & Implementation Steps

### 1. Dashboard & Hero UI Updates
- **`FitnessStreaks/Views/Components/StreakHero.swift`**:
  - Swap the emphasis: Make the daily goal progress (e.g., `chargeLabel`) use the large `RetroFont.pixel(36)` and move the streak count (e.g., `36 DAYS`) to the smaller sub-header position.
  - Highlight Completion: Add an overlay or border to the Hero card using `Theme.retroLime` when `streak.currentUnitCompleted` is true to make it pop in light mode.
  - Simplify Copy: Rephrase "best X in Yd" and remove the confusing "since date" text.
- **`FitnessStreaks/Views/DashboardView.swift`**:
  - Hide the "Streak Ended" banner (`brokenBanner`) if the underlying metric is currently hidden/disabled in settings.

### 2. Settings & Terminology Adjustments
- **Rename Vibe to Intensity**:
  - Rename `DiscoveryVibe` enum to `DiscoveryIntensity` across `StreakSettings.swift`, `StreakEngine.swift`, and all Views.
  - Update `SettingsView.swift` and `OnboardingView.swift` headers from "STREAK VIBE" to "INTENSITY".
  - Ensure the descriptions in Settings precisely match Onboarding.
- **Recalibration**:
  - Add a "RECALIBRATE ALL" button in `SettingsView.swift` beneath the Intensity section. This will clear `settings.committedThresholds` and trigger `Task { await store.load() }`. Ensure the loading state is properly dismissed upon completion.
- **Elsa Coach Callout**:
  - Add a new block in `SettingsView.swift` (above the About section) reading "Need a coach? Talk to Elsa" with a link (presumably to Elsa app/service, matching Vitals).
- **Discovery Slider**:
  - Update the slider in `SettingsView.swift` for `lookbackDays` to use a `Picker` or snapped `Slider` with discrete steps: 7, 30, 90, 180, 365, so 30 days is clearly defined.
- **Grace Days**:
  - Remove or comment out `graceSection` in `SettingsView.swift` to hide Grace Days for launch.

### 3. Metric & Logic Fixes
- **Default Primary to Steps**:
  - In `StreakStore.swift` or where `manualStreakOrder` is initialized, if `.steps` is in the discovered streaks, ensure it is prepended to the `manualStreakOrder` array so it defaults as the Hero.
- **Untrack Streak Button**:
  - In `StreakDetailView.swift`, add an "UNTRACK STREAK" button (perhaps at the bottom or replacing Make Primary if already primary) that removes the streak from `settings.trackedStreaks` and pops the view.
- **Hide Early Steps**:
  - In `SettingsView.swift`'s `metricsSection`, filter out `.earlySteps` so it cannot be manually toggled.
- **Toggle Sync**:
  - Update `StreakSettings.toggle()` / hidden metrics logic to immediately remove streaks relying on a newly hidden metric from `trackedStreaks` (or filter them out in `StreakStore.applyTrackedFilter`).
- **Precision Rounding**:
  - In `StreakMetric.swift`'s `format(value:)`, check the logic for `.distanceMiles`. Ensure `0.0` or `%.1f` is used correctly and verify that the `currentUnitCompleted` check in `Streak` uses raw double comparison rather than relying on formatted strings.

## Verification
- Launch the app and verify the Hero card shows the daily goal as the primary large text.
- Complete a goal and verify the glow/highlight activates.
- Open Settings, verify "Intensity" is used instead of "Vibe", Grace Days is hidden, the Elsa link is present, and the Discovery slider snaps to [7, 30, 90, 180, 365].
- Disable a metric in settings and verify any associated streaks vanish from tracked streaks and broken banners.
- Verify `Early Steps` is not in the Metrics list.
- Open a streak detail and untrack it; verify it disappears from the dashboard.