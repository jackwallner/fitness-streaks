# Fitness Streaks Implementation Plan (kimi430)

## Executive Summary

This document outlines a comprehensive set of UI/UX and data-quality improvements for the Fitness Streaks app based on fresh user perspective feedback. The core insight is that an unfamiliar user finds several aspects unintuitive: confusing calorie metrics, overwhelming streak selection, inconsistent goal display, missing context in detail views, and awkward heatmap interactions.

---

## 1. Total Calories → Active Calories Only

### Current Problem
The `totalCalories` metric in `ActivityDay` (line 278-282 of `Streak.swift`) estimates total calories as `activeEnergy * 1.4`, which is scientifically inaccurate and varies wildly by individual. This creates a streak metric that doesn't correlate to actual HealthKit data, making it meaningless.

```swift
// Current problematic implementation
var totalCalories: Double {
    activeEnergy * 1.4  // Arbitrary estimate
}
```

### Proposed Solution
Remove the `totalCalories` metric entirely from `StreakMetric`. Users should only track `activeEnergy` (which is already available), which represents actual workout/activity burn from HealthKit.

### Files to Modify
- `Shared/Models/StreakMetric.swift` - Remove `.totalCalories` case from enum
- `Shared/Models/Streak.swift` - Remove `totalCalories` computed property and case in `value(for:)` switch
- `Shared/Models/DailyActivity.swift` - Remove from model if cached
- `Shared/Utilities/Theme.swift` - Remove `accentTotalCalories` if defined

### Why This Approach
- **Data Integrity**: Active energy is a real HealthKit metric; estimated total is fabrication
- **User Trust**: Arbitrary multiplication destroys credibility
- **Simplicity**: One clear calorie metric instead of confusing "active vs total"

### Edge Cases
- Users with existing `totalCalories` streaks in their tracked set → filter out during migration
- Widgets displaying cached data → gracefully degrade to not showing the metric

---

## 2. Smart Default Streak Selection with Priority Ordering

### Current Problem
In `OnboardingView.swift` (line 462), ALL discovered streaks are pre-selected: `selection = Set(store.allCandidates.map(\.trackingKey))`. This overwhelms new users who may have 8-12 discovered streaks. The "SELECT ALL" button then becomes ironic since everything is already selected.

### Current Selection Flow
```swift
// OnboardingView.swift:462
selection = Set(store.allCandidates.map(\.trackingKey))  // Everything selected!
```

### Proposed Solution
Implement a "Core 4" default selection strategy:

1. **Primary Core Metrics** (always auto-select if applicable):
   - `.steps` - Most universal fitness metric
   - `.activeEnergy` - True calorie burn (replacing totalCalories)
   - `.exerciseMinutes` - Apple Watch ring completion
   - `.workouts` - Binary "any workout" streak

2. **Priority Ordering**: Reorder picker list so core metrics appear at top

3. **Default Selection Logic**:
   ```swift
   let coreMetrics: [StreakMetric] = [.steps, .activeEnergy, .exerciseMinutes, .workouts]
   let defaults = store.allCandidates.filter { coreMetrics.contains($0.metric) }
   selection = Set(defaults.map(\.trackingKey))
   ```

4. **Visual Hierarchy**:
   - Section 1: "Recommended" (core metrics with ★)
   - Section 2: "Other Streaks" (discovered but not core)
   - Keep "SELECT ALL" button that actually selects everything

### Files to Modify
- `FitnessStreaks/Views/OnboardingView.swift` - Update `handleLoadFinished()` default selection
- `FitnessStreaks/Views/Components/StreakPicker.swift` - Reorder `StreakPickerList` with sections

### Why This Approach
- **Progressive Disclosure**: New users see 2-4 manageable streaks instead of 8-12
- **Cognitive Load**: "SELECT ALL" now has purpose (opt-in to everything)
- **Familiar Priority**: Steps + exercise + calories + workouts = standard fitness tracking

### Edge Cases
- User has no data for any core metric → fall back to top 3 by intensity score
- All discovered streaks ARE core metrics → show all as recommended

---

## 3. Consistent Step Goal Rounding to Hundreds

### Current Problem
The "today's goal 3556 of 7737 steps" display feels wrong because:
1. The goal (7737) should be a consistent round number
2. Current display shows variable thresholds based on unique historical values

### Root Cause Analysis
In `StreakEngine.swift`:
1. Line 170: `candidates = Array(Set(values).filter { $0 > 0 }).sorted()` - Uses raw historical values
2. Line 117: `roundThreshold` only applies AFTER discovery, not to candidates

