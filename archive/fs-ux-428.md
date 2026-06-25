# Fitness Streaks — Comprehensive UX Audit
**Date:** 2026-04-28  
**Scope:** iOS app, watchOS app, widgets, complications, notifications, onboarding, settings, streak management, broken-streak recovery  
**Method:** Static code-path analysis of every Swift file, every `View.body`, every navigation/sheet trigger, and every state machine transition.

---

## 1. First-Launch / Onboarding Route

### Path
`App.swift:RootView` → `OnboardingView` (5 steps: intro → vibe → minimum → review → primary)

### Friction Points
- **Step 1 — Health auth is a hard gate.** If the user taps `CONNECT HEALTH` and denies permission in the system sheet, the inline error says "Couldn't connect. Open Settings → Health → Data Access → Streak Finder." There is no "skip and explore empty dashboard" path. The user is trapped on the intro step until they grant access or force-quit.
- **Step 3 — "Existing streaks stay locked" is confusing copy for a first-timer.** The user has no existing streaks yet; this message only makes sense for a repeat visit to settings.
- **Step 4 (review) — If `allCandidates` is empty, the CTA changes to `FINISH SETUP`.** This path (fresh device / App Store reviewer) dumps the user into an empty dashboard with no tracked streaks. The empty dashboard does explain the situation, but there is no guided path back to onboarding or a way to manually seed a custom streak from the empty state.
- **Step 4 — Pre-checked top 5 are automatic.** The first-timer doesn't explicitly opt in; streaks are silently selected for them. If they tap `NEXT` without reading, they may end up tracking metrics they don't care about.
- **Step 5 (primary) — If `candidates.isEmpty`, the copy says "Go back to pick at least one," but the primary button `START TRACKING` is still visible and tappable.** `advance()` has a `guard !selectedStreaks.isEmpty else { return }`, so the tap silently does nothing. No visual feedback = dead click.
- **No onboarding replay.** Once `hasCompletedSetup = true`, there is no in-app path to re-run onboarding or re-pick vibe/lookback from a guided flow. Users must discover Settings > Streak Vibe on their own.

### Screen Connections
- Onboarding → Dashboard is a single boolean flip (`hasCompletedSetup`). No animated transition, no "You're all set" confirmation. The UI instantly swaps.
- Onboarding does not preload the dashboard; the first `store.load()` happens during Step 3 (`minimum`), so Step 4 may show a loading gap.

---

## 2. Dashboard Daily-Use Route

### Path
`DashboardView` → hero tap → `StreakDetailView` / badge tap → `StreakDetailView` / settings gear → `SettingsView` / refresh button → `store.load()` / broken banner → `BrokenStreakSheet`

### Friction Points
- **At-risk awareness is hero-only.** The red `! AT RISK` banner only renders for the hero streak. A user could have a 60-day workout badge at risk and never know, because the hero happens to be steps and is already locked.
- **Broken streak banner only shows the most recent one.** `settings.recentlyBroken.first` is displayed; if two streaks break the same day (e.g., after a vacation), the second is invisible until the first is dismissed.
- **"Other Streaks · X Active" counts all tracked badges, not "active and at risk."** The label is factual but doesn't help the user prioritize attention.
- **Badge grid is capped at 4.** If the user tracks 6 streaks, 2 are completely hidden from the dashboard with no "show more" affordance. The user must tap `+ FIND MORE STREAKS` to see the full list.
- **No pull-to-refresh.** The only refresh affordance is a small icon button in the top bar. Muscle memory from Mail/Weather doesn't work here.
- **`+ FIND MORE STREAKS` is always visible, even when all candidates are already tracked.** Tapping it opens `StreakPickerSheet`, which can feel redundant.
- **Refresh button + Settings button have identical visual weight.** Two square outline buttons side-by-side; the refresh button is easily mistaken for a "sync to Apple Watch" or "share" action.

### Screen Connections
- Hero → Detail is a `navigationDestination(item:)`. The back button in detail is custom `◄ BACK` text, not a standard chevron. This breaks iOS muscle memory and looks like a label, not a button.
- Dashboard → Settings is a sheet. Dashboard → Streak Picker is also a sheet. If the user opens Settings, then opens the streak picker from inside Settings, they are now two sheets deep. Dismissing the picker returns to Settings, not Dashboard.

---

## 3. Streak Detail Deep-Dive Route

### Path
`StreakDetailView` — scrollable cards: header → today progress → recalibrate (conditional) → make primary (conditional) → hour-window explainer (conditional) → calendar heatmap / stats row → weekday histogram (hero-only) → threshold ladder (hero-only)

