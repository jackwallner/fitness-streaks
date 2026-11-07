# Project documentation

Developer notes and historical audits for this repository. The published site remains in the docs directory.

## Audits

- [audit823.md](audits/audit823.md): Streak Finder audit823
- [ios27StreakFinder.md](audits/ios27StreakFinder.md): iOS 27 compatibility audit: Streak Finder
- [state-machines-2026-11-06.md](audits/state-machines-2026-11-06.md): state machine audit: entitlement, trial, streak break and save, reminders (repro suite alongside)
- [state-machines-2026-11-06-review.md](audits/state-machines-2026-11-06-review.md): independent review of the state machine audit: 8 confirmed, 1 not a bug, method changes
- [state-machines-2026-11-06-fixes.md](audits/state-machines-2026-11-06-fixes.md): fixes for the reviewed state machine audit: 10 fixed, 0 held, 0 skipped, with regression tests; verify round: P-11 regression and note 2 fixed, note 4 held, 158 tests pass
- [state-machines-2026-11-06-verify.md](audits/state-machines-2026-11-06-verify.md): independent verification of the state machine fixes, round 2: PASS, all 10 fixes and both follow-ups verified, 158 tests pass, revert proof fails as intended

## Design

- [design.md](design/design.md)

## Marketing

- [aso-plan.md](marketing/aso-plan.md): aso-plan.md: Streak Finder ASO (creative niche pass)

## Specs

- [my-current-paywall-spec.md](specs/my-current-paywall-spec.md): FitnessStreaks Pro: Paywall Design Spec

## Android

- [Android release preparation](android/README.md): products, Play preparation and port acceptance evidence.
