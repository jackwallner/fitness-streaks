# Localization ASO — Streak Finder

**Playbook:** [global ASO rollout archive](~/ios/archive/aso/2026-05/astro-global-aso-go-2026.md) — say **go** = optimize all locales · 91 Astro stores · **upload ASC draft**.

## Status (2026-05-25)

| Item | Value |
|------|-------|
| ASC draft version | **1.1.1** (`PREPARE_FOR_SUBMISSION`) |
| Live version | 1.1.0 |
| Astro app ID | `6762699692` |
| ASC locales on disk | **50** fastlane folders (39 original + 11 appInfo via deliver) |
| Astro stores synced | In progress → target **91** |

## Backups

| Path | When |
|------|------|
| `fastlane/metadata.bak.20260525-184645` | ASC pull (ground truth before optimize) |
| `fastlane/metadata.bak.pre-upload-20260525-184804` | Pre-upload snapshot |

**Restore pre-optimize metadata:**

```bash
rm -rf fastlane/metadata
cp -R fastlane/metadata.bak.20260525-184645 fastlane/metadata
```

**Restore pre-upload only:**

```bash
rm -rf fastlane/metadata
cp -R fastlane/metadata.bak.pre-upload-20260525-184804 fastlane/metadata
```

## Re-run upload (draft)

```bash
./scripts/asc-finish-missed.sh
# or metadata only:
eval "$(python3 scripts/asc-ensure-draft-version.py | grep '^export ')"
SKIP_SCREENSHOTS=true ./scripts/upload-appstore-metadata.sh
```

## Astro sync / prune (native language)

**`scripts/astro_locale.py`** maps each Astro store → primary fastlane locale(s) only (e.g. `de` → `de-DE`, not `en-US`). Sync no longer bleeds English keywords into German/French/Japanese stores.

```bash
./scripts/astro-sync-all-stores.sh      # 91 stores, native keywords from fastlane
./scripts/astro-prune-all-stores.sh       # drop wrong script, headache terms, EN bleed
python3 scripts/astro-tier1-second-pass.py  # tier-1 suggestions with native seeds
```

Logs: `scripts/astro-prune-all-stores.log`, `scripts/astro-resync-native.log`

State file: `scripts/.asc-state.json`