### Friction Points
- **Recalibrate dismisses the entire detail view.** Tapping `RECALIBRATE` clears the committed threshold, triggers `store.load()`, and immediately `dismiss()`. The user is yeeted back to the dashboard without seeing what the new threshold became. No "Are you sure?" or preview.
- **Make Primary also dismisses immediately.** Same abrupt exit. The user doesn't get to see the dashboard reordering or confirm the change.
- **Weekday histogram and threshold ladder are hero-only.** If a user is proud of a badge streak and wants to see which days they perform best on, or what the next tier would be, they can't. These analytics are locked behind being the primary streak.
- **Calendar heatmap scrolls horizontally, but cell size is tiny (8pt).** Tapping a day does nothing — no tooltip, no exact value, no date label. The user must mentally map the grid position to a date.
- **Heatmap legend says "AVG X HITS/WK" but "hits" is undefined.** It means "days that met threshold," but the term is never introduced.
- **Stats row label "RATE" shows completion percentage over `lookbackDays` but the unit label always says "DAY WINDOW" even for weekly cadence.** A weekly streak shows "65% · 30 DAY WINDOW" which is technically correct (the rate is computed over days) but reads oddly.
- **Threshold ladder recomputes every tier's streak on every render.** Expensive but hidden from user. On older phones this can cause scroll jank.
- **Hour-window explainer says "the next window starts at X" but the risk text says "between X to lock today in."** These two descriptions use different framing (future window vs current deadline) and could be unified.

### Screen Connections
- Detail → Dashboard is only via the custom back button or swipe-back. No deep-linking into a specific tab or section.

---

## 4. Settings Management Route

### Path
`SettingsView` → Appearance / Streak Vibe (with tracked-streaks button & slider) / Notifications / Grace Days / Metrics Tracked / Data / About

### Friction Points
- **Vibe change triggers a full `store.load()` with no loading state.** The Settings sheet stays open while HealthKit queries run in the background. On a slow day, the dashboard behind the sheet updates silently, which can be disorienting when the user dismisses Settings.
- **LookbackDays slider fires `store.load()` on every 1-day increment.** Dragging from 30 → 60 days can trigger 30 full engine recomputations. The slider should probably debounce or only act on drag-end.
- **"TRACKED STREAKS" button lives inside the "Streak Vibe" section.** Conceptually, tracked streaks are independent of vibe. Grouping them together makes the settings hierarchy harder to scan.
- **Metrics Tracked toggles also trigger `store.load()` immediately.** Toggling 5 metrics off = 5 engine runs. No batching.
- **No way to delete custom streaks.** Once a user builds a custom streak in the picker, it persists forever in `settings.customStreaks`. Disabling its metric hides it, but the data is still there and the threshold still blocks rediscovery.
- **No "Reset to defaults" or "Clear all streaks" escape hatch.** If the user's dashboard becomes a mess of custom thresholds, the only fix is manual per-streak recalibration or reinstall.
- **"REFRESH NOW" in Data section dismisses the Settings sheet.** The user tapped refresh expecting data to update behind the sheet; instead they are kicked out of Settings entirely.
- **About links (Privacy Policy, Source, Support) open in Safari.** The user leaves the app. No in-app Safari or simple text display.
- **Notification time picker is visible but disabled when notifications are off.** Grayed-out controls are fine, but the DatePicker still takes up vertical space and may tempt the user to try interacting.

### Screen Connections
- Settings → Streak Picker is a sheet over a sheet. The picker has its own `CANCEL`/`SAVE` toolbar. If the user cancels, they return to Settings. If they save, they return to Settings and the dashboard updates.
- Settings → Custom Streak Builder is a third sheet layer. Three-deep sheet stack on iPhone can feel heavy.

---

## 5. Streak Discovery & Tracking Route

### Path
`StreakPickerSheet` → reorder selected / toggle all candidates / `+ BUILD YOUR OWN` → `CustomStreakBuilderSheet`

