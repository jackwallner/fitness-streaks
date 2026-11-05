---
paths:
  - "FitnessStreaks/**"
  - "FitnessStreaksWatch/**"
  - "FitnessStreaksWidget/**"
  - "FitnessStreaksWatchWidget/**"
  - "Shared/**"
  - "Tools/Localization/**"
---

# Streak Finder: localization (prepared 2026-11-04)

All user-facing copy routes through one string catalog, in English only for
now. Separate runs add the other languages; nothing is translated yet and no
language is listed in `CFBundleLocalizations`.

## Setup
- `Shared/Localizable.xcstrings` (source `en`, every key `extractionState:
  manual`). `Shared/` is a source of the app, widget, Watch, Watch widget and
  test targets, so every target compiles it. XcodeGen 2.39+ reads its languages
  into `knownRegions`; `developmentLanguage` is `en`.
- `FitnessStreaks/InfoPlist.xcstrings` and `FitnessStreaksWatch/InfoPlist.xcstrings`
  hold the two HealthKit purpose strings (English for now). Display names are the
  brand and stay out.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on a
  source literal with no key, on a `return "..."`, `case x: "..."` arm or ternary
  of literals that could reach the screen, on a key missing a language in `LANGS`,
  and on mismatched format specifiers. `LANGS` is empty today: add each language
  code there when its translations land. A literal that is not copy (symbol name,
  id, RevenueCat attribute) takes a trailing `// l10n-ignore: reason`.
- `LocalizationTests` proves the catalog compiles to an `.lproj` and that the
  English plural forms and the `PluralLabel` categories resolve. The test
  process has no catalog of its own: `String(localized:)` without
  `bundle: en` returns the raw key, so English assertions go through the `en`
  bundle.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `alert`, `Picker`, `accessibilityLabel`
  and friends localize themselves. Copy held in a `String` (enums, models,
  view parameters, notifications, error messages, accessibility strings) must be
  `String(localized: "...")`. Logs, analytics, RevenueCat metadata, stored keys,
  tags and ids stay plain. Keep the English wording exactly; visible words are
  Jack's.
- Whole sentences only. Branch and give each variant its own key (cadence x
  trial x window variants are separate keys). Counts go in plural variations, or
  a `%#@n@` substitution when the sentence has other arguments (see
  `"You're at %lld days. Get it in by %@."`). Slavic languages will need
  one/few/many/other.
- Number-plus-unit phrases come from `StreakMetric.amount(_:)` /
  `amount(wholeNumber:)`, `Streak.amount(_:)`, `WorkoutMeasure.amount(_:)` and
  `StreakCadence.count(_:)`. They take the number, not a formatted string. The
  integer on screen (`StreakMetric.displayCount`) is the plural selector, so
  every unit key has plural variations, and the digits travel as text beside
  it: `"\(n)|\(text) steps"` is key `"%lld|%@ steps"`, value `%#@n@`, forms
  `%2$@ steps`. A form must not print `%arg` or `%lld` for a goal: a plural
  variation formats its integer with a thousands separator ("10,000 steps",
  English is ungrouped), so the integer only selects. The same shape carries a
  separately formatted number (`"\(n)|\(number)+ steps every day"`). Only a
  value that always shows a fraction (sleep, kcal/min, distance and workout
  miles under 10) keeps a text-only `%@` key. Never hand `String(localized:)` a
  pre-formatted number next to a unit noun without the integer selector.
- Never splice one translated phrase into another sentence when the phrase
  holds a count or a noun (a run, a streak, a trial). Broken-run sentences are
  whole keys per cadence and trial state with the length as a number
  (`BrokenStreakSheet`). Trial sentences are whole keys per unit on
  `TrialLength` (day, month, year; a week folds into days), with the length as
  `%lld`. Adding a sentence that mentions the trial means adding it there, one
  key per unit.
- A cadence count inside a sentence ("streak: 5 days, threshold ...") is a
  `%lld` plural substitution in a per-cadence key, not `cadence.count(n)`
  interpolated as `%@`.
- A count label drawn beside a separately rendered number ("12" over
  "DAYS STREAK") cannot be a plural key. `PluralLabel` asks the catalog's
  `"%lld plural category"` key for the CLDR category, then picks one whole key per
  category (`"days streak"`, `"days streak (few)"`, `"days streak (many)"`). The
  `(few)`/`(many)` keys carry an `en` value so English never shows the key.
- All-caps styling is `.textCase(.uppercase)` on the `Text`, never `.uppercased()`
  or `.lowercased()` on translated text. In-sentence lowercase names are separate
  keys (`StreakMetric.lowerName`, `WorkoutTypeCatalog.Entry.lowerName`). English
  keys that were already upper case (`"KEEP YOUR %lld-DAY %@ STREAK ALIVE."`) stay
  upper case; the argument is natural case and the view upper-cases it.
- Dates use `setLocalizedDateFormatFromTemplate` (never a literal
  `dateFormat`); weekday initials come from `DateHelpers.mondayFirstWeekdayInitials`;
  relative times use `RelativeDateTimeFormatter`. Numbers use the `.plain`
  helpers in `StreakMetric.swift` (locale digits, no grouping) or
  `.formatted(.number...)`.
- Prices and currency only come from StoreKit (`localizedPriceString`,
  `streaksRecurringPriceLabel`). "$0.00" is `StreaksPricing.zeroLabel`, in the
  plan's currency. Trial lengths come from `streaksIntroOfferNumber`, never from
  parsing a label.
- Stored English values stay English in the store and snapshot (`StreakMetric`
  raw values, workout type keys, `recentlyBroken`, `gracePreservations`);
  labels are translated at display time.
- Brand stays untranslated: Streaks, Streaks+, Streak Finder, Fitness Habit
  Tracker, Elsa. Keep translations about as long as the English; the retro UI has
  tight rows (tab bar, pixel chips, CTA buttons).

## Proving a change
`python3 Tools/Localization/check.py`, then `gh-sim test --scheme FitnessStreaks`.
Screenshots per language: `gh-sim all` with one `--screen` per language, e.g.
`--screen "-AppleLanguages (de) -AppleLocale de_DE"`. Never set the production
RevenueCat `appl_` key on a simulator run.
