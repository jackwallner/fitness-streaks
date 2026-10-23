---
paths: ["FitnessStreaks/Views/RootTabView.swift", "Shared/Utilities/UnfoldedSplit.swift", "FitnessStreaks/Views/DashboardView.swift", "FitnessStreaks/Views/StatsView.swift", "FitnessStreaks/Views/SavesView.swift", "FitnessStreaks/Views/StreakDetailView.swift", "FitnessStreaks/Views/SettingsView.swift"]
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
- iOS 27.1 moves a `NavigationStack`'s toolbar into a vertical bar on its
  trailing edge. In the leading pane that bar sat against the fold and
  narrowed Streaks, Saves and Stats by 84 pt (455.5 pt pane, 371.7 pt
  content). While split, `RootTabView` sets `toolbarVerticalBehavior(.disabled)`
  (`horizontalToolbarsInPanes`); folded keeps `.automatic`. The system then
  drops its own vertical bar: root 951 pt, panes 0-455.5 and 495.5-951, the
  status bar across the top of the trailing pane.
- Split, the Dashboard hides its empty nav bar and ignores the top safe area,
  its top bar padded 30 pt so it sits level with the detail's title.
- The pane is only 669 pt tall. Split, the Saves hero puts its sprite beside
  the caption (a row, not a column), so the Planned Freezes card ends above
  the tab bar instead of being sliced by it (rejected 2026-10-23). Check every
  leading-pane tab for text cut at the bar after a layout change.
- Still across the fold: onboarding and the paywall, picker, broken-streak and
  freeze sheets (centred form sheets). None are in the store set.
- Unattended captures: `-FitnessScreenshotBrand -UITestSeedStreaks
  -UITestSetPro -UITestSkipHealthKit`, then one `gh-sim --screen
  "-DuoScreen <route>"` per surface (`streaks`, `streaks/exerciseMinutes`,
  `stats/standHours`, `saves/sleepHours`, `streaks/settings`). Never `--url`
  (iOS 27.1 alerts over every openurl). `-DuoTour` (`-DuoTourFirst`,
  `-DuoTourStep`, `-DuoRoutes`, `-DuoRoutesRegular`) walks the routes on a
  timer for recordings. `DUOSCREEN`/`DUOTOUR` lines in app.log map shots to
  routes (`DuoScreenshotTour` in `RootTabView.swift`). `-UITestSeedStreaks`
  seeds before the launch task's first await and turns `StreakStore.load()`
  into a no-op; otherwise a launch load restored the widget snapshot over the
  seed (folded empty state, 0% completion, the routed streak missing).
  Screenshot mode skips the coachmark tutorial.