### Friction Points
- **"YOUR ORDER (drag to reorder)" only shows selected streaks, but the primary streak is determined by order.** A user may not realize that the first item in the reorder list is their dashboard hero. The copy says "first becomes your primary streak," but it's easy to miss.
- **"ALL STREAKS" list includes already-selected items.** There is no visual separation; users must cross-reference the reorder list above to see what's active.
- **Custom streak builder allows `threshold = 0` and any decimal value.** The text field uses `.decimalPad` and the `ADD` button is always active. A threshold of `0` causes the engine to return a 0-length streak (the `guard threshold > 0` blocks infinite loops but still produces a useless streak). A threshold of `0.5` workouts is nonsensical.
- **Custom streak builder only offers hour-window for steps.** A user can't create "exercise between 6–7am" or "mindfulness at 9pm." The UI doesn't explain why.
- **No preview of custom streak viability before saving.** The user enters 50,000 steps and taps ADD. The streak appears with `current: 0` and no guidance on what threshold would actually yield a streak.
- **No edit or delete for custom streaks.** Once added, the only way to change the threshold is to delete the whole thing... but there is no delete button. The user must disable the metric globally in Settings > Metrics Tracked.
- **"SAVE" is always enabled even if selection is empty.** Saving an empty selection is allowed (produces an empty dashboard). There is no "You must track at least one streak" validation.

### Screen Connections
- Custom Builder → Streak Picker auto-inserts the new custom streak into selection and order. Good flow.
- Streak Picker → Dashboard calls `store.refilter()` (not `load()`), so if `allCandidates` is stale, the new custom streak may not show until next refresh.

---

## 6. Broken-Streak Recovery Route

### Path
Dashboard broken banner tap → `BrokenStreakSheet` → `RESTART SAME GOAL` / `PICK A NEW GOAL` / `CLOSE`

### Friction Points
- **"TAP TO RESTART" on the banner is oversimplified.** Tapping opens a sheet with three options, not a single restart action. The banner promises one thing and delivers a decision tree.
- **"RESTART SAME GOAL" reuses the exact same threshold.** If the streak broke because the threshold was too aggressive (e.g., life-changing vibe auto-picked 15k steps), restarting with the same threshold sets the user up to fail again. There is no "lower the goal" option in this sheet.
- **"PICK A NEW GOAL" closes the broken sheet and opens the Streak Picker.** This is a context switch from "your streak died" to "here's a buffet of options." The emotional beat of losing a streak is lost.
- **"CLOSE" on the toolbar vs the dismiss action have different semantics.** Toolbar `CLOSE` just closes the sheet without persisting snapshot. The banner may reappear. The `dismiss` closure (not exposed to user as a labeled action) persists snapshot and dismisses the banner. This is subtle.
- **No "pause streak" or "vacation mode."** If a user knows they will be traveling, the only option is to let it break and restart later.
- **Broken streaks expire after 48h (pruned in `pruneBroken`).** A user who doesn't open the app for 3 days loses the chance to even see what broke. The notification fires, but if missed, the context is gone.
- **Grace days are consumed silently.** When a grace day auto-preserves a streak, the user gets a notification, but the dashboard never explains *why* the streak didn't reset. The user may think they hit the goal when they didn't.
- **Grace day UI is minimal.** Settings shows "X banked · +1 every 30 days" but doesn't explain the preservation logic, show a history of grace usage, or warn when the bank is empty.

### Screen Connections
- Broken sheet → Streak Picker is a sheet chain. If the user picks a new goal, saves, and returns to Dashboard, the broken banner is gone. If they cancel, the broken banner remains.

---

## 7. WatchOS App Route

### Path
`WatchRootView` → `WatchOnboardingView` (auth) → `WatchTodayView` (hero + up to 6 badges)

### Friction Points
- **Onboarding is a single screen, unlike iOS's 5-step flow.** The watch user gets no vibe picker, no discovery window slider, no primary selection. Their watch experience is entirely governed by the iOS settings, but there is no indication of this dependency.
- **No broken-streak recovery on watch.** If a streak breaks, the watch user sees the count drop to 0 on next refresh with no explanation or recovery action.
- **No settings view on watch.** The user can't toggle notifications, change vibe, or hide metrics from the watch. They must open the iOS app.
- **Watch shows 6 badges; iOS dashboard shows 4.** Inconsistency in how many streaks are visible at a glance. The watch actually shows *more* context than the phone.
- **Pull-to-refresh exists on watch (`refreshable`) but not on iOS.** Inverted platform convention.
- **Watch onboarding uses a different visual language.** Rounded buttons, system fonts, gradients — whereas iOS uses sharp rectangles, JetBrains Mono, and retro palette. The apps feel like different products.
- **No complication/widget explanation.** A user who adds the watch complication may see "No streak yet — open app" for hours because the iOS app hasn't written a snapshot yet.

### Screen Connections
- Watch app shares `StreakStore`, `StreakSettings`, and `HealthKitService` via the app group, but there is no explicit sync protocol. `PhoneSyncService` exists in the iOS app but its delegate methods are empty. The two platforms happen to read the same UserDefaults/SwiftData, but the user isn't told this.

---

## 8. Widget & Complication Glance Route

