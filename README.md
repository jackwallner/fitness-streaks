# Streak Finder

Native iPhone + Apple Watch app that mines your Apple Health history for the fitness streaks you've already built — the ones you didn't realize were going — and nudges you to keep them alive.

- **Discovery engine.** Automatically finds active streaks across steps, exercise minutes, stand hours, active energy, workouts, mindfulness, sleep, distance, and flights climbed — at every threshold tier, daily and weekly.
- **Hero streak + badges.** One flagship streak front and center, with the rest as tappable badges.
- **Strict daily, with weekly fallback.** If your daily streak breaks, a weekly streak keeps the momentum alive.
- **Calendar heatmap** per streak, showing every hit and miss in the last year.
- **Home + Lock Screen widgets.** Small, medium, and lock-screen complications.
- **Apple Watch.** Full watch app plus circular, rectangular, corner, and inline complications.
- **Daily at-risk reminder.** 7pm nudge if the hero streak isn't locked in yet.
- **Local-only.** Read-only HealthKit access. No network, no analytics, no accounts.

## Tech

- Swift 6 / SwiftUI, strict concurrency
- HealthKit (read-only)
- SwiftData (local cache, shared via App Group)
- WidgetKit (iOS + watchOS)
- XcodeGen (`project.yml` → `.xcodeproj`)
- iOS 17+ / watchOS 10+

## Build

```bash
# Requires: brew install xcodegen
xcodegen generate
open FitnessStreaks.xcodeproj
```

Or from CLI:

```bash
xcodebuild -project FitnessStreaks.xcodeproj \
  -scheme FitnessStreaks \
  -destination 'generic/platform=iOS' build
```

## TestFlight

```bash
./scripts/testflight.sh
```

Requires Xcode signed in (Settings → Accounts) with team `YXG4MP6W39`.

## Architecture

Four targets, all sharing `Shared/`:

| Target | Bundle ID | Platform |
|---|---|---|
| FitnessStreaks | `com.jackwallner.streaks` | iOS |
| FitnessStreaksWidget | `com.jackwallner.streaks.widget` | iOS |
| FitnessStreaksWatch | `com.jackwallner.streaks.watch` | watchOS |
| FitnessStreaksWatchWidget | `com.jackwallner.streaks.watch.widget` | watchOS |

App group: `group.com.jackwallner.streaks`

### Shared/

- `Models/StreakMetric.swift` — enum of metrics + per-metric threshold ladders + display.
- `Models/Streak.swift` — `Streak` (current/best/threshold/progress) + `ActivityDay`.
- `Models/DailyActivity.swift` — SwiftData `@Model` cache row.
- `Services/HealthKitService.swift` — HK auth, daily history fetch across 9 metrics, background delivery, SwiftData upsert.
- `Services/StreakEngine.swift` — the core. Scans history and picks, per (metric, cadence), the highest-threshold tier with an active streak — daily and weekly. Ranks by an interestingness score.
- `Services/StreakStore.swift` — `@MainActor ObservableObject` that drives the iOS + watch UI.
- `Services/StreakSettings.swift` — user prefs + `SnapshotStore` that persists the top streaks to App Group UserDefaults so widgets can render without hitting HealthKit.
- `Services/DataService.swift` — SwiftData container scoped to the app group.
- `Services/NotificationService.swift` — daily 7pm at-risk reminder.
- `Utilities/Theme.swift`, `Utilities/DateHelpers.swift`.

### How the engine discovers streaks

1. Pull ~400 days of daily samples from HealthKit (sum-per-day for quantity types; workout counts for `HKWorkout`; sleep attributed to the day each asleep sample ended on).
2. For each metric (9 of them), evaluate every threshold tier (e.g. steps → 3k/5k/7.5k/10k/12.5k/15k) at both daily and weekly cadence.
3. Pick the **highest threshold per (metric, cadence)** with `current ≥ minLength` (3 days / 2 weeks).
4. Rank with `score = length × metricWeight × tierBonus`. The top one is the hero; the rest are badges.
5. Today (or this week) doesn't break the streak until it ends — the live unit counts once the threshold is met.

## Privacy

- Reads only. Never writes to Apple Health.
- No network calls. No third parties. No analytics.
- All data stays on-device + in the app group container.

## License

Personal project.