```swift
// StreakEngine.swift:114-125 - Rounding happens AFTER candidate generation
private static func roundThreshold(_ value: Double, for metric: StreakMetric) -> Double {
    switch metric {
    case .steps:
        return (value / 100).rounded(.down) * 100  // Applied too late!
    ...
    }
}
```

### Proposed Solution
Apply rounding at candidate generation time, not post-discovery:

```swift
// StreakEngine.swift - Modified candidate generation
case .steps:
    // Round each unique value to nearest 100 first, then deduplicate
    let rounded = Set(values.map { (($0 / 100).rounded(.down) * 100) })
    candidates = Array(rounded).filter { $0 > 0 }.sorted()
```

This ensures goals like 7700, 7500, 8000 instead of 7737, 7542, etc.

### Files to Modify
- `Shared/Services/StreakEngine.swift` - Modify `discoverBestThreshold` to round candidates per-metric

### Why This Approach
- **Mental Models**: Users think "~7500 steps" not "exactly 7737 steps"
- **Consistency**: Same threshold rounding logic for all users at similar activity levels
- **Aesthetics**: Cleaner UI without arbitrary precision

### Edge Cases
- Rounding could create duplicate candidates → Set handles this
- Very low step counts (<100) → filtered by `$0 > 0`
- User with very consistent 7333 daily steps → rounds to 7300

---

## 4. Show Last Missed Date in Streak Detail

### Current Problem
When viewing a streak, users want context: "When was the last time I DIDN'T hit this?" Currently only `startDate` and `lastHitDate` are available, neither of which shows failure points.

### Data Available in Streak Model
```swift
// Streak.swift:46-48
let startDate: Date?      // When streak began
let lastHitDate: Date?     // Most recent day that met threshold
```

### Proposed Solution

Add a computed property to find the most recent failure before the streak started:

```swift
// In Streak.swift or StreakEngine
static func findLastMissedDate(
    metric: StreakMetric,
    threshold: Double,
    history: [ActivityDay],
    streakStartDate: Date
) -> Date? {
    // Filter to dates BEFORE the streak started, sorted newest first
    let priorDays = history
        .filter { $0.date < streakStartDate }
        .sorted { $0.date > $1.date }  // Newest first
    
    // Find first (most recent) day that did NOT meet threshold
    return priorDays.first { $0.value(for: metric) < threshold }?.date
}
```

### UI Implementation in StreakDetailView

Add below the header card:

```swift
private var lastMissedCard: some View {
    if let lastMissed = streak.lastMissedDate {
        HStack {
            Text("Last missed: \(formatDate(lastMissed)) (\(formatDayOfWeek(lastMissed)))")
                .font(RetroFont.mono(10))
                .foregroundStyle(Theme.retroInkDim)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .pixelPanel(color: Theme.retroInkFaint)
    }
}
```

### Files to Modify
- `Shared/Models/Streak.swift` - Add `lastMissedDate: Date?` property
- `Shared/Services/StreakEngine.swift` - Compute and include in Streak construction
- `FitnessStreaks/Views/StreakDetailView.swift` - Add UI card showing last missed

### Why This Approach
- **Context**: Users understand their streak better knowing when it broke
- **Day of Week**: Knowing "last missed was a Sunday" helps spot patterns
- **Motivation**: Shows how long they've been consistent since last failure

### Edge Cases
- Streak extends to beginning of history → lastMissedDate = nil
- Streak just started today → show "Just started today"
- No history available → hide the card entirely

---

## 5. Revamp 365-Day Heatmap for Binary Goals

### Current Problem
In `StreakDetailView.swift` (lines 478-495), the heatmap shows:
1. "LESS → MORE" gradient legend - nonsensical for binary pass/fail goals
2. Horizontal scrolling through 52+ weeks - awkward on mobile
3. Month labels at top - disconnected from actual dates

### Current Implementation
```swift
// StreakDetailView.swift:478-495
private var legendRow: some View {
    HStack(spacing: 6) {
        Text("LESS")  // Irrelevant for binary goals
        ForEach(0..<4) { i in
            Rectangle().fill(swatchColor(i))  // Gradient for continuous values
        }
        Text("MORE")  // Irrelevant for binary goals
        ...
    }
}
```

### Proposed Solution: Date-Selectable Range View

Replace the "LESS/MORE" gradient with a simpler pass/fail visualization and add date range selection:

