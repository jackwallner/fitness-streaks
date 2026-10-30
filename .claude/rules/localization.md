---
paths:
  - "FitnessStreaks/**"
  - "Shared/**"
  - "FitnessStreaksWatch/**"
  - "FitnessStreaksWidget/**"
  - "FitnessStreaksWatchWidget/**"
  - "Tools/Localization/**"
---

# Streak Finder: localization (added 2026-10-30)

The app, widgets, Watch and complications ship in English plus de, es, fr,
it, ja, nl, pl and pt-BR (the fleet's top non-English markets; the App Store
pages were already translated, the app was English only). Same setup as Sober.

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`). `Shared/` is a source of every target and of
  `FitnessStreaksTests`, so they all compile it. XcodeGen 2.39+ reads its
  languages into `knownRegions`; each Info.plist also lists them in
  `CFBundleLocalizations`.
- `FitnessStreaks/InfoPlist.xcstrings` and `FitnessStreaksWatch/InfoPlist.xcstrings`
  translate the HealthKit purpose strings. Keep them in step with the
  Info.plist English. Display names stay "Streaks" (brand).
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on
  a source literal with no key, a key missing a language, mismatched format
  specifiers, or a bare literal passed to one of this app's String-typed copy
  parameters (`COPY_PARAMS`: `PixelSectionHeader(title:)`, `PixelChip(text:)`,
  `CoachmarkStep`, `statCell`, ...). Add new copy-taking views there.
- `LocalizationTests` proves every `.lproj` ships, Polish plurals pick
  one/few/many, the plural-category key works, and substitutions keep their
  argument order.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `alert`, `accessibilityLabel` and
  friends localize themselves. Copy held in a `String` (view parameters,
  enums, notifications, errors, the custom pixel components) must be
  `String(localized: "...")`. Logs, analytics, RevenueCat ids, stored keys and
  workout-type keys stay plain. Use `Text(verbatim:)` for pure
  number/punctuation joins.
- Whole sentences only. Branch per cadence (`-day` / `-week` keys) and per
  trial/no-trial instead of splicing. Trial lengths come from
  `Package.streaksIntroOfferDays`; never parse or lowercase a label.
- Metric and workout names inside sentences use `inlineName`
  (`inline.*` keys): the form each language needs in "your X streak" /
  "20 min X" (German compounds "%@-Serie", Polish genitive "seria kroków",
  French "série de pas"). Standalone labels use `displayName`, Apple Health's
  own metric names.
- Counts go in plural substitutions (`%#@n@` with `argNum`); Polish needs
  one/few/many/other. A word drawn beside a separate number ("12" over
  "DAYS STREAK") goes through `PluralLabel.category` and one key per category
  (`StreakCadence.unitWord/streakWord/bestWord`, `(few)`/`(many)` keys).
- Numbers via `LocalizedNumber` (no `String(format: "%.1f")`), percents via
  `.formatted(.percent)`, dates via `setLocalizedDateFormatFromTemplate`,
  weekday initials from `Calendar.veryShortStandaloneWeekdaySymbols`.
  `HourWindow.label` keeps the compact "5a-6p" in English and uses the
  locale's hour range elsewhere.
- Prices only from StoreKit; "$0.00" is `streaksZeroPriceLabel` in the
  product's currency.
- Distance stays in miles (thresholds 1/3/5/8 mi are part of streak ids);
  only the unit label is translated.
- Apple Health is named by its local app name (Salud, Santé, Salute,
  ヘルスケア, Gezondheid, Zdrowie, Saúde; "Apple Health" in German).
  Address: du / tú / vous / tu / je / ty / você / polite Japanese.
- Brand stays untranslated: Streaks, Streaks+, Streak Finder.

## Regenerating the catalog
The catalog was generated from per-language TSV sources by a one-off script
(not in the repo). Edit `Localizable.xcstrings` directly in Xcode or with a
JSON-aware script, then run `check.py`.

## Proving a change
`gh-sim all` with one `--screen` per language, e.g.
`--screen "-AppleLanguages (de) -AppleLocale de_DE"` (onboarding),
`"... -PaywallSnapshot trial"`, `"... -PaywallSnapshot yearly"` and
`"... -FitnessScreenshotBrand -UITestSeedStreaks -UITestSkipHealthKit -UITestSetFree"`
(dashboard with seeded data).
