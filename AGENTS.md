# Streak Finder Project Guide

iPhone + Apple Watch app that mines Apple Health history for active streaks and encourages the user to keep them alive.

XcodeGen project/scheme: `FitnessStreaks`, sim lease owner `fitness-streaks`.

## Tech Stack

- Swift 6 / SwiftUI (strict concurrency)
- HealthKit (read-only: stepCount, appleExerciseTime, appleStandTime, activeEnergyBurned, distanceWalkingRunning, flightsClimbed, workoutType, mindfulSession, sleepAnalysis)
- SwiftData (local cache shared via App Group)
- WidgetKit (iOS widgets + watchOS complications)
- XcodeGen (`project.yml`). Targets: iOS 17+, watchOS 10+

## Targets

| Target | Type | Bundle ID | Platform |
|---|---|---|---|
| FitnessStreaks | iOS app | `com.jackwallner.streaks` | iOS |
| FitnessStreaksWidget | app-extension | `com.jackwallner.streaks.widget` | iOS |
| FitnessStreaksWatch | watchOS app | `com.jackwallner.streaks.watch` | watchOS |
| FitnessStreaksWatchWidget | app-extension | `com.jackwallner.streaks.watch.widget` | watchOS |

App group: `group.com.jackwallner.streaks`.

## Data flow

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

## The streak engine

`StreakEngine.discover(history:hiddenMetrics:now:)` returns sorted `[Streak]`. Per `(metric, cadence)`:
- Evaluates every threshold tier (e.g. `steps.dailyThresholds = [3k, 5k, 7.5k, 10k, 12.5k, 15k]`).
- Picks the highest threshold where `current ≥ minLength` (3 days / 2 weeks).
- Falls back to the lowest threshold with `current ≥ 2` if nothing higher qualifies.

Today / this-week is treated as "live". It doesn't break the streak until the unit actually ends.
Sleep attribution: asleep samples less than 2 h apart form one night, credited to the day it *ended*.
Weekly totals: summed per ISO week starting Monday (see `DateHelpers.startOfWeek`).

## App-specific notes

- Ratings: no in-app rating question (App Review 5.6.1). When the hero streak grows or today's goal is newly met (`StreakStore`), `DashboardView` calls the system `requestReview()` about 3.5s later if no sheet, alert, tutorial or trial pitch is up (from the 2nd launch, 30-day cooldown; `ReviewPromptTracker`). A blocked ask stays pending for the next moment. Settings has separate "RATE STREAKS" and "SEND FEEDBACK" rows. App Store ID `6762699692`. (Shared rules in the `ios-dev` skill.)

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, HealthKit/widget gotchas):
the global agent rules + the `ios-dev` skill.

## Path-scoped rules

- [Android](.claude/rules/android.md): native phone port, local Pro verification, Health Connect differences and billing.
- [iPhone Duo](.claude/rules/iphone-duo.md): unfolded two-pane layout (tabs beside the streak detail), split math and capture tour.
