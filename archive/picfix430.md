# UI Issues Flagged from Screenshots (April 30)

This document maps the user annotations from the provided screenshots to the specific SwiftUI components in the codebase that require modification.

## 1. Missing Goal on Dashboard Badges
*   **UI Component:** `FitnessStreaks/Views/Components/StreakBadge.swift`
*   **Context:** The smaller, secondary streak cards displayed in the "Other Streaks" grid on the main dashboard.
*   **Issue:** The user scribbled "missing goal" next to these smaller cards and circled the area around the progress bar. Currently, these badges show the current value and a progress bar, but lack explicit text stating what the target goal is.
*   **Required Fix:** Update `StreakBadge.swift` to display the goal text (e.g., "Goal: 300 kcal") within the component's layout, likely near the progress bar or the current value.

## 2. Goal Text Placement on Hero View
*   **UI Component:** `FitnessStreaks/Views/Components/StreakHero.swift`
*   **Context:** The large, primary card at the top of the details view or dashboard displaying the main metric.
*   **Issue:** The user drew an arrow pointing from the "Goal: [value]" text (currently situated just above the progress bar) to the empty space directly to the right of the large, prominent current value number.
*   **Required Fix:** Update the layout in `StreakHero.swift`. Move the goal text from its current lower position and align it adjacent to the large primary metric value at the top of the card.

## 3. Broken Calendar Heatmap Layout (6-Month View)
*   **UI Component:** `FitnessStreaks/Views/Components/CalendarHeatmap.swift`
*   **Context:** The history section showing a grid of squares representing past performance, specifically when the "6mo" (6-month) segment is selected.
*   **Issue:** The user circled the 6-month grid and wrote "wrong". The layout is clearly broken—instead of a horizontal scrolling calendar layout, the grid items are squished into a narrow, vertical column stack.
*   **Required Fix:** Investigate the layout calculation logic within `CalendarHeatmap.swift`. Fix the grid definition (likely `LazyHGrid` or `LazyVGrid` configuration) to ensure the 6-month view wraps correctly into a standard horizontal calendar grid.

## 4. Recalibration Prompt on Lookback Period Change
*   **UI Component:** `FitnessStreaks/Views/SettingsView.swift`
*   **Context:** The "Discovery Window" setting, which determines the lookback period for suggesting new goals.
*   **Issue:** The user drew an arrow linking "Recalibrate All Goals" to the Discovery Window picker and wrote "prompt". When the user changes the lookback period (e.g., from 30 days to 90 days), the system should suggest recalibrating existing goals based on this new timeframe.
*   **Required Fix:** Update the `Picker` or state change logic for the Discovery Window in `SettingsView.swift`. When the value changes, trigger an alert or confirmation prompt asking the user: "Would you like to recalibrate your goals based on this new lookback period?" If they confirm, execute the recalibration logic.