### Path
Home screen / Lock screen / Watch face → `StreakWidgetView` / `WatchComplicationView` (reads `SnapshotStore`)

### Friction Points
- **Widgets are passive and can be heavily stale.** The timeline refresh policy is `min(nextHour, tomorrow)`, so a widget can show yesterday's hero for up to an hour after the streak broke. The user may see "42 days" on the widget while the app shows "0 days."
- **"No streak yet — open app" is a dead end.** The widget cannot trigger an app refresh or deep-link. The user must remember to open the app.
- **Medium widget shows hero + 3 badges, but if the hero is weekly and badges are daily, the widget doesn't distinguish cadence visually.** All just show numbers.
- **Watch complication `accessoryCorner` only shows the number.** No metric name, no unit. A user with multiple complications from different apps might forget what the number refers to.
- **Lock-screen inline widget says "42 d" or "42 days" but doesn't say what metric.** "Steps 42 days" vs "Sleep 42 days" is indistinguishable at a glance.
- **Widget doesn't respect the iOS "at risk" state.** The widget always shows the number cheerfully, even if the hero streak is about to break tonight. No amber/red coloring.

### Screen Connections
- Widgets cannot open a specific streak detail. Tapping any widget family just opens the app to the dashboard root.

---

## 9. Notification Experience

### Path
System notification → `scheduleDailyReminder` / `notifyStreakBroken`

### Friction Points
- **Only the hero streak gets at-risk reminders.** A user with 5 tracked streaks only gets a nudge for one of them. The others can break silently.
- **Notification only checks `hero.current >= 3`.** A 2-day streak that is at risk gets no protection.
- **Notification time is a single daily slot.** If a user's hour-window streak is at risk at 3pm but their reminder is set for 7pm, it may be too late.
- **Broken-streak notification fires immediately (1s trigger).** If the user is actively using the app when the streak breaks, they get an instant banner. If they're not, they get a stale notification hours later with no context.
- **Notification body for weekly streaks still says "days" and "before midnight."** Copy is incorrect for weekly cadence.
- **No rich notification actions.** "Keep the streak alive" notification has no "Mark done" or "Open app" action buttons.

---

## 10. Empty & Error States

### Friction Points
- **Empty dashboard shows 3 buttons side-by-side (`FIND MORE`, `REFRESH`, `HEALTH ACCESS`).** On small iPhones (SE/Mini), these may stack or truncate. The `HEALTH ACCESS` button opens the app's iOS Settings page, not the HealthKit permission page directly.
- **Empty dashboard copy: "If you've been moving lately, double-check Streak Finder has Health access."** This is speculative. If Health access *is* granted but there just isn't enough data, the copy is misleading.
- **Onboarding error state (Health denied) shows "OPEN SETTINGS" button.** Tapping it opens the app's system settings, not Health → Data Access. The user must navigate two more taps.
- **Loading state is just a flame + "LOADING HEALTH..."** No progress bar, no estimated time, no cancellation. If HealthKit is slow, the user may think the app froze.
- **Widget "No streak yet" state has no fallback or explanation.** It can't distinguish between "app hasn't been opened" and "no data in HealthKit."

---

## 11. Cross-Screen State & Conceptual Confusion

### Friction Points
- **"Tracked streaks" vs "hidden metrics" are two different filters that interact non-obviously.**
  - Hidden metrics remove an entire dimension from discovery (e.g., hide all Sleep streaks).
  - Tracked streaks remove specific metric+threshold combinations from the dashboard.
  - A user might hide Sleep in Metrics Tracked, but still see a Sleep streak in the Streak Picker if it was previously selected. The picker doesn't enforce the hidden-metrics filter.
- **Vibe changes thresholds retroactively.** Switching from Sustainable → Life-changing can replace a 5k steps streak with a 10k steps streak. The user's "current" count may drop to 0 instantly. There is no warning or explanation sheet.
- **Committed thresholds persist across vibe changes.** If a user recalibrates a streak, it stays locked even when vibe changes. This is correct for stability, but the UI doesn't explain why some streaks change and others don't.
- **The term "LOCKED GOAL" in detail view and "LOCKED" in today card use the same word for different meanings.** "Locked goal" = threshold is committed. "Locked" = today's unit is completed. These are conceptually unrelated.
- **"Grace days" are invisible in the dashboard.** The user has no way to know if a grace day was used yesterday unless they happen to check Settings. The streak count continues as if nothing happened, which is magical but opaque.
- **Primary streak vs hero vs "first in order" are the same thing with three names.** The UI calls it "primary" in detail, "hero" in code/dashboard, and "first in order" in the picker. Consistency would reduce cognitive load.
- **"Best in X days" changes meaning based on lookback window.** A user who sees "best 12 in 30d" on Monday and changes lookback to 365 days may see "best 12 in 365d" on Tuesday. The number didn't change, but the context makes it feel like a downgrade.

