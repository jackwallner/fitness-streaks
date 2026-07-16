# Astro ASO setup — Streak Finder (US)

> Process: [Astro setup process](~/ios/aso/astro-setup-process.md) · Playbook: [global ASO rollout archive](~/ios/archive/aso/2026-05/astro-global-aso-go-2026.md) · Phase B: [Phase B report](archive/aso/2026-05/astro-phase-b-report.md) · Last pass: **2026-05-25**

## App

| Field | Value |
|-------|-------|
| App Store name | Fitness Habits - Streak Finder |
| Astro app ID | `6762699692` |
| Bundle ID | `com.jackwallner.streaks` |
| Store | `us` |

---

## Recommended marketing mix (implemented locally)

These files are updated in-repo; **push to App Store Connect** when ready:

```bash
./scripts/upload-appstore-metadata.sh   # or your usual deliver flow
```

### Subtitle (30 chars)

**Before:** `Daily Routine & Goal Tracker`  
**After:** `Streaks, Widgets & Apple Watch`

Why: Surfaces core differentiators (streaks, widgets, Watch) instead of generic “routine/goal tracker” where you rank #1000. Name already owns “Streak Finder” / “Fitness Habits”; subtitle should sell features.

### Keywords field (100 chars)

**Before:** `steps,workout,widget,activity,motivate,consistent,progress,trend,watch,health,energy,change,calorie`

**After:** `motivate,habit,rings,healthkit,widget,watch,steps,workout,mindful,sleep,stand,chain,heatmap,activity`

| Kept | Why |
|------|-----|
| `motivate` | **Best attack term** — pop 24, difficulty 48, already in field |
| `habit` | Supports `habit tracker` (pop **67**) without repeating “habits” from name |
| `rings`, `stand` | Activity rings / stand ring — diff 42–61, on-brand |
| `healthkit`, `widget`, `watch`, `steps`, `workout` | Feature + mid/high volume |
| `mindful`, `sleep` | Mindfulness + sleep streak features |
| `chain` | “Don’t break the chain” positioning (diff 45) |
| `heatmap`, `activity` | Calendar heatmaps + activity streak |

| Removed | Why |
|---------|-----|
| `calorie`, `change` | Wrong positioning; high pop, rank 1000, difficulty ~80 |
| `health`, `energy`, `trend`, `progress`, `consistent` | Either too generic (health pop 68 / diff 79) or too weak (pop ≤7) |

**Apple rule:** Do not repeat words from **name** or **subtitle** in the keyword field (`fitness`, `habits`, `streak`, `finder`, `daily`, `routine`, `goal`, `tracker` are off-limits).

---

## Keyword tiers (Astro data, US store)

Use this framework every week. Sorted by what to **do**, not raw popularity alone.

### Tier A — Defend (rank ≤ 200)

Already winning. Protect in **name**; do not rename away.

| Rank | Keyword | Pop | Diff | Action |
|------|---------|-----|------|--------|
| 1 | streak finder | 5 | 39 | Brand — keep in app name |
| 2 | fitness habits | 5 | 54 | Brand — keep in app name |
| 77 | healthkit streak | 5 | 48 | Mention in description + screenshots |
| 135 | activity streak | 5 | 53 | Same |
| 152 | active energy streak | 5 | 38 | Same |
| 167 | apple health streak | 5 | 67 | Same |

Low popularity = niche queries, but **high intent** and you own them.

### Tier B — Attack (pop ≥ 15, difficulty &lt; 72, rank 1000 today)

Primary growth targets. ASC field + subtitle + screenshots should reinforce these.

| Keyword | Pop | Diff | Notes |
|---------|-----|------|-------|
| **habit tracker** | **67** | 68 | #1 volume target; `habit` added to keyword field |
| **streak tracker** | **30** | 60 | Strong semantic fit |
| **motivate** | **24** | 48 | Easiest big term — keep in keywords |
| **healthkit** | **19** | 59 | Technical differentiator |
| **activity rings** | **16** | 61 | Rings closure audience |
| **exercise tracker** | **33** | 81 | Pop good; diff hard — track, don’t bet ASC on it alone |
| **apple health** | **60** | 65 | High volume; pair with HealthKit privacy story |

**New phrases to track in Astro** (sync when MCP stable): `fitness streak`, `habit streak`, `health streak`, `ring tracker`, `step tracker`.

### Tier C — Long shots (pop ≥ 40, difficulty ≥ 72)

Track in Astro for trends; **do not** optimize ASC around these first.

| Keyword | Pop | Diff |
|---------|-----|------|
| widget | 70 | 83 |
| health | 68 | 79 |
| workout | 66 | 81 |
| watch | 66 | 64 |
| habit tracker | 67 | 68 |
| steps | 58 | 81 |
| step counter | 62 | 81 |
| calorie | 55 | 80 |
| fitness tracker | 49 | 83 |

You need ratings + time to crack these.

### Tier D — Niche feature phrases (pop ~5, difficulty &lt; 55)

Low traffic but easy rank over time; good for description/screenshots.

- `activity ring streak` (diff 42)
- `don't break the chain` (diff 45)
- `stand ring` (diff 43)
- `calendar heatmap fitness` (diff 52)

---

## Astro tracking list

Curated list: `scripts/astro-keywords-us.json` (~65 terms, tier-focused).

Re-sync:

```bash
./scripts/sync-astro-keywords.sh
```

Config: `scripts/.astro-app.json`

---

## Weekly routine (10 min)

1. Sort Astro by **rank change** on Tier B keywords.
2. If **habit tracker** or **streak tracker** moves under 500 → keep current ASC; if flat 3+ weeks, test subtitle variant.
3. Tier A: confirm still #1–200 for `streak finder` / `fitness habits`.
4. Tier C: ignore unless rank improves without ASC changes (organic momentum).
5. After uploading new subtitle/keywords, wait **7–14 days** before judging.

---

## MCP prompts

- "Streak Finder US: Tier B keywords with rank change and popularity ≥ 15"
- "Compare habit tracker vs streak tracker rank trend for app 6762699692"
- "Which asc-field tokens rank under 200?"

---

## What success looks like (90 days)

| Milestone | Target |
|-----------|--------|
| Branded | Hold #1–3 on `streak finder`, `fitness habits` |
| Mid-tail | `streak tracker` or `habit tracker` under rank 100 |
| Feature | `healthkit` / `activity rings` under rank 150 |
| Long shots | Any Tier C term under 500 (bonus) |

---

## Upload checklist

- [x] Subtitle: `Streaks, Widgets & Apple Watch` (draft **1.1.1**)
- [x] Keywords field (deduped vs name/subtitle, 95 chars en-US)
- [x] `./scripts/asc-finish-missed.sh` (draft API + deliver 2.234)
- [ ] `./scripts/astro-sync-all-stores.sh` + prune + tier-1 (in progress — see phase B report)
- [ ] Re-check rankings in Astro after 7–14 days (**go refine**)

Backups: pull `fastlane/metadata.bak.20260525-184645` · pre-upload `fastlane/metadata.bak.pre-upload-20260525-184804`