```swift
// New heatmap approach
struct StreakHistoryView: View {
    @State private var selectedRange: DateRange = .lookbackPeriod  // Default
    
    enum DateRange: CaseIterable {
        case last30Days
        case last90Days
        case last180Days
        case lookbackPeriod  // Uses settings.lookbackDays
        case fullYear       // 365 days
        
        var label: String { ... }
        var days: Int { ... }
    }
}
```

**Visual Changes**:
1. **Simplified Legend**: Only 2 colors
   - Filled square: Met goal ✓
   - Empty square: Missed goal ✗
   - Gray square: No data

2. **Date Range Picker**: Segmented control above heatmap
   - 30d | 90d | 6mo | Lookback | 1yr
   - Dynamically filters displayed data
   - Defaults to user's configured lookback period

3. **Improved Scrolling**:
   - Vertical list of weeks (more natural than horizontal)
   - Or: Keep horizontal but add "Jump to Today" button
   - Show current streak window highlighted

### Files to Modify
- `FitnessStreaks/Views/Components/CalendarHeatmap.swift` - Simplify to binary colors
- `FitnessStreaks/Views/StreakDetailView.swift` - Add date range picker, remove LESS/MORE

### Why This Approach
- **Binary Clarity**: Pass/fail goals don't need gradients
- **User Control**: Choose their own analysis window
- **Mobile-Friendly**: Vertical scrolling or fixed viewport

### Edge Cases
- History shorter than selected range → show all available
- No data in selected range → show "No data for this period"
- Binary metrics (workouts) vs continuous (steps) → different color schemes

---

## 6. Add % Complete to Badge Cards

### Current Problem
In `StreakBadge.swift` (lines 52-56), badge cards show:
```swift
private var chargeLabel: String {
    "of \(t) goal · \(streak.current) days"  // No % complete!
}
```

But the Hero card (`StreakHero.swift:102-104`) shows:
```swift
private var statusText: String {
    if streak.currentUnitCompleted { return "LOCKED" }
    return "\(Int(min(1, streak.currentUnitProgress) * 100))% COMPLETE"
}
```

### Proposed Solution

Add % complete indicator to `StreakBadgeCard`:

```swift
// StreakBadge.swift - Enhanced chargeLabel
private var chargeLabel: String {
    let t = streak.format(currentUnitValue: streak.threshold)
    let unit = streak.current == 1 ? streak.cadence.label : streak.cadence.pluralLabel
    if streak.currentUnitCompleted {
        return "\(streak.current) \(unit) · LOCKED"
    } else {
        let pct = Int(min(1, streak.currentUnitProgress) * 100)
        return "\(pct)% · \(streak.current) \(unit)"
    }
}
```

### Visual Enhancement
- Progress bar already exists (line 48-51)
- Add color-coded percentage text:
  - ≥100%: Lime green (locked)
  - 50-99%: Amber (in progress)
  - <50%: Magenta (at risk)

### Files to Modify
- `FitnessStreaks/Views/Components/StreakBadge.swift` - Update `chargeLabel` computed property

### Why This Approach
- **Parity**: Main streak and badges show same information
- **At-a-Glance**: Users scanning dashboard see completion status immediately
- **Consistency**: Same information architecture across all streak cards

### Edge Cases
- Badge card is smaller → text may truncate → use compact format "87% · 12 days"
- Very long streak counts → prioritize percentage over count if space limited

---

## Implementation Order

1. **Remove totalCalories** (safest, no UI changes)
2. **Fix step rounding** (affects core display)
3. **Smart default selection** (onboarding improvement)
4. **Add % complete to badges** (quick UI win)
5. **Last missed date** (detail view enhancement)
6. **Heatmap redesign** (most complex, multiple files)

---

## Testing Considerations

### Unit Tests to Add
- `StreakEngineTests.swift`: Verify steps round to nearest 100
- Verify totalCalories exclusion from discovery
- Verify lastMissedDate calculation

### Manual Test Scenarios
1. Fresh install onboarding with 8 discovered streaks → only 4 selected
2. Verify step goal shows 7500 not 7543
3. Open streak detail → verify last missed date visible
4. Toggle heatmap date ranges → data updates
5. Verify badge cards show % complete

### Regression Risks
- Existing users with totalCalories streak → gracefully remove
- Committed thresholds with unrounded values → maintain but new ones round
- Widget cached data → may show old format temporarily

---

## Success Metrics

- **Onboarding completion rate**: Should improve (less overwhelming)
- **Streak selection time**: Faster with smart defaults
- **Detail view engagement**: More time spent (heatmap interaction)
- **User feedback**: Fewer "what does this number mean?" questions