---

## 12. Design & Typography Inconsistencies

### Friction Points
- **`RetroFont.pixel()` is not a pixel font.** It renders JetBrains Mono Bold. The naming and comments suggest an old pixel aesthetic that no longer exists. This creates a mismatch between the code's self-image and the actual UI.
- **Watch app uses `.rounded` design; iOS app uses retro sharp rectangles.** The watch doesn't use `pixelPanel`, `RetroFont`, or the retro palette. It looks like a different product.
- **iOS app has no haptic feedback for streak completions, breaks, or recalibrations.** Arcade-themed app with no physical feedback feels flat.
- **The flame sprite (`PixelFlame`) is 8×8 blocks.** At large sizes (88pt in onboarding, 72pt in empty state), it looks blocky and low-resolution compared to the crisp typography around it.
- **Dashboard top bar shows "updated just updated · apple health" which reads poorly.** The relative date formatter + static suffix produces redundancy.

---

## 13. Missing Safety Nets

### Friction Points
- **No undo for recalibrate or make-primary.** Both actions are irreversible in the moment and immediately dismiss the view.
- **No confirmation before resetting a broken streak.** Restarting a 200-day streak with the same threshold is one tap away.
- **No data export or backup.** All data is local; a phone restore wipes history and committed thresholds.
- **No onboarding help/tooltip for first-time dashboard users.** The first time a user sees a hero card, they may not understand what "DAYS IN A ROW" means or why the progress bar is segmented.
- **No in-app FAQ for edge cases.** "Why did my streak break?" "What is a grace day?" "How is the threshold chosen?" None of these are answerable without leaving the app.

---

## 14. Summary Table — Highest-Impact Friction

| Rank | Issue | Route | Severity |
|------|-------|-------|----------|
| 1 | Health auth is a hard gate with no skip | Onboarding intro | High |
| 2 | Recalibrate/Make Primary dismiss view abruptly | Streak Detail | High |
| 3 | At-risk banner is hero-only; badges can break silently | Dashboard | High |
| 4 | Stale widget data up to 1h after break/change | Widget | Medium-High |
| 5 | Custom streak builder allows 0/nonsensical thresholds | Streak Picker | Medium-High |
| 6 | Broken streak banner "TAP TO RESTART" is misleading | Dashboard → Sheet | Medium |
| 7 | Only hero gets at-risk notifications | Notifications | Medium |
| 8 | Watch onboarding gives no vibe/primary control | Watch | Medium |
| 9 | Settings refresh button kicks user out of Settings | Settings | Medium |
| 10 | Grace days are invisible in dashboard | Dashboard | Medium |
| 11 | No delete/edit for custom streaks | Streak Picker / Settings | Medium |
| 12 | Lookback slider triggers engine recompute per tick | Settings | Medium |
| 13 | Detail back button is non-standard `◄ BACK` text | Streak Detail | Low-Medium |
| 14 | Watch and iOS feel like different apps | Cross-platform | Low-Medium |
| 15 | "Loading Health..." has no progress or cancel | Dashboard loading | Low-Medium |

---

## 15. Files Referenced

- `FitnessStreaks/App.swift`
- `FitnessStreaks/Views/OnboardingView.swift`
- `FitnessStreaks/Views/DashboardView.swift`
- `FitnessStreaks/Views/StreakDetailView.swift`
- `FitnessStreaks/Views/SettingsView.swift`
- `FitnessStreaks/Views/BrokenStreakSheet.swift`
- `FitnessStreaks/Views/Components/StreakPicker.swift`
- `FitnessStreaks/Views/Components/StreakHero.swift`
- `FitnessStreaks/Views/Components/CalendarHeatmap.swift`
- `FitnessStreaksWatch/App.swift`
- `FitnessStreaksWatch/Views/WatchTodayView.swift`
- `FitnessStreaksWidget/FitnessStreaksWidget.swift`
- `FitnessStreaksWatchWidget/WatchComplication.swift`
- `Shared/Services/StreakStore.swift`
- `Shared/Services/StreakEngine.swift`
- `Shared/Services/StreakSettings.swift`
- `Shared/Services/HealthKitService.swift`
- `Shared/Services/NotificationService.swift`
- `Shared/Models/StreakMetric.swift`
- `Shared/Utilities/Theme.swift`
