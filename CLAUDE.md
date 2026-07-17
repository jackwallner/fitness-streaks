# Streak Finder — Project Guide

iPhone + Apple Watch app that mines Apple Health history for active streaks and encourages the user to keep them alive.

XcodeGen project/scheme: `FitnessStreaks`, simulator device `agent-fitness-streaks`.

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

Today / this-week is treated as "live" — doesn't break the streak until the unit actually ends.
Sleep attribution: an asleep sample is credited to the day it *ended*.
Weekly totals: summed per ISO week starting Monday (see `DateHelpers.startOfWeek`).

## App-specific notes

- Review funnel: positive moments on hero-streak growth / today's goal met (`ReviewPromptTracker`, `ReviewPromptSheet`). App Store ID `6762699692`. (Shared funnel mechanics + playbook in the `ios-dev` skill.)

---
Shared iOS conventions (build, simulator, release/TestFlight, ASC key, signing, HealthKit/widget gotchas):
always-loaded global CLAUDE.md + the `ios-dev` skill.

## Subagent delegation
Follow the global CLAUDE.md subagent rules: ask Jack for the model before spawning, spawn at most one at a time unless Jack explicitly approves more, and never allow a subagent to spawn another subagent.
