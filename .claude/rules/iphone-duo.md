---
paths: ["FitnessStreaks/Views/RootTabView.swift", "Shared/Utilities/UnfoldedSplit.swift", "FitnessStreaks/Views/DashboardView.swift", "FitnessStreaks/Views/StatsView.swift", "FitnessStreaks/Views/StreakDetailView.swift", "FitnessStreaks/Views/SettingsView.swift"]
---

# Streak Finder: iPhone Duo (2026-10-21)

- Unfolded (regular width, room for two panes of at least 360 pt), `RootTabView`
  puts the open tab (Streaks, Saves or Stats) and the pixel tab bar on the
  leading side of the fold and the streak detail on the trailing side. The
  pane shows the tapped streak, else the hero; the card on show gets a ring in
  its metric colour. Settings (the gear, the auto-save banner) opens in the
  trailing pane, `SettingsView(onClose:)`.
- Fold edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split; the math is
  `UnfoldedSplit` in Shared, tested in `UnfoldedSplitTests`. Same shape as Vitals.
- Rows reach the pane through `\.streakDetailPane` (nil when folded, so they
  push as on a phone). Unfolding moves a pushed streak or the Settings sheet
  into the pane; folding hands Settings back to the sheet.
- One view tree: folding only changes frames. The pane gets
  `horizontalSizeClass = .compact`. Never swap the tab content between
  containers with an `if`.
- Open issue: on the gh-sim iPhone Duo (iOS 27.1, root 867 pt with an 84 pt
  vertical bar on the trailing edge, fold 455.5...495.5) the leading pane's
  NavigationStacks (Dashboard, Saves, Stats) lay out at 455.7 pt, then settle
  at 371.7 pt, 84 pt short of the fold (`DUOGEOM dashboard width` in app.log).
  The tab bar and the trailing pane are correct. A full-width leading-aligned
  wrapper frame did not help. Next to try: measure with a DEBUG log whether
  the pane gets an 84 pt trailing safe-area inset, and if so
  `.ignoresSafeArea(.container, edges: split == nil ? [] : .trailing)` on the
  leading content; else host the three tabs in one NavigationStack at the
  `RootTabView` level, as VO2 Max does.
- Still across the fold: onboarding and the paywall, picker, broken-streak and
  freeze sheets (centred form sheets). None are in the store set.
- Unattended captures: `-FitnessScreenshotBrand -UITestSeedStreaks
  -UITestSetPro -UITestSkipHealthKit -DuoTour` plus `-DuoTourFirst`,
  `-DuoTourStep`, `-DuoRoutes`, `-DuoRoutesRegular` (`DuoScreenshotTour` in
  `RootTabView.swift`). `DUOTOUR` lines in app.log map shots to routes.
  Screenshot mode skips the coachmark tutorial.
