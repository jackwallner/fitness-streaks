# Streak Finder — Project Guide

iPhone + Apple Watch app that mines Apple Health history for active streaks and encourages the user to keep them alive.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- HealthKit (read-only: stepCount, appleExerciseTime, appleStandTime, activeEnergyBurned, distanceWalkingRunning, flightsClimbed, workoutType, mindfulSession, sleepAnalysis)
- SwiftData (local cache shared via App Group)
- WidgetKit (iOS widgets + watchOS complications)
- XcodeGen (`project.yml` → `.xcodeproj`)
- Targets: iOS 17+, watchOS 10+

## Build & Run

```bash
xcodegen generate  # required after project.yml or file-structure changes
xcodebuild -project FitnessStreaks.xcodeproj -scheme FitnessStreaks -destination 'generic/platform=iOS' build
./scripts/testflight.sh  # archive + upload to TestFlight
```

## Architecture

### Targets

| Target | Type | Bundle ID | Platform |
|---|---|---|---|
| FitnessStreaks | iOS app | `com.jackwallner.streaks` | iOS |
| FitnessStreaksWidget | app-extension | `com.jackwallner.streaks.widget` | iOS |
| FitnessStreaksWatch | watchOS app | `com.jackwallner.streaks.watch` | watchOS |
| FitnessStreaksWatchWidget | app-extension | `com.jackwallner.streaks.watch.widget` | watchOS |

App group: `group.com.jackwallner.streaks`.

### Data flow

```
HealthKit → HealthKitService.fetchHistory(days:) → StreakEngine.discover(...)
                        ↓                                   ↓
             DailyActivity (SwiftData)          Streak[] (hero + badges)
                        ↓                                   ↓
                 Widget reads cache         StreakSnapshot in App Group UserDefaults
                                                            ↓
                                            Widgets + complications read snapshot
```

Widgets never query HealthKit. They render from the `StreakSnapshot` that the main app writes to App Group UserDefaults after each refresh.

### The streak engine

`StreakEngine.discover(history:hiddenMetrics:now:)` returns sorted `[Streak]`. Per `(metric, cadence)`:
- Evaluates every threshold tier (e.g. `steps.dailyThresholds = [3k, 5k, 7.5k, 10k, 12.5k, 15k]`).
- Picks the highest threshold where `current ≥ minLength` (3 days / 2 weeks).
- Falls back to the lowest threshold with `current ≥ 2` if nothing higher qualifies.

Today / this-week is treated as "live" — doesn't break the streak until the unit actually ends.

Sleep attribution: an asleep sample is credited to the day it *ended*.

Weekly totals: summed per ISO week starting Monday (see `DateHelpers.startOfWeek`).

### Signing

- Team: `YXG4MP6W39` (free Apple Dev account — max 3 apps installed)
- Automatic signing, set in `project.yml`
- Short bundle IDs (free accounts reject deeply nested IDs)

## Gotchas

- After adding/removing any `.swift`, run `xcodegen generate`.
- `UILaunchScreen` key is mandatory in `FitnessStreaks/Info.plist`.
- Widgets use the module-level `streaksAppGroupID` constant since `DataService` is `@MainActor`.
- watchOS `Theme`: no UIKit semantic colors — handled via `#if os(watchOS)`.
- Swift 6: all HealthKit callbacks wrapped in async continuations; `@Sendable` where required.
- `WKCompanionAppBundleIdentifier` in `FitnessStreaksWatch/Info.plist` must match the iOS bundle ID exactly.
