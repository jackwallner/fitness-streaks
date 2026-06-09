#!/usr/bin/env python3
"""Apply the 'Streak Tracker'-led repositioning across all App Store locales.

- Latin-script locales still on the old English "Fitness Streak Tracker - Move"
  get the new English name "Streak Tracker: Fitness Habits".
- Localized names that still carry a literal "Move" suffix get it stripped.
- Non-Latin names already streak-tracker-led (and Move-free) are left untouched.
- The four English locales also get the refined keyword set + new promo text.
- Subtitles and all locale-tuned keyword files are intentionally preserved.

Validates Apple field limits and refuses to write anything if a limit is blown.
"""
import sys
from pathlib import Path

META = Path("fastlane/metadata")
NAME_LIMIT, KW_LIMIT, PROMO_LIMIT = 30, 100, 170

EN_NAME = "Streak Tracker: Fitness Habits"

# Latin-script locales currently showing "Fitness Streak Tracker - Move".
LATIN_ENGLISH = [
    "ca", "cs", "da", "de-DE", "en-AU", "en-CA", "en-US", "en-GB", "es-ES",
    "fr-CA", "fi", "fr-FR", "hu", "hr", "it", "id", "ms", "no", "nl-NL",
    "pt-BR", "pl", "pt-PT",
]

# Localized names that still carry a "Move"-equivalent suffix -> strip it.
LOCALIZED_FIXES = {
    "th": "ตัวติดตามสตรีคฟิตเนส",   # "Fitness Streak Tracker" (drops "- Move")
    "tr": "Fitness Seri Takibi",      # "Fitness Streak Tracking" (drops "- Hareket")
    "ur-PK": "فٹنس اسٹریک ٹریکر",     # "Fitness Streak Tracker" (drops "- حرکت")
    "zh-Hant": "健身連勝追蹤器",        # "Fitness Streak Tracker" (drops "- 動起來")
}

EN_LOCALES = ["en-US", "en-GB", "en-AU", "en-CA"]
# No name/subtitle token repeats (name: streak/tracker/fitness/habits;
# subtitle: auto/streaks/health/data). Singles maximize combo coverage.
EN_KEYWORDS = "stand,ring,step,sleep,exercise,workout,mindful,activity,watch,widget,heatmap,energy,move,calendar"
EN_PROMO = (
    "You're already on streaks you can't see. Streak Tracker reads your "
    "Apple Health and surfaces every active run — then nudges you before "
    "one breaks. No logging, ever."
)

errors: list[str] = []
planned: list[tuple[Path, str]] = []


def stage(locale: str, field: str, value: str, limit: int) -> None:
    p = META / locale / f"{field}.txt"
    if not p.parent.is_dir():
        errors.append(f"{locale}: locale dir missing")
        return
    if len(value) > limit:
        errors.append(f"{locale}/{field}: {len(value)} > {limit}  «{value}»")
        return
    planned.append((p, value))
    print(f"  {locale:<8} {field:<16} ({len(value):>3}) {value}")


print("== names ==")
for loc in LATIN_ENGLISH:
    stage(loc, "name", EN_NAME, NAME_LIMIT)
for loc, name in LOCALIZED_FIXES.items():
    stage(loc, "name", name, NAME_LIMIT)

print("\n== english keywords + promo ==")
for loc in EN_LOCALES:
    stage(loc, "keywords", EN_KEYWORDS, KW_LIMIT)
    stage(loc, "promotional_text", EN_PROMO, PROMO_LIMIT)

if errors:
    print("\nREFUSING TO WRITE — limit/validation errors:")
    for e in errors:
        print("  -", e)
    sys.exit(1)

for p, value in planned:
    p.write_text(value + "\n", encoding="utf-8")

print(f"\nOK — wrote {len(planned)} files across "
      f"{len(LATIN_ENGLISH) + len(LOCALIZED_FIXES)} renamed locales.")
