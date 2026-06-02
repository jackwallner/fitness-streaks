# Astro Phase B report — Streak Finder (go pipeline)

**Date:** 2026-05-25 · **App:** Fitness Habits - Streak Finder · **Astro ID:** `6762699692`

## Summary

| Step | Status |
|------|--------|
| ASC pull + backup | ✅ `fastlane/metadata.bak.20260525-184645` |
| Locale optimize (39) + dedupe vs name/subtitle | ✅ `scripts/aso-apply-locale-optimizations.py` |
| Pre-upload backup | ✅ `fastlane/metadata.bak.pre-upload-20260525-184804` |
| Draft upload (`asc-finish-missed.sh`) | ✅ **Version 1.1.1** · deliver finished successfully |
| Astro 91-store sync | ✅ **91/91** native (`scripts/astro-keywords-by-store/_summary.json`) |
| Prune all stores | ✅ (wrong language, headache terms, EN bleed) |
| Tier-1 second pass | ✅ (native seeds; no new suggestions returned) |
| Native re-sync | ✅ **91/91** — `scripts/astro-resync-native.log` |

## ASC upload

- **Draft:** `1.1.1` (`PREPARE_FOR_SUBMISSION`) — see `scripts/.asc-state.json`
- **Live:** `1.1.0`
- **API PATCH:** 50 locales keywords/description (`asc-upload-metadata.sh`)
- **Deliver:** 50 version localizations + 11 new **appInfo** locales (bn-BD, gu-IN, kn-IN, ml-IN, mr-IN, or-IN, pa-IN, sl-SI, ta-IN, te-IN, ur-PK)
- **Next:** Attach a build in ASC and submit **1.1.1** to ship metadata

## US highlights (en-US)

| Field | Before (live pull) | After |
|-------|-------------------|-------|
| **Subtitle** (30) | `Daily Routine & Goal Tracker` | `Streaks, Widgets & Apple Watch` |
| **Keywords** (100) | `steps,workout,widget,activity,motivate,consistent,progress,trend,watch,health,energy,change,calorie` | `motivate,rings,healthkit,move,steps,workout,mindful,sleep,stand,chain,heatmap,activity,exercise` (95 chars; deduped vs name/subtitle) |

**Dedupe rule:** Removed `habit` (in name “Habits”), `widget`/`watch`/`apple` (in subtitle). Added rings, healthkit, mindful, sleep, stand, chain, heatmap, exercise.

## All locales (39 optimized)

Full before/after: `scripts/aso-locale-optimization-report.json`

| Locale | Kw len | Subtitle (new) |
|--------|--------|----------------|
| en-US | 95 | Streaks, Widgets & Apple Watch |
| en-GB | 95 | Streaks, Widgets & Apple Watch |
| en-AU | 95 | Streaks, Widgets & Apple Watch |
| en-CA | 95 | Streaks, Widgets & Apple Watch |
| de-DE | 96 | Serien, Widgets & Apple Watch |
| fr-FR | 94 | Séries, widgets et Apple Watch |
| ja | 66 | 連続記録・ウィジェット・Watch |
| ko | 43 | 연속 기록·위젯·Watch |
| zh-Hans | 39 | 连续记录、小组件与Watch |
| … | … | (see JSON for all 39) |

## Astro stores

- Target: **91** (`scripts/astro-stores-2026.json`)
- Sync log: `scripts/astro-sync-all-stores.log`, `scripts/astro-sync-remaining.log`
- Per-store payloads: `scripts/astro-keywords-by-store/<store>.json`
- Summary (when complete): `scripts/astro-keywords-by-store/_summary.json`

## Recommended ASC locales not yet on disk

Indian regional folders may exist as appInfo-only until version locs unlock on draft submit: bn-BD, gu-IN, kn-IN, ml-IN, mr-IN, or-IN, pa-IN, ta-IN, te-IN, ur-PK, sl-SI.

## go refine (calendar)

Re-run after **7–14 days** on live **1.1.1** metadata:

```bash
ASC_APP_VERSION=1.1.1 ./scripts/pull-appstore-metadata.sh
python3 scripts/astro-tier1-second-pass.py
./scripts/astro-prune-all-stores.sh
./scripts/asc-finish-missed.sh
```
